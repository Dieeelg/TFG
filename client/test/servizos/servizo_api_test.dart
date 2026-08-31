import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tfg_sintrom/nucleo/constantes.dart';
import 'package:tfg_sintrom/servizos/servizo_api.dart';

void main() {
  test(
    'estado distingue resposta correcta, erro HTTP e erro de rede',
    () async {
      final ok = ServizoApi(
        client: MockClient((request) async {
          expect(request.url.path, ConstantesAplicacion.endpointEstado);
          return http.Response('', 200);
        }),
      );
      expect(await ok.comprobarEstado(), isTrue);

      final erroHttp = ServizoApi(
        client: MockClient((_) async => http.Response('', 503)),
      );
      expect(await erroHttp.comprobarEstado(), isFalse);

      final erroRede = ServizoApi(
        client: MockClient(
          (_) async => throw const SocketException('sen rede'),
        ),
      );
      expect(await erroRede.comprobarEstado(), isFalse);
    },
  );

  test('buscar centro codifica a consulta e interpreta a resposta', () async {
    final api = ServizoApi(
      client: MockClient((request) async {
        expect(request.url.path, ConstantesAplicacion.endpointCentro);
        expect(request.url.queryParameters['nome'], 'A Coruña');
        return http.Response(
          jsonEncode({'nome': 'Centro', 'telefono': '981'}),
          200,
        );
      }),
    );

    expect(await api.buscarCentro('A Coruña'), {
      'nome': 'Centro',
      'telefono': '981',
    });
  });

  test('buscar centro conserva o detalle de erro da API', () async {
    final api = ServizoApi(
      client: MockClient(
        (_) async => http.Response(jsonEncode({'detail': 'Non atopado'}), 404),
      ),
    );
    expect(
      api.buscarCentro('Descoñecido'),
      throwsA(predicate((e) => e.toString().contains('Non atopado'))),
    );
  });

  test('envía unha notificación co contrato JSON esperado', () async {
    final api = ServizoApi(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, ConstantesAplicacion.endpointEnviarNotif);
        expect(request.headers['content-type'], contains('application/json'));
        expect(jsonDecode(request.body), {
          'token_destino': 'token',
          'payload': 'cifrado',
          'tipo_aviso': 'TOMA_CONFIRMADA',
        });
        return http.Response('', 200);
      }),
    );

    expect(
      await api.enviarNotificacion(
        tokenDestino: 'token',
        payload: 'cifrado',
        tipoAviso: 'TOMA_CONFIRMADA',
      ),
      isTrue,
    );
  });

  test('notificación devolve false ante HTTP ou rede', () async {
    final erroHttp = ServizoApi(
      client: MockClient((_) async => http.Response('', 500)),
    );
    expect(
      await erroHttp.enviarNotificacion(
        tokenDestino: 't',
        payload: 'p',
        tipoAviso: 'A',
      ),
      isFalse,
    );

    final erroRede = ServizoApi(
      client: MockClient((_) async => throw const SocketException('sen rede')),
    );
    expect(
      await erroRede.enviarNotificacion(
        tokenDestino: 't',
        payload: 'p',
        tipoAviso: 'A',
      ),
      isFalse,
    );
  });

  test('sube multipart e converte a análise recibida', () async {
    final temporal = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}sintrom-api-test.jpg',
    );
    await temporal.writeAsBytes([1, 2, 3]);
    addTearDown(() => temporal.deleteSync());

    final api = ServizoApi(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, ConstantesAplicacion.endpointExtraccion);
        expect(
          request.headers['content-type'],
          contains('multipart/form-data'),
        );
        expect(request.bodyBytes, isNotEmpty);
        return http.Response(
          jsonEncode({
            'cabeceira': {
              'dataInforme': '2026-08-20',
              'inr': '2,5',
              'farmaco': 'Sintrom',
              'doseSemanal': '7',
              'proximaVisita': '27/08/2026',
              'centro': 'Centro',
            },
            'calendario': [
              {
                'data': '2026-08-21',
                'dia': 21,
                'dose': '1/2',
                'accion': 'TOMAR',
                'eControl': false,
                'diaSemanaTexto': 'VENRES',
              },
            ],
            'historico': [],
          }),
          200,
        );
      }),
    );

    final analise = await api.enviarInforme(temporal);
    expect(analise.cabeceira.inr, '2,5');
    expect(analise.calendario.single.dose, '1/2');
  });

  test('subida encapsula tanto o detalle HTTP como o fallo de rede', () async {
    final temporal = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}sintrom-api-error.jpg',
    );
    await temporal.writeAsBytes([1]);
    addTearDown(() => temporal.deleteSync());

    final erroHttp = ServizoApi(
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode({'detail': 'Imaxe borrosa'}), 422),
      ),
    );
    expect(
      erroHttp.enviarInforme(temporal),
      throwsA(predicate((e) => e.toString().contains('Imaxe borrosa'))),
    );

    final erroRede = ServizoApi(
      client: MockClient((_) async => throw const SocketException('sen rede')),
    );
    expect(
      erroRede.enviarInforme(temporal),
      throwsA(predicate((e) => e.toString().contains('Erro de conexión'))),
    );
  });
}
