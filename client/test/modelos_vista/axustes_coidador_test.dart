import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_sintrom/modelos_vista/axustes_coidador.dart';

void main() {
  test('carga pacientes e calcula nomes visibles', () async {
    final vm = CaregiverSettingsViewModel.conDependencias(
      obterPacientes: () async => [
        {
          'uid': '1',
          'token': 't1',
          'datos': {'nome': ' Ana '},
        },
        {'uid': '2', 'token': 't2', 'datos': <String, dynamic>{}},
      ],
      desvincularPaciente: ({required uid, required tokenPaciente}) async {},
    );

    await vm.cargar();

    expect(vm.pacientes, hasLength(2));
    expect(vm.nomePaciente(0), 'Ana');
    expect(vm.nomePaciente(1), 'Persoa 2');
    expect(vm.erro, isNull);
  });

  test('elimina, recarga e limpa o indicador', () async {
    var pacientes = [
      {'uid': '1', 'token': 't1', 'datos': <String, dynamic>{}},
    ];
    String? eliminado;
    final vm = CaregiverSettingsViewModel.conDependencias(
      obterPacientes: () async => pacientes,
      desvincularPaciente: ({required uid, required tokenPaciente}) async {
        eliminado = '$uid:$tokenPaciente';
        pacientes = [];
      },
    );
    await vm.cargar();

    expect(await vm.eliminar(vm.pacientes.first), isTrue);
    expect(eliminado, '1:t1');
    expect(vm.pacientes, isEmpty);
    expect(vm.eliminandoUid, isNull);
  });

  test('diferencia os erros de carga e eliminación', () async {
    final vmCarga = CaregiverSettingsViewModel.conDependencias(
      obterPacientes: () async => throw Exception('sqlite'),
      desvincularPaciente: ({required uid, required tokenPaciente}) async {},
    );
    await vmCarga.cargar();
    expect(vmCarga.erro, 'Non se puideron cargar os pacientes');

    final vmEliminar = CaregiverSettingsViewModel.conDependencias(
      obterPacientes: () async => [],
      desvincularPaciente: ({required uid, required tokenPaciente}) async {
        throw Exception('non autorizado');
      },
    );
    expect(
      await vmEliminar.eliminar({
        'uid': '1',
        'token': 't1',
        'datos': <String, dynamic>{},
      }),
      isFalse,
    );
    expect(vmEliminar.erro, 'non autorizado');
  });
}
