import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_sintrom/servizos/inicializador_aplicacion.dart';

void main() {
  late Map<String, String> storage;
  late List<String> eventos;
  late Map<String, String> estados;

  InicializadorAplicacion crearInicializador() =>
      InicializadorAplicacion.conDependencias(
        inicializarFirebase: () async => eventos.add('firebase'),
        rexistrarBackground: (_) => eventos.add('background'),
        solicitarPermisos: () async => eventos.add('permisos'),
        inicializarNotificacions: () async => eventos.add('notificacions'),
        escoitarMensaxes: (_) => eventos.add('foreground'),
        procesarMensaxe: (_) async {},
        ler: (key) async => storage[key],
        programarTomas: ({required nome, required hora}) async {
          eventos.add('programar:$nome:$hora');
        },
        obterEstados: () async => estados,
        cancelarEsquecemento: ({required identificador}) async {
          eventos.add('cancelar:$identificador');
        },
        agora: () => DateTime(2026, 8, 21),
      );

  Future<void> background(RemoteMessage _) async {}

  setUp(() {
    storage = {};
    eventos = [];
    estados = {};
  });

  test('inicializa as plataformas e detecta unha app sen configurar', () async {
    final resultado = await crearInicializador().inicializar(
      backgroundHandler: background,
    );

    expect(resultado.xaConfigurado, isFalse);
    expect(resultado.rolUsuario, isNull);
    expect(eventos, [
      'firebase',
      'background',
      'permisos',
      'notificacions',
      'foreground',
    ]);
  });

  test(
    'un supervisor configurado non restaura recordatorios de toma',
    () async {
      storage = {
        'configuracion_finalizada': 'true',
        'rol_usuario': 'SUPERVISOR',
        'hora_toma': '20:00',
      };
      final resultado = await crearInicializador().inicializar(
        backgroundHandler: background,
      );

      expect(resultado.xaConfigurado, isTrue);
      expect(resultado.rolUsuario, 'SUPERVISOR');
      expect(eventos.where((e) => e.startsWith('programar')), isEmpty);
    },
  );

  test(
    'restaura avisos do paciente e cancela o esquecemento xa tomado',
    () async {
      storage = {
        'configuracion_finalizada': 'true',
        'rol_usuario': 'PACIENTE',
        'hora_toma': '20:30',
        'nome_usuario': 'Ana',
      };
      estados['2026-08-21'] = 'TOMADA_FORA_HORA';

      await crearInicializador().inicializar(backgroundHandler: background);

      expect(eventos, contains('programar:Ana:20:30'));
      expect(eventos, contains('cancelar:paciente_local'));
    },
  );

  test('non programa sen hora nin cancela unha toma pendente', () async {
    storage = {'configuracion_finalizada': 'true', 'rol_usuario': 'PACIENTE'};
    await crearInicializador().inicializar(backgroundHandler: background);
    expect(eventos.where((e) => e.startsWith('programar')), isEmpty);

    eventos.clear();
    storage['hora_toma'] = '20:00';
    estados['2026-08-21'] = 'PENDENTE';
    await crearInicializador().inicializar(backgroundHandler: background);
    expect(eventos, contains('programar::20:00'));
    expect(eventos.where((e) => e.startsWith('cancelar')), isEmpty);
  });
}
