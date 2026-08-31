import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_sintrom/modelos/cabeceira.dart';
import 'package:tfg_sintrom/modelos/historico.dart';
import 'package:tfg_sintrom/modelos_vista/progreso.dart';

void main() {
  test('normaliza valores e calcula as métricas de puntualidade', () async {
    final vm = ProgresoViewModel.conDependencias(
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
    expect(ProgresoViewModel.numero(null), isNull);
    expect(ProgresoViewModel.numero('sen datos'), isNull);
    expect(ProgresoViewModel.numero('1/2'), 0.5);
    expect(ProgresoViewModel.numero('1+1/2 mg'), 1.5);
    expect(ProgresoViewModel.numero('1/0'), isNull);
    expect(ProgresoViewModel.numero('-2,5 mg'), -2.5);
  });

  test('sen rexistros non inventa unha desviación media', () async {
    final vm = ProgresoViewModel.conDependencias(
      obterHistorico: () async => [],
      obterCabeceira: () async => null,
      obterCumprimento: () async => [],
    );
    await vm.cargar();
    expect(vm.inrActual, '--');
    expect(vm.doseActual, '--');
    expect(vm.desviacionMedia, isNull);
    expect(vm.valoresInr, isEmpty);
    expect(vm.valoresDose, isEmpty);
  });

  test('expón erro e recupera o estado de carga', () async {
    final vm = ProgresoViewModel.conDependencias(
      obterHistorico: () async => throw Exception('sqlite'),
      obterCabeceira: () async => null,
      obterCumprimento: () async => [],
    );
    await vm.cargar();
    expect(vm.erro, 'Non se puideron cargar os datos de progreso');
    expect(vm.cargando, isFalse);
  });
}
