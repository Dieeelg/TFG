import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_sintrom/modelos/cabeceira.dart';
import 'package:tfg_sintrom/modelos/dose_dia.dart';
import 'package:tfg_sintrom/modelos_vista/inicio.dart';

void main() {
  late Map<String, String> storage;
  late List<DoseDiaModel> pauta;
  late Map<String, String> estados;
  late List<String> eventos;
  late StreamController<String> actualizacions;
  final agora = DateTime(2026, 8, 21, 21, 15);

  DoseDiaModel dia(String data, {String? dose = '1/2', bool control = false}) =>
      DoseDiaModel(
        data: data,
        dia: DateTime.parse(data).day,
        dose: dose,
        accion: control ? 'CONTROL' : 'TOMAR',
        eControl: control,
        diaSemanaTexto: 'VENRES',
      );

  HomeViewModel crearVm({
    Future<List<String>> Function()? pechar,
    Future<List<DoseDiaModel>> Function()? obterPauta,
    Future<Map<String, String>> Function()? obterEstados,
    Future<CabeceiraModel?> Function()? obterCabeceira,
    Future<Map<String, dynamic>> Function(String)? buscarCentro,
  }) => HomeViewModel.conDependencias(
    ler: (key) async => storage[key],
    pecharTomasVencidas: pechar ?? () async => [],
    obterPauta: obterPauta ?? () async => pauta,
    obterEstados: obterEstados ?? () async => estados,
    obterCabeceira:
        obterCabeceira ?? () async => CabeceiraModel(farmaco: 'Sintrom'),
    rexistrarToma:
        ({
          required data,
          required instante,
          required desviacionMinutos,
          required foraDeHora,
        }) async {
          eventos.add(
            'rexistrar:$data:$desviacionMinutos:$foraDeHora:${instante.hour}',
          );
          estados[data] = foraDeHora ? 'TOMADA_FORA_HORA' : 'TOMADA';
        },
    notificarCoidador: (tipo) async => eventos.add('notificar:$tipo'),
    cancelarEsquecemento: ({required identificador}) async {
      eventos.add('cancelar:$identificador');
    },
    enviarPayload:
        ({required tokenDestino, required payload, required tipoAviso}) async {
          eventos.add('payload:$tokenDestino:$payload:$tipoAviso');
          return true;
        },
    buscarCentro: buscarCentro ?? (_) async => {'telefono': ' 981 123 456 '},
    actualizacions: actualizacions.stream,
    agora: () => agora,
  );

  setUp(() {
    storage = {
      'nome_usuario': '  Ana  ',
      'hora_toma': '20:00',
      'modo_sinxelo': 'true',
    };
    pauta = [
      dia('2026-08-20'),
      dia('2026-08-21'),
      dia('2026-08-22', dose: '0'),
      dia('2026-08-23', control: true, dose: null),
    ];
    estados = {'2026-08-20': 'PENDENTE', '2026-08-21': 'PENDENTE'};
    eventos = [];
    actualizacions = StreamController<String>.broadcast();
  });

  tearDown(() async {
    await actualizacions.close();
  });

  test('carga e normaliza preferencias', () async {
    final vm = crearVm();
    await vm.cargarPreferencias();

    expect(vm.preferenciasCargadas, isTrue);
    expect(vm.nomeUsuario, 'Ana');
    expect(vm.horaToma, '20:00');
    expect(vm.modoSinxelo, isTrue);

    storage.clear();
    await vm.cargarPreferencias();
    expect(vm.nomeUsuario, isNull);
    expect(vm.horaToma, '20:00');
    expect(vm.modoSinxelo, isFalse);
    vm.dispose();
  });

  test('constrúe a pauta visual e pecha tomas vencidas', () async {
    final vm = crearVm(pechar: () async => ['2026-08-20']);
    await vm.cargarDatosHome();

    expect(vm.cargando, isFalse);
    expect(vm.pautaSemanal, hasLength(4));
    expect(vm.pautaSemanal[0].estado, 'NON_TOMADA');
    expect(vm.pautaSemanal[2].dose, 'NON');
    expect(vm.pautaSemanal[3].dose, 'CTRL');
    expect(vm.tomaHoxe?.data, '2026-08-21');
    expect(vm.doseHoxe, '1/2');
    expect(eventos, ['notificar:TOMA_ESQUECIDA']);
    vm.dispose();
  });

  test('manexa pauta baleira e erro de lectura sen quedar cargando', () async {
    pauta = [];
    final vm = crearVm();
    await vm.cargarDatosHome();
    expect(vm.tomaHoxe, isNull);
    expect(vm.doseHoxe, '--');

    final vmErro = crearVm(obterPauta: () async => throw Exception('sqlite'));
    await vmErro.cargarDatosHome();
    expect(vmErro.cargando, isFalse);
    vm.dispose();
    vmErro.dispose();
  });

  test('rexistra unha toma fóra de hora e sincroniza', () async {
    final vm = crearVm();
    await vm.cargarDatosHome();
    await vm.confirmarTomaHoxe();

    expect(eventos, contains('rexistrar:2026-08-21:75:true:21'));
    expect(eventos, contains('notificar:TOMA_CONFIRMADA'));
    expect(eventos, contains('cancelar:paciente_local'));
    expect(vm.tomaHoxe?.estado, 'TOMADA_FORA_HORA');
    vm.dispose();
  });

  test('non confirma días sen dose ou de control', () async {
    pauta = [dia('2026-08-21', dose: '0')];
    final vmSenDose = crearVm();
    await vmSenDose.cargarDatosHome();
    await vmSenDose.confirmarTomaHoxe();
    expect(eventos, isEmpty);

    pauta = [dia('2026-08-21', control: true, dose: null)];
    final vmControl = crearVm();
    await vmControl.cargarDatosHome();
    await vmControl.confirmarTomaHoxe();
    expect(eventos, isEmpty);
    vmSenDose.dispose();
    vmControl.dispose();
  });

  test('envía confirmación directa e valida o teléfono do centro', () async {
    final vm = crearVm();
    await vm.confirmarToma('token', 'contido');
    expect(eventos, ['payload:token:contido:TOMA_CONFIRMADA']);
    expect(await vm.buscarTelefonoCentro('Centro'), '981 123 456');

    final senTelefono = crearVm(buscarCentro: (_) async => {'telefono': ' '});
    expect(
      () => senTelefono.buscarTelefonoCentro('Centro'),
      throwsA(isA<Exception>()),
    );
    vm.dispose();
    senTelefono.dispose();
  });

  test('iniciar é idempotente e responde á sincronización', () async {
    var cargas = 0;
    final vm = crearVm(
      obterPauta: () async {
        cargas++;
        return pauta;
      },
    );
    await vm.iniciar();
    final trasInicio = cargas;
    await vm.iniciar();
    expect(cargas, trasInicio);

    actualizacions.add('outro');
    await Future<void>.delayed(Duration.zero);
    expect(cargas, trasInicio);
    actualizacions.add('paciente_local');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(cargas, trasInicio + 1);
    vm.dispose();
  });
}
