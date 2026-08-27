import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_sintrom/modelos/analise.dart';
import 'package:tfg_sintrom/modelos_vista/captura_informe.dart';

import '../axuda/datos_proba.dart';

void main() {
  late AnaliseModel analise;
  late Map<String, String> storage;
  late List<String> eventos;

  setUp(() {
    analise = crearAnaliseProba();
    storage = {'hora_toma': '20:30', 'nome_usuario': 'Ana'};
    eventos = [];
  });

  CapturaInformeViewModel crearVm({
    Future<AnaliseModel> Function(File)? enviar,
    Future<void> Function(AnaliseModel)? gardar,
  }) => CapturaInformeViewModel.conDependencias(
    enviarInforme: enviar ?? (_) async => analise,
    gardarAnalise: gardar ?? (_) async => eventos.add('gardar'),
    ler: (key) async => storage[key],
    programarTomas: ({required nome, required hora}) async {
      eventos.add('programar:$nome:$hora');
    },
    notificarSupervisores: (tipo) async => eventos.add('notificar:$tipo'),
    enviarInformeRemoto: (valor, token) async {
      eventos.add('remoto:$token');
    },
  );

  test('extrae o informe e conserva o nome do ficheiro', () async {
    final vm = crearVm();
    final resultado = await vm.extraer(File('informe.jpg'), 'informe.jpg');

    expect(resultado, same(analise));
    expect(vm.nomeFicheiro, 'informe.jpg');
    expect(vm.procesando, isFalse);
    expect(vm.erro, isNull);
  });

  test('transforma o erro de extracción nun estado presentable', () async {
    final vm = crearVm(
      enviar: (_) async => throw Exception('formato non admitido'),
    );

    expect(await vm.extraer(File('malo.txt'), 'malo.txt'), isNull);
    expect(vm.erro, 'formato non admitido');
  });

  test('completa o fluxo local: BD, recordatorios e supervisor', () async {
    final vm = crearVm();

    expect(await vm.completar(analise), isTrue);
    expect(eventos, [
      'gardar',
      'programar:Ana:20:30',
      'notificar:NOVO_INFORME',
    ]);
  });

  test('non programa recordatorios sen hora e permite envío remoto', () async {
    storage.clear();
    final vm = crearVm();
    expect(await vm.completar(analise), isTrue);
    expect(eventos, ['gardar', 'notificar:NOVO_INFORME']);

    eventos.clear();
    expect(
      await vm.completar(analise, tokenPacienteDestino: 'token-remoto'),
      isTrue,
    );
    expect(eventos, ['remoto:token-remoto']);
  });

  test('informa do erro de persistencia e recupera o estado', () async {
    final vm = crearVm(gardar: (_) async => throw Exception('disco cheo'));

    expect(await vm.completar(analise), isFalse);
    expect(vm.erro, 'disco cheo');
    expect(vm.procesando, isFalse);
  });
}
