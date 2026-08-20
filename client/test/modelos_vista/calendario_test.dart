import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_sintrom/modelos/cabeceira.dart';
import 'package:tfg_sintrom/modelos/dose_dia.dart';
import 'package:tfg_sintrom/modelos_vista/calendario.dart';

void main() {
  DoseDiaModel dia(String data, {String? dose = '1/2', bool control = false}) =>
      DoseDiaModel(
        data: data,
        dia: DateTime.parse(data).day,
        dose: dose,
        accion: control ? 'CONTROL' : 'TOMAR',
        eControl: control,
        diaSemanaTexto: 'LUNS',
      );

  test('carga a pauta e calcula cumprimento excluíndo controis', () async {
    var pechouVencidas = false;
    final vm = CalendarViewModel.conDependencias(
      pecharTomasVencidas: () async => pechouVencidas = true,
      obterPauta: () async => [
        dia('2026-08-18'),
        dia('2026-08-19'),
        dia('2026-08-20', control: true, dose: null),
      ],
      obterEstados: () async => {
        '2026-08-18': 'TOMADA',
        '2026-08-19': 'PENDENTE',
      },
      obterCabeceira: () async => CabeceiraModel(proximaVisita: '25/08/2026'),
      agora: () => DateTime(2026, 8, 20),
    );

    await vm.cargar();

    expect(pechouVencidas, isTrue);
    expect(vm.cargando, isFalse);
    expect(vm.erro, isNull);
    expect(vm.tomadas, 1);
    expect(vm.esquecidas, 1);
    expect(vm.cumprimento, 50);
    expect(vm.diasAtaCita, 5);
  });

  test('expón un erro estable se falla a fonte de datos', () async {
    final vm = CalendarViewModel.conDependencias(
      pecharTomasVencidas: () async {},
      obterPauta: () async => throw Exception('base de datos non dispoñible'),
      obterEstados: () async => {},
      obterCabeceira: () async => null,
    );

    await vm.cargar();

    expect(vm.cargando, isFalse);
    expect(vm.erro, 'Non se puido cargar o calendario');
  });
}
