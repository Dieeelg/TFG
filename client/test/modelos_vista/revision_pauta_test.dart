import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_sintrom/modelos/analise.dart';
import 'package:tfg_sintrom/modelos/cabeceira.dart';
import 'package:tfg_sintrom/modelos/dose_dia.dart';
import 'package:tfg_sintrom/modelos_vista/revision_pauta.dart';

void main() {
  AnaliseModel analise() => AnaliseModel(
    cabeceira: CabeceiraModel(proximaVisita: '25/08/2026'),
    calendario: [
      DoseDiaModel(
        data: '2026-08-22',
        dia: 22,
        dose: '1/2',
        accion: 'TOMAR',
        eControl: false,
        diaSemanaTexto: 'SÁBADO',
      ),
      DoseDiaModel(
        data: '2026-08-21',
        dia: 21,
        dose: '1',
        accion: 'TOMAR',
        eControl: false,
        diaSemanaTexto: 'VENRES',
      ),
    ],
    historico: const [],
  );

  test('ordena, edita e confirma unha pauta válida', () {
    final vm = RevisionPautaViewModel(analise());

    expect(vm.analise.calendario.first.data, '2026-08-21');
    vm.iniciarEdicion();
    vm.actualizarDia(0, dose: '3/4');

    expect(vm.editando, isTrue);
    expect(vm.revisarCorreccions(), isTrue);
    expect(vm.editando, isFalse);
    expect(vm.confirmar()?.calendario.first.dose, '3/4');
  });

  test('cancelar restaura a última revisión confirmada', () {
    final vm = RevisionPautaViewModel(analise());

    vm.iniciarEdicion();
    vm.eliminarDia(0);
    expect(vm.analise.calendario, hasLength(1));

    vm.cancelarCambios();
    expect(vm.analise.calendario, hasLength(2));
  });

  test('non confirma unha pauta baleira', () {
    final vm = RevisionPautaViewModel(analise());
    vm.eliminarDia(1);
    vm.eliminarDia(0);

    expect(vm.confirmar(), isNull);
    expect(vm.erro, 'A pauta debe conter polo menos un día.');
  });
}
