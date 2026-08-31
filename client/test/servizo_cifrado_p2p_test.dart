import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tfg_sintrom/servizos/servizo_cifrado_p2p.dart';

void main() {
  final clave = base64Encode(List<int>.generate(32, (i) => i));
  final outraClave = base64Encode(List<int>.generate(32, (i) => 31 - i));
  const vinculacionId = 'vinculacion-de-proba';
  late ServizoCifradoP2P servizo;
  late VinculacionP2P vinculacion;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    servizo = ServizoCifradoP2P();
    vinculacion = VinculacionP2P(
      id: vinculacionId,
      uidRemoto: 'uid-remoto',
      tokenRemoto: 'token-remoto',
      claveBase64: clave,
      rolRemoto: 'SUPERVISOR',
    );
  });

  test('cifra e descifra un payload mantendo o contido', () async {
    const payload = '{"dose":"1/2","inr":"2.4"}';
    final envelope = await servizo.cifrarPayload(
      vinculacion: vinculacion,
      tipoAviso: 'ESTADO_COMPLETO',
      payload: payload,
    );

    expect(envelope, isNot(contains('2.4')));
    final resultado = await servizo.descifrarPayloadConClave(
      envelope: envelope,
      tipoAviso: 'ESTADO_COMPLETO',
      claveBase64: clave,
    );

    expect(resultado.vinculacionId, vinculacionId);
    expect(resultado.contido, payload);
  });

  test('xera claves permanentes independentes de 256 bits', () async {
    final primeira = await servizo.xerarClaveBase64();
    final segunda = await servizo.xerarClaveBase64();

    expect(base64Decode(primeira), hasLength(32));
    expect(base64Decode(segunda), hasLength(32));
    expect(segunda, isNot(primeira));
  });

  test('rexeita a mensaxe cando se emprega outra clave', () async {
    final envelope = await servizo.cifrarPayload(
      vinculacion: vinculacion,
      tipoAviso: 'TOMA_CONFIRMADA',
      payload: '{"estado":"TOMADA"}',
    );

    expect(
      () => servizo.descifrarPayloadConClave(
        envelope: envelope,
        tipoAviso: 'TOMA_CONFIRMADA',
        claveBase64: outraClave,
      ),
      throwsA(isA<MensaxeP2PNonValida>()),
    );
  });

  test('rexeita a modificación do tipo de aviso', () async {
    final envelope = await servizo.cifrarPayload(
      vinculacion: vinculacion,
      tipoAviso: 'TOMA_CONFIRMADA',
      payload: '{"estado":"TOMADA"}',
    );

    expect(
      () => servizo.descifrarPayloadConClave(
        envelope: envelope,
        tipoAviso: 'NOVO_INFORME',
        claveBase64: clave,
      ),
      throwsA(isA<MensaxeP2PNonValida>()),
    );
  });

  test('rexeita un payload cifrado que foi alterado', () async {
    final envelope = await servizo.cifrarPayload(
      vinculacion: vinculacion,
      tipoAviso: 'ESTADO_COMPLETO',
      payload: '{"estado":"PENDENTE"}',
    );
    final json = jsonDecode(envelope) as Map<String, dynamic>;
    final bytes = base64Decode(json['datos'] as String);
    bytes[0] ^= 1;
    json['datos'] = base64Encode(bytes);

    expect(
      () => servizo.descifrarPayloadConClave(
        envelope: jsonEncode(json),
        tipoAviso: 'ESTADO_COMPLETO',
        claveBase64: clave,
      ),
      throwsA(isA<MensaxeP2PNonValida>()),
    );
  });

  test('interpreta un código QR seguro', () {
    final codigo = jsonEncode({
      'version': 1,
      'vinculacionId': vinculacionId,
      'uidPaciente': 'uid-paciente',
      'tokenPaciente': 'token-paciente',
      'clave': clave,
    });

    final datos = servizo.lerCodigoVinculacion(codigo);

    expect(datos.id, vinculacionId);
    expect(datos.uidPaciente, 'uid-paciente');
    expect(datos.tokenPaciente, 'token-paciente');
    expect(datos.claveBase64, clave);
  });

  test('elimina só a vinculación seleccionada', () async {
    final outraVinculacion = VinculacionP2P(
      id: 'segunda-vinculacion',
      uidRemoto: 'outro-uid',
      tokenRemoto: 'outro-token',
      claveBase64: outraClave,
      rolRemoto: 'SUPERVISOR',
    );
    await servizo.gardarVinculacion(vinculacion);
    await servizo.gardarVinculacion(outraVinculacion);

    await servizo.eliminarPorId(vinculacion.id);

    expect(await servizo.obterPorId(vinculacion.id), isNull);
    expect(
      (await servizo.obterPorId(outraVinculacion.id))?.tokenRemoto,
      outraVinculacion.tokenRemoto,
    );
  });

  test('serializa, copia e converte os datos do QR', () {
    final json = vinculacion.toJson();
    final restaurada = VinculacionP2P.fromJson(json);
    expect(restaurada.id, vinculacion.id);
    expect(restaurada.uidRemoto, vinculacion.uidRemoto);
    expect(restaurada.tokenRemoto, vinculacion.tokenRemoto);
    expect(restaurada.claveBase64, vinculacion.claveBase64);
    expect(restaurada.rolRemoto, 'SUPERVISOR');

    final copiada = restaurada.copyWith(
      tokenRemoto: 'novo-token',
      claveBase64: outraClave,
    );
    expect(copiada.uidRemoto, restaurada.uidRemoto);
    expect(copiada.tokenRemoto, 'novo-token');
    expect(copiada.claveBase64, outraClave);

    final paciente = const DatosQrVinculacion(
      id: 'qr1',
      uidPaciente: 'uid-paciente',
      tokenPaciente: 'token-paciente',
      claveBase64: 'clave',
    ).comoPacienteRemoto();
    expect(paciente.rolRemoto, 'PACIENTE');
    expect(paciente.uidRemoto, 'uid-paciente');
    expect(const MensaxeP2PNonValida('erro').toString(), 'erro');
  });

  test('rexeita versión, campos e formato incorrectos do QR', () {
    String codigo({
      Object version = 1,
      String id = vinculacionId,
      String uid = 'uid',
      String token = 'token',
      String? claveQr,
    }) => jsonEncode({
      'version': version,
      'vinculacionId': id,
      'uidPaciente': uid,
      'tokenPaciente': token,
      'clave': claveQr ?? clave,
    });

    expect(
      () => servizo.lerCodigoVinculacion(codigo(version: 2)),
      throwsA(predicate((e) => e.toString().contains('Versión'))),
    );
    expect(
      () => servizo.lerCodigoVinculacion(codigo(id: '')),
      throwsA(predicate((e) => e.toString().contains('incompleto'))),
    );
    expect(
      () => servizo.lerCodigoVinculacion(codigo(claveQr: base64Encode([1]))),
      throwsA(predicate((e) => e.toString().contains('incompleto'))),
    );
    expect(
      () => servizo.lerCodigoVinculacion('non-json'),
      throwsA(predicate((e) => e.toString().contains('non válido'))),
    );
  });

  test('un novo QR invalida a clave pendente anterior', () async {
    const storage = FlutterSecureStorage();
    final primeiro =
        jsonDecode(
              await servizo.xerarCodigoVinculacion(
                uidPaciente: 'uid',
                tokenPaciente: 'token',
              ),
            )
            as Map<String, dynamic>;
    final segundo =
        jsonDecode(
              await servizo.xerarCodigoVinculacion(
                uidPaciente: 'uid',
                tokenPaciente: 'token',
              ),
            )
            as Map<String, dynamic>;

    expect(primeiro['vinculacionId'], isNot(segundo['vinculacionId']));
    expect(
      await storage.read(
        key: 'p2p_clave_pendente_${primeiro['vinculacionId']}',
      ),
      isNull,
    );
    expect(
      await storage.read(key: 'p2p_vinculacion_pendente_actual'),
      segundo['vinculacionId'],
    );
  });

  test(
    'descifra mediante unha vinculación gardada ou unha clave pendente',
    () async {
      await servizo.gardarVinculacion(vinculacion);
      final envelope = await servizo.cifrarPayload(
        vinculacion: vinculacion,
        tipoAviso: 'ESTADO_COMPLETO',
        payload: 'gardado',
      );
      expect(
        (await servizo.descifrarPayload(
          envelope: envelope,
          tipoAviso: 'ESTADO_COMPLETO',
        )).contido,
        'gardado',
      );

      FlutterSecureStorage.setMockInitialValues({});
      servizo = ServizoCifradoP2P();
      final codigo = await servizo.xerarCodigoVinculacion(
        uidPaciente: 'uid',
        tokenPaciente: 'token',
      );
      final datos = servizo.lerCodigoVinculacion(codigo);
      final pendente = datos.comoPacienteRemoto();
      final envelopePendente = await servizo.cifrarPayload(
        vinculacion: pendente,
        tipoAviso: 'VINCULACION_INICIAL',
        payload: 'pendente',
      );
      expect(
        (await servizo.descifrarPayload(
          envelope: envelopePendente,
          tipoAviso: 'VINCULACION_INICIAL',
          permitirClavePendente: true,
        )).contido,
        'pendente',
      );
    },
  );

  test('rexeita mensaxes descoñecidas e versións incompatibles', () async {
    final mensaxeDesconecida = await servizo.cifrarPayload(
      vinculacion: vinculacion,
      tipoAviso: 'AVISO',
      payload: 'contido',
    );
    expect(
      servizo.descifrarPayload(
        envelope: mensaxeDesconecida,
        tipoAviso: 'AVISO',
      ),
      throwsA(predicate((e) => e.toString().contains('non pertence'))),
    );

    final json = jsonDecode(mensaxeDesconecida) as Map<String, dynamic>;
    json['version'] = 99;
    expect(
      servizo.descifrarPayloadConClave(
        envelope: jsonEncode(json),
        tipoAviso: 'AVISO',
        claveBase64: clave,
      ),
      throwsA(predicate((e) => e.toString().contains('Versión'))),
    );
  });

  test('confirma unha vinculación pendente cunha clave permanente', () async {
    const storage = FlutterSecureStorage();
    final codigo = await servizo.xerarCodigoVinculacion(
      uidPaciente: 'uid',
      tokenPaciente: 'token',
    );
    final datos = servizo.lerCodigoVinculacion(codigo);

    await servizo.confirmarVinculacionPendente(
      id: datos.id,
      uidSupervisor: 'supervisor',
      tokenSupervisor: 'token-supervisor',
      clavePermanenteBase64: outraClave,
    );

    final confirmada = await servizo.obterPorId(datos.id);
    expect(confirmada?.rolRemoto, 'SUPERVISOR');
    expect(confirmada?.claveBase64, outraClave);
    expect(await storage.read(key: 'p2p_clave_pendente_${datos.id}'), isNull);
    expect(await storage.read(key: 'p2p_vinculacion_pendente_actual'), isNull);
  });

  test(
    'rexeita confirmación ausente ou cunha clave permanente incorrecta',
    () async {
      expect(
        servizo.confirmarVinculacionPendente(
          id: 'inexistente',
          uidSupervisor: 'uid',
          tokenSupervisor: 'token',
          clavePermanenteBase64: clave,
        ),
        throwsA(
          predicate((e) => e.toString().contains('xa non está pendente')),
        ),
      );

      final codigo = await servizo.xerarCodigoVinculacion(
        uidPaciente: 'uid',
        tokenPaciente: 'token',
      );
      final id = (jsonDecode(codigo) as Map<String, dynamic>)['vinculacionId'];
      expect(
        servizo.confirmarVinculacionPendente(
          id: id as String,
          uidSupervisor: 'uid',
          tokenSupervisor: 'token',
          clavePermanenteBase64: 'incorrecta',
        ),
        throwsA(predicate((e) => e.toString().contains('non válida'))),
      );
    },
  );

  test(
    'filtra, substitúe, elimina por UID e tolera storage corrupto',
    () async {
      final paciente = VinculacionP2P(
        id: 'paciente',
        uidRemoto: 'uid-paciente',
        tokenRemoto: 'token-paciente',
        claveBase64: clave,
        rolRemoto: 'PACIENTE',
      );
      await servizo.gardarVinculacion(vinculacion);
      await servizo.gardarVinculacion(paciente);
      expect(await servizo.obterPorRolRemoto('SUPERVISOR'), hasLength(1));
      expect((await servizo.obterPorToken('token-paciente'))?.id, 'paciente');
      expect((await servizo.obterPorUid('uid-paciente'))?.id, 'paciente');

      await servizo.gardarVinculacion(
        paciente.copyWith(tokenRemoto: 'token-novo'),
      );
      expect(await servizo.obterVinculacions(), hasLength(2));
      expect(
        (await servizo.obterPorUid('uid-paciente'))?.tokenRemoto,
        'token-novo',
      );
      await servizo.eliminarPorUid('uid-paciente');
      expect(await servizo.obterPorUid('uid-paciente'), isNull);

      FlutterSecureStorage.setMockInitialValues({
        'p2p_vinculacions_seguras': 'json corrupto',
      });
      expect(await ServizoCifradoP2P().obterVinculacions(), isEmpty);
    },
  );
}
