import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_sintrom/modelos/analise.dart';
import 'package:tfg_sintrom/modelos/cabeceira.dart';
import 'package:tfg_sintrom/modelos/dose_dia.dart';
import 'package:tfg_sintrom/modelos/revision_pauta.dart';

void main() {
  AnaliseModel analiseValida() => AnaliseModel(
    cabeceira: CabeceiraModel(
      dataInforme: '2026-08-07',
      farmaco: 'Sintrom 4 mg',
      proximaVisita: '12/08/2026',
    ),
    calendario: [
      DoseDiaModel(
        data: '2026-08-08',
        dia: 8,
        dose: '1/2',
        accion: 'TOMAR',
        eControl: false,
        diaSemanaTexto: 'SÁBADO',
      ),
      DoseDiaModel(
        data: '2026-08-12',
        dia: 12,
        dose: null,
        accion: 'CONTROL',
        eControl: true,
        diaSemanaTexto: 'MÉRCORES',
      ),
    ],
    historico: const [],
  );

  test('acepta unha pauta coherente', () {
    expect(RevisionPauta.validar(analiseValida()), isEmpty);
  });

  test('rexeita datas repetidas e doses baleiras', () {
    final base = analiseValida();
    final incorrecta = AnaliseModel(
      cabeceira: base.cabeceira,
      calendario: [
        base.calendario.first,
        DoseDiaModel(
          data: '2026-08-08',
          dia: 8,
          dose: '',
          accion: 'TOMAR',
          eControl: false,
          diaSemanaTexto: 'SÁBADO',
        ),
      ],
      historico: const [],
    );

    final erros = RevisionPauta.validar(incorrecta);
    expect(erros, contains('A data 2026-08-08 está repetida.'));
    expect(erros, contains('Falta a dose do 2026-08-08.'));
  });

  test('actualiza a data e os campos derivados do día', () {
    final actualizada = RevisionPauta.actualizarDia(
      analiseValida(),
      0,
      data: DateTime(2026, 8, 10),
      dose: '0',
    );

    final dia = actualizada.calendario.first;
    expect(dia.data, '2026-08-10');
    expect(dia.dia, 10);
    expect(dia.diaSemanaTexto, 'LUNS');
    expect(dia.accion, 'NON TOMAR');
  });

  test('un día de control non conserva unha dose', () {
    final actualizada = RevisionPauta.actualizarDia(
      analiseValida(),
      0,
      eControl: true,
    );

    final dia = actualizada.calendario.first;
    expect(dia.eControl, isTrue);
    expect(dia.dose, isNull);
    expect(dia.accion, 'CONTROL');
  });

  test('interpreta datas ISO e europeas e rexeita datas imposibles', () {
    expect(RevisionPauta.interpretarData('2026-08-21'), DateTime(2026, 8, 21));
    expect(RevisionPauta.interpretarData('21/8/2026'), DateTime(2026, 8, 21));
    expect(RevisionPauta.interpretarData('31/02/2026'), isNull);
    expect(RevisionPauta.interpretarData('texto'), isNull);
    expect(RevisionPauta.interpretarData(''), isNull);
  });

  test('actualiza a visita, elimina, insire e ordena', () {
    var actualizada = RevisionPauta.actualizarProximaVisita(
      analiseValida(),
      DateTime(2026, 9, 1),
    );
    expect(actualizada.cabeceira.proximaVisita, '01/09/2026');

    final eliminado = actualizada.calendario.first;
    actualizada = RevisionPauta.eliminarDia(actualizada, 0);
    expect(actualizada.calendario, hasLength(1));
    actualizada = RevisionPauta.inserirDia(actualizada, 1, eliminado);
    expect(actualizada.calendario, hasLength(2));
    expect(
      RevisionPauta.ordenar(actualizada).calendario.first.data,
      '2026-08-08',
    );

    actualizada = RevisionPauta.actualizarProximaVisita(actualizada, null);
    expect(actualizada.cabeceira.proximaVisita, isNull);
  });

  test('valida calendario baleiro, data, visita e formatos de dose', () {
    AnaliseModel conDose(String dose) => AnaliseModel(
      cabeceira: CabeceiraModel(proximaVisita: 'data incorrecta'),
      calendario: [
        DoseDiaModel(
          data: 'data incorrecta',
          dia: 1,
          dose: dose,
          accion: 'TOMAR',
          eControl: false,
          diaSemanaTexto: 'LUNS',
        ),
      ],
      historico: const [],
    );

    expect(
      RevisionPauta.validar(
        AnaliseModel(
          cabeceira: CabeceiraModel(),
          calendario: const [],
          historico: const [],
        ),
      ),
      ['A pauta debe conter polo menos un día.'],
    );
    final erros = RevisionPauta.validar(conDose('1/0'));
    expect(erros, contains('A data da fila 1 non é válida.'));
    expect(erros, contains('A dose «1/0» do data incorrecta non é válida.'));
    expect(erros, contains('A data da seguinte visita non é válida.'));

    for (final dose in ['0', '1.5', '1/2', '1+1/2']) {
      final valida = analiseValida();
      final modificada = RevisionPauta.actualizarDia(valida, 0, dose: dose);
      expect(RevisionPauta.validar(modificada), isEmpty, reason: dose);
    }
  });
}
