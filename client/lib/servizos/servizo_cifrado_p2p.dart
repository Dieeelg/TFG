import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VinculacionP2P {
  const VinculacionP2P({
    required this.id,
    required this.uidRemoto,
    required this.tokenRemoto,
    required this.claveBase64,
    required this.rolRemoto,
  });

  final String id;
  final String uidRemoto;
  final String tokenRemoto;
  final String claveBase64;
  final String rolRemoto;

  VinculacionP2P copyWith({
    String? uidRemoto,
    String? tokenRemoto,
    String? claveBase64,
  }) => VinculacionP2P(
    id: id,
    uidRemoto: uidRemoto ?? this.uidRemoto,
    tokenRemoto: tokenRemoto ?? this.tokenRemoto,
    claveBase64: claveBase64 ?? this.claveBase64,
    rolRemoto: rolRemoto,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'uidRemoto': uidRemoto,
    'tokenRemoto': tokenRemoto,
    'clave': claveBase64,
    'rolRemoto': rolRemoto,
  };

  factory VinculacionP2P.fromJson(Map<String, dynamic> json) => VinculacionP2P(
    id: json['id'] as String,
    uidRemoto: json['uidRemoto'] as String,
    tokenRemoto: json['tokenRemoto'] as String,
    claveBase64: json['clave'] as String,
    rolRemoto: json['rolRemoto'] as String,
  );
}

class DatosQrVinculacion {
  const DatosQrVinculacion({
    required this.id,
    required this.uidPaciente,
    required this.tokenPaciente,
    required this.claveBase64,
  });

  final String id;
  final String uidPaciente;
  final String tokenPaciente;
  final String claveBase64;

  VinculacionP2P comoPacienteRemoto() => VinculacionP2P(
    id: id,
    uidRemoto: uidPaciente,
    tokenRemoto: tokenPaciente,
    claveBase64: claveBase64,
    rolRemoto: 'PACIENTE',
  );
}

class PayloadP2PDescifrado {
  const PayloadP2PDescifrado({
    required this.vinculacionId,
    required this.contido,
  });

  final String vinculacionId;
  final String contido;
}

class MensaxeP2PNonValida implements Exception {
  const MensaxeP2PNonValida(this.motivo);

  final String motivo;

  @override
  String toString() => motivo;
}

