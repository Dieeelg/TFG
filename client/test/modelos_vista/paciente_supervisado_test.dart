import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_sintrom/modelos_vista/paciente_supervisado.dart';

import '../axuda/datos_proba.dart';

void main() {
  test('calcula nome, INR e dose con formatos locais', () {
    final vm = PacienteSupervisadoViewModel.conDependencias(
      paciente: crearPacienteProba(nome: ' Ana '),
      numero: 2,
      obterPacientes: () async => [],
      actualizacions: const Stream.empty(),
    );

    expect(vm.nomeVisible, 'Ana');
    expect(vm.valoresInr, [2.2, 2.5]);
    expect(vm.valoresDose, [6.5, 7]);
    expect(PacienteSupervisadoViewModel.numeroDesde(null), isNull);
    expect(PacienteSupervisadoViewModel.numeroDesde('sen dato'), isNull);
    expect(
      PacienteSupervisadoViewModel.conDependencias(
        paciente: crearPacienteProba(nome: ' '),
        numero: 2,
        obterPacientes: () async => [],
        actualizacions: const Stream.empty(),
      ).nomeVisible,
      'Persoa 2',
    );
  });

  test('actualiza só ante o evento do paciente correcto', () async {
    final eventos = StreamController<String>();
    var nome = 'Inicial';
    var cargas = 0;
    final vm = PacienteSupervisadoViewModel.conDependencias(
      paciente: crearPacienteProba(nome: nome),
      numero: 1,
      obterPacientes: () async {
        cargas++;
        return [crearPacienteProba(nome: nome)];
      },
      actualizacions: eventos.stream,
    );
    vm.iniciar();

    eventos.add('supervisor:outro');
    await Future<void>.delayed(Duration.zero);
    expect(cargas, 0);

    nome = 'Actualizada';
    eventos.add('supervisor:paciente-1');
    await Future<void>.delayed(Duration.zero);
    expect(cargas, 1);
    expect(vm.nomeVisible, 'Actualizada');

    vm.dispose();
    await eventos.close();
  });

  test('mantén o paciente se non aparece e expón erros', () async {
    final vmSenResultado = PacienteSupervisadoViewModel.conDependencias(
      paciente: crearPacienteProba(nome: 'Inicial'),
      numero: 1,
      obterPacientes: () async => [crearPacienteProba(uid: 'outro')],
      actualizacions: const Stream.empty(),
    );
    await vmSenResultado.recargar();
    expect(vmSenResultado.nomeVisible, 'Inicial');

    final vmErro = PacienteSupervisadoViewModel.conDependencias(
      paciente: crearPacienteProba(),
      numero: 1,
      obterPacientes: () async => throw Exception('sqlite'),
      actualizacions: const Stream.empty(),
    );
    await vmErro.recargar();
    expect(vmErro.erro, 'Non se puideron actualizar os datos do paciente');
  });
}
