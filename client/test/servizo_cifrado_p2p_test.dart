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
      rolRemoto: 'COIDADOR',
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
      rolRemoto: 'COIDADOR',
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
}