class ServizoCifradoP2P {
  ServizoCifradoP2P({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _storageVinculacions = 'p2p_vinculacions_seguras';
  static const _storagePendenteActual = 'p2p_vinculacion_pendente_actual';
  static const _prefixoPendente = 'p2p_clave_pendente_';
  static const _versionProtocolo = 1;

  final FlutterSecureStorage _storage;
  final AesGcm _algoritmo = AesGcm.with256bits();

  Future<String> xerarClaveBase64() async =>
      base64Encode(await (await _algoritmo.newSecretKey()).extractBytes());

  Future<String> xerarCodigoVinculacion({
    required String uidPaciente,
    required String tokenPaciente,
  }) async {
    final claveBase64 = await xerarClaveBase64();
    final idBytes = await (await _algoritmo.newSecretKey()).extractBytes();
    final id = base64UrlEncode(idBytes.sublist(0, 16)).replaceAll('=', '');

    final pendenteAnterior = await _storage.read(key: _storagePendenteActual);
    if (pendenteAnterior != null && pendenteAnterior != id) {
      await _storage.delete(key: '$_prefixoPendente$pendenteAnterior');
    }
    await _storage.write(key: _storagePendenteActual, value: id);
    await _storage.write(key: '$_prefixoPendente$id', value: claveBase64);

    return jsonEncode({
      'version': _versionProtocolo,
      'vinculacionId': id,
      'uidPaciente': uidPaciente,
      'tokenPaciente': tokenPaciente,
      'clave': claveBase64,
    });
  }

  DatosQrVinculacion lerCodigoVinculacion(String codigo) {
    try {
      final json = jsonDecode(codigo) as Map<String, dynamic>;
      if (json['version'] != _versionProtocolo) {
        throw const MensaxeP2PNonValida('Versión do código QR non admitida');
      }
      final datos = DatosQrVinculacion(
        id: json['vinculacionId'] as String,
        uidPaciente: json['uidPaciente'] as String,
        tokenPaciente: json['tokenPaciente'] as String,
        claveBase64: json['clave'] as String,
      );
      if (datos.id.isEmpty ||
          datos.uidPaciente.isEmpty ||
          datos.tokenPaciente.isEmpty ||
          base64Decode(datos.claveBase64).length != 32) {
        throw const MensaxeP2PNonValida('Código QR incompleto');
      }
      return datos;
    } catch (e) {
      if (e is MensaxeP2PNonValida) rethrow;
      throw const MensaxeP2PNonValida('Código QR non válido');
    }
  }

  Future<String> cifrarPayload({
    required VinculacionP2P vinculacion,
    required String tipoAviso,
    required String payload,
  }) async {
    final nonce = _algoritmo.newNonce();
    final caixa = await _algoritmo.encrypt(
      utf8.encode(payload),
      secretKey: SecretKey(base64Decode(vinculacion.claveBase64)),
      nonce: nonce,
      aad: _aad(vinculacion.id, tipoAviso),
    );
    return jsonEncode({
      'version': _versionProtocolo,
      'vinculacionId': vinculacion.id,
      'nonce': base64Encode(caixa.nonce),
      'datos': base64Encode(caixa.cipherText),
      'mac': base64Encode(caixa.mac.bytes),
    });
  }

  Future<PayloadP2PDescifrado> descifrarPayload({
    required String envelope,
    required String tipoAviso,
    bool permitirClavePendente = false,
  }) async {
    try {
      final json = jsonDecode(envelope) as Map<String, dynamic>;
      if (json['version'] != _versionProtocolo) {
        throw const MensaxeP2PNonValida('Versión da mensaxe non admitida');
      }
      final id = json['vinculacionId'] as String;
      final claveBase64 = permitirClavePendente
          ? await _storage.read(key: '$_prefixoPendente$id')
          : (await obterPorId(id))?.claveBase64;
      if (claveBase64 == null) {
        throw const MensaxeP2PNonValida(
          'A mensaxe non pertence a unha vinculación coñecida',
        );
      }
      return descifrarPayloadConClave(
        envelope: envelope,
        tipoAviso: tipoAviso,
        claveBase64: claveBase64,
      );
    } catch (e) {
      if (e is MensaxeP2PNonValida) rethrow;
      throw const MensaxeP2PNonValida(
        'Non se puido autenticar ou descifrar a mensaxe',
      );
    }
  }

  Future<PayloadP2PDescifrado> descifrarPayloadConClave({
    required String envelope,
    required String tipoAviso,
    required String claveBase64,
  }) async {
    try {
      final json = jsonDecode(envelope) as Map<String, dynamic>;
      if (json['version'] != _versionProtocolo) {
        throw const MensaxeP2PNonValida('Versión da mensaxe non admitida');
      }
      final id = json['vinculacionId'] as String;
      final caixa = SecretBox(
        base64Decode(json['datos'] as String),
        nonce: base64Decode(json['nonce'] as String),
        mac: Mac(base64Decode(json['mac'] as String)),
      );
      final claro = await _algoritmo.decrypt(
        caixa,
        secretKey: SecretKey(base64Decode(claveBase64)),
        aad: _aad(id, tipoAviso),
      );
      return PayloadP2PDescifrado(
        vinculacionId: id,
        contido: utf8.decode(claro),
      );
    } catch (e) {
      if (e is MensaxeP2PNonValida) rethrow;
      throw const MensaxeP2PNonValida(
        'Non se puido autenticar ou descifrar a mensaxe',
      );
    }
  }

  Future<void> confirmarVinculacionPendente({
    required String id,
    required String uidCoidador,
    required String tokenCoidador,
    required String clavePermanenteBase64,
  }) async {
    final clave = await _storage.read(key: '$_prefixoPendente$id');
    if (clave == null) {
      throw const MensaxeP2PNonValida('A vinculación xa non está pendente');
    }
    try {
      if (base64Decode(clavePermanenteBase64).length != 32) {
        throw const MensaxeP2PNonValida('Clave permanente non válida');
      }
    } catch (e) {
      if (e is MensaxeP2PNonValida) rethrow;
      throw const MensaxeP2PNonValida('Clave permanente non válida');
    }
    await gardarVinculacion(
      VinculacionP2P(
        id: id,
        uidRemoto: uidCoidador,
        tokenRemoto: tokenCoidador,
        claveBase64: clavePermanenteBase64,
        rolRemoto: 'COIDADOR',
      ),
    );
    await _storage.delete(key: '$_prefixoPendente$id');
    final actual = await _storage.read(key: _storagePendenteActual);
    if (actual == id) await _storage.delete(key: _storagePendenteActual);
  }

  Future<List<VinculacionP2P>> obterVinculacions() async {
    final raw = await _storage.read(key: _storageVinculacions);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => VinculacionP2P.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<VinculacionP2P>> obterPorRolRemoto(String rol) async =>
      (await obterVinculacions()).where((v) => v.rolRemoto == rol).toList();

  Future<VinculacionP2P?> obterPorId(String id) async =>
      (await obterVinculacions()).where((v) => v.id == id).firstOrNull;

  Future<VinculacionP2P?> obterPorToken(String token) async =>
      (await obterVinculacions())
          .where((v) => v.tokenRemoto == token)
          .firstOrNull;

  Future<VinculacionP2P?> obterPorUid(String uid) async =>
      (await obterVinculacions()).where((v) => v.uidRemoto == uid).firstOrNull;

  Future<void> gardarVinculacion(VinculacionP2P vinculacion) async {
    final todas = await obterVinculacions();
    todas.removeWhere(
      (v) =>
          v.id == vinculacion.id ||
          (v.uidRemoto == vinculacion.uidRemoto &&
              v.rolRemoto == vinculacion.rolRemoto),
    );
    todas.add(vinculacion);
    await _storage.write(
      key: _storageVinculacions,
      value: jsonEncode(todas.map((v) => v.toJson()).toList()),
    );
  }

  Future<void> eliminarPorId(String id) async {
    final todas = await obterVinculacions();
    todas.removeWhere((v) => v.id == id);
    await _storage.write(
      key: _storageVinculacions,
      value: jsonEncode(todas.map((v) => v.toJson()).toList()),
    );
  }

  Future<void> eliminarPorUid(String uid) async {
    final todas = await obterVinculacions();
    todas.removeWhere((v) => v.uidRemoto == uid);
    await _storage.write(
      key: _storageVinculacions,
      value: jsonEncode(todas.map((v) => v.toJson()).toList()),
    );
  }

  List<int> _aad(String id, String tipoAviso) =>
      utf8.encode('sintrom-p2p-v$_versionProtocolo|$id|$tipoAviso');
}
