import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_sintrom/modelos_vista/autenticacion/vinculacion_coidador.dart';
import 'package:tfg_sintrom/modelos_vista/autenticacion/vinculacion_paciente.dart';
import 'package:tfg_sintrom/servizos/servizo_cifrado_p2p.dart';

void main() {
  group('VinculacionPacienteViewModel', () {
    test('xera o QR con UID e token e remata a carga', () async {
      String? entrada;
      final vm = VinculacionPacienteViewModel.conDependencias(
        obterUid: () async => 'paciente-1',
        obterToken: () async => 'token-paciente',
        xerarCodigo: ({required uidPaciente, required tokenPaciente}) async {
          entrada = '$uidPaciente:$tokenPaciente';
          return 'codigo-qr';
        },
        ler: (_) async => null,
      );

      await vm.xerarDatosVinculacion();
      expect(entrada, 'paciente-1:token-paciente');
      expect(vm.datosQR, 'codigo-qr');
      expect(vm.cargando, isFalse);
      vm.dispose();
    });

    test(
      'usa un UID seguro por defecto e controla token e cifrado erróneos',
      () async {
        String? uidUsado;
        final senUid = VinculacionPacienteViewModel.conDependencias(
          obterUid: () async => null,
          obterToken: () async => 'token',
          xerarCodigo: ({required uidPaciente, required tokenPaciente}) async {
            uidUsado = uidPaciente;
            return 'qr';
          },
          ler: (_) async => null,
        );
        await senUid.xerarDatosVinculacion();
        expect(uidUsado, 'sen_id');

        final senToken = VinculacionPacienteViewModel.conDependencias(
          obterUid: () async => 'uid',
          obterToken: () async => '',
          xerarCodigo: ({required uidPaciente, required tokenPaciente}) async =>
              'non debe executarse',
          ler: (_) async => null,
        );
        await senToken.xerarDatosVinculacion();
        expect(senToken.datosQR, 'erro_datos');

        final erro = VinculacionPacienteViewModel.conDependencias(
          obterUid: () async => 'uid',
          obterToken: () async => 'token',
          xerarCodigo: ({required uidPaciente, required tokenPaciente}) async =>
              throw Exception('cifrado'),
          ler: (_) async => null,
        );
        await erro.xerarDatosVinculacion();
        expect(erro.datosQR, 'erro_datos');
        senUid.dispose();
        senToken.dispose();
        erro.dispose();
      },
    );

    test('detecta unha vinculación gardada unha única vez', () async {
      var token = <String, String>{};
      final vm = VinculacionPacienteViewModel.conDependencias(
        obterUid: () async => 'uid',
        obterToken: () async => 'token',
        xerarCodigo: ({required uidPaciente, required tokenPaciente}) async =>
            'qr',
        ler: (key) async => token[key],
      );

      await vm.comprobarEstadoVinculacion();
      expect(vm.tenCoidador, isFalse);
      token['token_coidador'] = 'token-coidador';
      await vm.comprobarEstadoVinculacion();
      expect(vm.tenCoidador, isTrue);
      await vm.comprobarEstadoVinculacion();
      expect(vm.tenCoidador, isTrue);
      vm.dispose();
    });
  });

  group('VinculacionCoidadorViewModel', () {
    const datosQr = DatosQrVinculacion(
      id: 'v1',
      uidPaciente: 'paciente-1',
      tokenPaciente: 'token-paciente',
      claveBase64: 'clave-temporal',
    );

    late List<String> eventos;
    late Map<String, String> storage;
    late String? payloadClaro;

    VinculacionCoidadorViewModel crearVm({
      Future<bool> Function()? comprobarApi,
      DatosQrVinculacion Function(String)? lerCodigo,
      Future<String?> Function()? obterToken,
      Future<bool> Function({
        required String tokenDestino,
        required String payload,
        required String tipoAviso,
      })?
      enviar,
    }) => VinculacionCoidadorViewModel.conDependencias(
      comprobarApi: comprobarApi ?? () async => true,
      lerCodigo: lerCodigo ?? (_) => datosQr,
      xerarClave: () async => 'clave-permanente',
      obterToken: obterToken ?? () async => 'token-coidador',
      obterUid: () async => 'coidador-1',
      cifrarPayload:
          ({required vinculacion, required tipoAviso, required payload}) async {
            payloadClaro = payload;
            expect(vinculacion.claveBase64, 'clave-temporal');
            expect(tipoAviso, 'VINCULACION_INICIAL');
            return 'payload-cifrado';
          },
      enviarNotificacion:
          enviar ??
          ({
            required tokenDestino,
            required payload,
            required tipoAviso,
          }) async {
            eventos.add('enviar:$tokenDestino:$payload:$tipoAviso');
            return true;
          },
      gardarVinculacion: (vinculacion) async {
        eventos.add('vinculacion:${vinculacion.claveBase64}');
      },
      gardarPaciente: ({required uid, required token}) async {
        eventos.add('paciente:$uid:$token');
      },
      escribir: (key, value) async => storage[key] = value,
    );

    setUp(() {
      eventos = [];
      storage = {};
      payloadClaro = null;
    });

    test('completa o saúdo cifrado e persiste ambas as partes', () async {
      final vm = crearVm();

      expect(await vm.vincularPaciente('qr'), isTrue);
      expect(vm.escaneando, isFalse);
      expect(vm.erro, isNull);
      expect(jsonDecode(payloadClaro!), {
        'token': 'token-coidador',
        'coidadorUid': 'coidador-1',
        'clavePermanente': 'clave-permanente',
      });
      expect(eventos, [
        'enviar:token-paciente:payload-cifrado:VINCULACION_INICIAL',
        'vinculacion:clave-permanente',
        'paciente:paciente-1:token-paciente',
      ]);
      expect(storage['configuracion_finalizada'], 'true');
      expect(storage['rol_usuario'], 'COIDADOR');
    });

    test('detense se a API non responde ou falta token propio', () async {
      final senApi = crearVm(comprobarApi: () async => false);
      expect(await senApi.vincularPaciente('qr'), isFalse);
      expect(senApi.erro, contains('API non está dispoñible'));
      expect(eventos, isEmpty);

      final senToken = crearVm(obterToken: () async => null);
      expect(await senToken.vincularPaciente('qr'), isFalse);
      expect(senToken.erro, 'Non se puido identificar este dispositivo.');
    });

    test('non persiste cando falla a notificación inicial', () async {
      final vm = crearVm(
        enviar:
            ({
              required tokenDestino,
              required payload,
              required tipoAviso,
            }) async => false,
      );
      expect(await vm.vincularPaciente('qr'), isFalse);
      expect(vm.erro, contains('completar a vinculación'));
      expect(eventos, isEmpty);
      expect(storage, isEmpty);
    });

    test('distingue QR non válido de erro inesperado', () async {
      final qrInvalido = crearVm(
        lerCodigo: (_) => throw const MensaxeP2PNonValida('QR caducado'),
      );
      expect(await qrInvalido.vincularPaciente('qr'), isFalse);
      expect(qrInvalido.erro, 'QR caducado');

      final inesperado = crearVm(lerCodigo: (_) => throw StateError('fallo'));
      expect(await inesperado.vincularPaciente('qr'), isFalse);
      expect(inesperado.erro, contains('Erro inesperado'));
      expect(inesperado.escaneando, isFalse);
    });
  });
}
