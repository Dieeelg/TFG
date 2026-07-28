import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_sintrom/servizos/planificador_recordatorios.dart';

void main() {
  test('identifica correctamente os días nos que non hai toma', () {
    for (final dose in [null, '', '0', '0.0', '0,0', '0/1', 'NON', 'CTRL']) {
      expect(
        PlanificadorRecordatorios.eDoseTomable(dose),
        isFalse,
        reason: 'A dose $dose non debe xerar un aviso',
      );
    }
    expect(PlanificadorRecordatorios.eDoseTomable('1/2'), isTrue);
    expect(PlanificadorRecordatorios.eDoseTomable('1'), isTrue);
  });

  test('programa avisos unicamente nas datas indicadas', () {
    final recordatorios = PlanificadorRecordatorios.crear(
      agora: DateTime(2026, 7, 28, 10),
      hora: '20:00',
      datasConToma: const ['2026-07-28', '2026-07-30'],
    );

    expect(recordatorios, hasLength(4));
    expect(recordatorios.map((recordatorio) => recordatorio.data).toSet(), {
      '2026-07-28',
      '2026-07-30',
    });
  });

  test('non recupera recordatorios dun día anterior', () {
    final recordatorios = PlanificadorRecordatorios.crear(
      agora: DateTime(2026, 7, 28, 10),
      hora: '20:00',
      datasConToma: const ['2026-07-27'],
    );

    expect(recordatorios, isEmpty);
  });

  test('unha toma confirmada non conserva avisos dese día', () {
    final recordatorios = PlanificadorRecordatorios.crear(
      agora: DateTime(2026, 7, 28, 10),
      hora: '20:00',
      datasConToma: const ['2026-07-28', '2026-07-29'],
      estados: const {'2026-07-28': 'TOMADA'},
    );

    expect(
      recordatorios.every((recordatorio) => recordatorio.data == '2026-07-29'),
      isTrue,
    );
  });

  test('despois da hora da toma mantén só o aviso de esquecemento', () {
    final recordatorios = PlanificadorRecordatorios.crear(
      agora: DateTime(2026, 7, 28, 20, 10),
      hora: '20:00',
      datasConToma: const ['2026-07-28'],
    );

    expect(recordatorios, hasLength(1));
    expect(recordatorios.single.tipo, TipoRecordatorioToma.esquecemento);
    expect(recordatorios.single.instante, DateTime(2026, 7, 28, 20, 30));
  });

  test('ignora unha hora non válida', () {
    final recordatorios = PlanificadorRecordatorios.crear(
      agora: DateTime(2026, 7, 28, 10),
      hora: '25:00',
      datasConToma: const ['2026-07-28'],
    );

    expect(recordatorios, isEmpty);
  });
}
