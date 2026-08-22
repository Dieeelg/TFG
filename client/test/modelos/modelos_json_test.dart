import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_sintrom/modelos/analise.dart';
import 'package:tfg_sintrom/modelos/cabeceira.dart';
import 'package:tfg_sintrom/modelos/dose_dia.dart';
import 'package:tfg_sintrom/modelos/historico.dart';

void main() {
  test('AnaliseModel.fromJson converte todas as capas do contrato OCR', () {
    final analise = AnaliseModel.fromJson({
      'cabeceira': {
        'dataInforme': '2026-08-20',
        'inr': '2,5',
        'farmaco': 'Sintrom',
        'doseSemanal': '7 mg',
        'proximaVisita': '27/08/2026',
        'centro': 'Centro A',
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
      'historico': [
        {
          'data': '2026-08-01',
          'inr': '2,3',
          'farmaco': 'Sintrom',
          'dose': '6,5 mg',
          'apttInyectable': 'Non',
          'doseInyectable': null,
          'proximaVisita': '20/08/2026',
          'comentarios': 'Correcto',
        },
      ],
    });

    expect(analise.cabeceira.dataInforme, '2026-08-20');
    expect(analise.cabeceira.inr, '2,5');
    expect(analise.cabeceira.farmaco, 'Sintrom');
    expect(analise.cabeceira.doseSemanal, '7 mg');
    expect(analise.cabeceira.proximaVisita, '27/08/2026');
    expect(analise.cabeceira.centro, 'Centro A');
    expect(analise.calendario.single.data, '2026-08-21');
    expect(analise.calendario.single.dia, 21);
    expect(analise.calendario.single.dose, '1/2');
    expect(analise.calendario.single.accion, 'TOMAR');
    expect(analise.calendario.single.eControl, isFalse);
    expect(analise.calendario.single.diaSemanaTexto, 'VENRES');
    expect(analise.historico.single.data, '2026-08-01');
    expect(analise.historico.single.inr, '2,3');
    expect(analise.historico.single.farmaco, 'Sintrom');
    expect(analise.historico.single.dose, '6,5 mg');
    expect(analise.historico.single.apttInyectable, 'Non');
    expect(analise.historico.single.doseInyectable, isNull);
    expect(analise.historico.single.proximaVisita, '20/08/2026');
    expect(analise.historico.single.comentarios, 'Correcto');
  });

  test('os modelos admiten campos opcionais ausentes', () {
    final cabeceira = CabeceiraModel.fromJson(<String, dynamic>{});
    final historico = ItemHistoricoModel.fromJson(<String, dynamic>{});
    expect(cabeceira.dataInforme, isNull);
    expect(cabeceira.centro, isNull);
    expect(historico.data, isNull);
    expect(historico.comentarios, isNull);
  });

  test('DoseDiaModel conserva un día de control sen dose', () {
    final control = DoseDiaModel.fromJson({
      'data': '2026-08-27',
      'dia': 27,
      'dose': null,
      'accion': 'CONTROL',
      'eControl': true,
      'diaSemanaTexto': 'XOVES',
    });
    expect(control.eControl, isTrue);
    expect(control.dose, isNull);
  });
}
