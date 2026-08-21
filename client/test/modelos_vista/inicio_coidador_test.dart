import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_sintrom/modelos_vista/inicio_coidador.dart';

import '../axuda/datos_proba.dart';

void main() {
  test('iniciar carga, sincroniza e reacciona ao stream', () async {
    final eventos = StreamController<String>();
    var cargas = 0;
    var sincronizacions = 0;
    final vm = CaregiverHomeViewModel.conDependencias(
      obterPacientes: () async {
        cargas++;
        return [crearPacienteProba(nome: 'Ana $cargas')];
      },
      solicitarSincronizacion: () async => sincronizacions++,
      actualizacions: eventos.stream,
      agardar: (_) async {},
    );

    vm.iniciar();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(sincronizacions, 1);
    expect(vm.actualizando, isFalse);
    expect(vm.pacientes, isNotEmpty);

    eventos.add('ignorar');
    await Future<void>.delayed(Duration.zero);
    final antes = cargas;
    eventos.add('coidador:paciente-1');
    await Future<void>.delayed(Duration.zero);
    expect(cargas, antes + 1);

    vm.dispose();
    await eventos.close();
  });

  test('evita sincronizacións solapadas', () async {
    final espera = Completer<void>();
    var chamadas = 0;
    final vm = CaregiverHomeViewModel.conDependencias(
      obterPacientes: () async => [],
      solicitarSincronizacion: () {
        chamadas++;
        return espera.future;
      },
      actualizacions: const Stream.empty(),
      agardar: (_) async {},
    );

    final primeira = vm.sincronizar();
    await vm.sincronizar();
    expect(chamadas, 1);
    espera.complete();
    await primeira;
  });

  test('expón por separado erros de carga e sincronización', () async {
    final vmCarga = CaregiverHomeViewModel.conDependencias(
      obterPacientes: () async => throw Exception('sqlite'),
      solicitarSincronizacion: () async {},
      actualizacions: const Stream.empty(),
      agardar: (_) async {},
    );
    await vmCarga.cargar();
    expect(vmCarga.erro, 'Non se puideron cargar os pacientes');

    final vmSync = CaregiverHomeViewModel.conDependencias(
      obterPacientes: () async => [],
      solicitarSincronizacion: () async => throw Exception('rede'),
      actualizacions: const Stream.empty(),
      agardar: (_) async {},
    );
    await vmSync.sincronizar();
    expect(vmSync.erro, 'Non se puideron actualizar os pacientes');
    expect(vmSync.actualizando, isFalse);
  });
}
