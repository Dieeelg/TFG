import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../servizos/servizo_cifrado_p2p.dart';
import '../servizos/servizo_notificacions_locais.dart';
import '../servizos/servizo_sincronizacion_p2p.dart';

export '../servizos/servizo_cifrado_p2p.dart' show VinculacionP2P;

class PatientSettingsViewModel extends ChangeNotifier {
  final FlutterSecureStorage _storage;
  final ServizoCifradoP2P _cifrado;
  final LocalNotificationService _notificacions;
  final P2PSyncService _sincronizacion;
  final Future<String?> Function() _obterUid;
  final Future<String?> Function() _obterToken;

  PatientSettingsViewModel({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    ServizoCifradoP2P? cifrado,
    LocalNotificationService? notificacions,
    P2PSyncService? sincronizacion,
    Future<String?> Function()? obterUid,
    Future<String?> Function()? obterToken,
  }) : _storage = storage,
       _cifrado = cifrado ?? ServizoCifradoP2P(),
       _notificacions = notificacions ?? LocalNotificationService(),
       _sincronizacion = sincronizacion ?? P2PSyncService(),
       _obterUid =
           obterUid ?? (() async => FirebaseAuth.instance.currentUser?.uid),
       _obterToken = obterToken ?? FirebaseMessaging.instance.getToken;

  String _nome = '';
  String _hora = '20:00';
  bool _modoSinxelo = false;
  bool _cargando = false;
  bool _cargado = false;
  bool _gardando = false;
  String? _desvinculandoId;
  String? _erro;
  List<VinculacionP2P> _supervisores = const [];

  String get nome => _nome;
  String get hora => _hora;
  bool get modoSinxelo => _modoSinxelo;
  bool get cargando => _cargando;
  bool get cargado => _cargado;
  bool get gardando => _gardando;
  String? get desvinculandoId => _desvinculandoId;
  String? get erro => _erro;
  List<VinculacionP2P> get supervisores => _supervisores;

  Future<void> cargar() async {
    _cargando = true;
    _erro = null;
    notifyListeners();
    try {
      final resultados = await Future.wait<Object?>([
        _storage.read(key: 'nome_usuario'),
        _storage.read(key: 'hora_toma'),
        _storage.read(key: 'modo_sinxelo'),
        _cifrado.obterPorRolRemoto('COIDADOR'),
      ]);
      _nome = (resultados[0] as String?) ?? '';
      _hora = (resultados[1] as String?) ?? '20:00';
      _modoSinxelo = resultados[2] == 'true';
      _supervisores = resultados[3] as List<VinculacionP2P>;
      _cargado = true;
    } catch (e) {
      _erro = 'Non se puideron cargar os axustes';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  void cambiarModoSinxelo(bool activar) {
    _modoSinxelo = activar;
    notifyListeners();
  }

  Future<bool> gardar({required String nome, required String hora}) async {
    _gardando = true;
    _erro = null;
    notifyListeners();
    try {
      final nomeLimpo = nome.trim();
      if (nomeLimpo.isEmpty) {
        await _storage.delete(key: 'nome_usuario');
      } else {
        await _storage.write(key: 'nome_usuario', value: nomeLimpo);
      }
      await _storage.write(key: 'hora_toma', value: hora);
      await _storage.write(
        key: 'modo_sinxelo',
        value: _modoSinxelo ? 'true' : 'false',
      );
      await _notificacions.programarTomasPaciente(nome: nomeLimpo, hora: hora);
      await _sincronizacion.notificarCoidador('ESTADO_COMPLETO');
      _nome = nomeLimpo;
      _hora = hora;
      return true;
    } catch (e) {
      _erro = 'Non se puideron gardar os cambios';
      return false;
    } finally {
      _gardando = false;
      notifyListeners();
    }
  }

  Future<bool> desvincular(VinculacionP2P vinculacion) async {
    _desvinculandoId = vinculacion.id;
    _erro = null;
    notifyListeners();
    try {
      await _sincronizacion.desvincularCoidador(vinculacion);
      _supervisores = await _cifrado.obterPorRolRemoto('COIDADOR');
      return true;
    } catch (e) {
      _erro = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _desvinculandoId = null;
      notifyListeners();
    }
  }

  Future<String?> xerarCodigoQr() async {
    _erro = null;
    final resultados = await Future.wait<String?>([_obterUid(), _obterToken()]);
    final uid = resultados[0];
    final token = resultados[1];
    if (uid == null || token == null) {
      _erro = 'Non se puido xerar o código QR';
      notifyListeners();
      return null;
    }
    try {
      return await _cifrado.xerarCodigoVinculacion(
        uidPaciente: uid,
        tokenPaciente: token,
      );
    } catch (e) {
      _erro = 'Non se puido xerar o código QR';
      notifyListeners();
      return null;
    }
  }
}
