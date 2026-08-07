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
}
