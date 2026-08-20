import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_sintrom/modelos/cabeceira.dart';
import 'package:tfg_sintrom/modelos/historico.dart';
import 'package:tfg_sintrom/modelos_vista/progreso.dart';

void main() {
  test('normaliza valores e calcula as métricas de puntualidade', () async {
    final vm = ProgressViewModel.conDependencias(
      obterHistorico: () async => [
        ItemHistoricoModel(inr: '2,4', dose: '13,5 mg'),
      ],
      obterCabeceira: () async =>
          CabeceiraModel(inr: '2.8', doseSemanal: '14 mg'),
      obterCumprimento: () async => [
        {'estado': 'TOMADA', 'desviacionMinutos': -10},
        {'estado': 'TOMADA_FORA_HORA', 'desviacionMinutos': 30},
        {'estado': 'NON_TOMADA'},
      ],
    );

    await vm.cargar();

    expect(vm.erro, isNull);
    expect(vm.valoresInr, [2.4, 2.8]);
    expect(vm.valoresDose, [13.5, 14]);
    expect(vm.tomasForaDeHora, 1);
    expect(vm.desviacionMedia, 20);
  });

  test('numero rexeita texto sen unha cantidade', () {
    expect(ProgressViewModel.numero(null), isNull);
    expect(ProgressViewModel.numero('sen datos'), isNull);
    expect(ProgressViewModel.numero('1/2'), 0.5);
    expect(ProgressViewModel.numero('1+1/2 mg'), 1.5);
  });
}
