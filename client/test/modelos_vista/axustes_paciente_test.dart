import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_sintrom/modelos_vista/axustes_paciente.dart';

void main() {
  const supervisor = VinculacionP2P(
    id: 'v1',
    uidRemoto: 'supervisor-1',
    tokenRemoto: 'token',
    claveBase64: 'clave',
    rolRemoto: 'SUPERVISOR',
  );

  late Map<String, String> storage;
  late List<VinculacionP2P> supervisores;
  late List<String> eventos;

  AxustesPacienteViewModel crearVm({
    Future<List<VinculacionP2P>> Function()? obterSupervisores,
    Future<String?> Function()? obterUid,
    Future<String?> Function()? obterToken,
    Future<String> Function({
      required String uidPaciente,
      required String tokenPaciente,
    })?
    xerarQr,
  }) => AxustesPacienteViewModel.conDependencias(
    ler: (key) async => storage[key],
    escribir: (key, value) async => storage[key] = value,
    eliminar: (key) async => storage.remove(key),
    obterSupervisores: obterSupervisores ?? () async => supervisores,
    programarTomas: ({required nome, required hora}) async {
      eventos.add('programar:$nome:$hora');
    },
    notificarSupervisores: (tipo) async => eventos.add('notificar:$tipo'),
    desvincularSupervisor: (vinculacion) async {
      eventos.add('desvincular:${vinculacion.id}');
      supervisores.removeWhere((v) => v.id == vinculacion.id);
    },
    obterUid: obterUid ?? () async => 'paciente-1',
    obterToken: obterToken ?? () async => 'token-paciente',
    xerarCodigoVinculacion:
        xerarQr ??
        ({required uidPaciente, required tokenPaciente}) async =>
            '$uidPaciente:$tokenPaciente',
  );

  setUp(() {
    storage = {
      'nome_usuario': 'Ana',
      'hora_toma': '19:45',
      'modo_sinxelo': 'true',
    };
    supervisores = [supervisor];
    eventos = [];
  });

  test('carga preferencias e supervisores', () async {
    final vm = crearVm();
    await vm.cargar();

    expect(vm.cargado, isTrue);
    expect(vm.cargando, isFalse);
    expect(vm.nome, 'Ana');
    expect(vm.hora, '19:45');
    expect(vm.modoSinxelo, isTrue);
    expect(vm.supervisores, [supervisor]);
  });

  test('usa valores por defecto e informa dun erro de carga', () async {
    storage.clear();
    final vm = crearVm();
    await vm.cargar();
    expect(vm.nome, isEmpty);
    expect(vm.hora, '20:00');
    expect(vm.modoSinxelo, isFalse);

    final vmErro = crearVm(
      obterSupervisores: () async => throw Exception('storage'),
    );
    await vmErro.cargar();
    expect(vmErro.erro, 'Non se puideron cargar os axustes');
  });

  test('garda nome, hora e modo e sincroniza o cambio', () async {
    final vm = crearVm();
    vm.cambiarModoSinxelo(false);

    expect(await vm.gardar(nome: '  Berta ', hora: '21:00'), isTrue);
    expect(storage['nome_usuario'], 'Berta');
    expect(storage['hora_toma'], '21:00');
    expect(storage['modo_sinxelo'], 'false');
    expect(eventos, ['programar:Berta:21:00', 'notificar:ESTADO_COMPLETO']);
    expect(vm.nome, 'Berta');
    expect(vm.hora, '21:00');
  });

  test('elimina un nome baleiro e expón erros de gardado', () async {
    final vm = crearVm();
    expect(await vm.gardar(nome: ' ', hora: '20:00'), isTrue);
    expect(storage.containsKey('nome_usuario'), isFalse);

    final vmErro = AxustesPacienteViewModel.conDependencias(
      ler: (_) async => null,
      escribir: (_, _) async => throw Exception('disco'),
      eliminar: (_) async {},
      obterSupervisores: () async => [],
      programarTomas: ({required nome, required hora}) async {},
      notificarSupervisores: (_) async {},
      desvincularSupervisor: (_) async {},
      obterUid: () async => null,
      obterToken: () async => null,
      xerarCodigoVinculacion:
          ({required uidPaciente, required tokenPaciente}) async => '',
    );
    expect(await vmErro.gardar(nome: 'Ana', hora: '20:00'), isFalse);
    expect(vmErro.erro, 'Non se puideron gardar os cambios');
    expect(vmErro.gardando, isFalse);
  });

  test('desvincula e recarga os supervisores', () async {
    final vm = crearVm();
    await vm.cargar();

    expect(await vm.desvincular(supervisor), isTrue);
    expect(eventos, ['desvincular:v1']);
    expect(vm.supervisores, isEmpty);
    expect(vm.desvinculandoId, isNull);
  });

  test('propaga o erro de desvinculación', () async {
    final vm = AxustesPacienteViewModel.conDependencias(
      ler: (_) async => null,
      escribir: (_, _) async {},
      eliminar: (_) async {},
      obterSupervisores: () async => [supervisor],
      programarTomas: ({required nome, required hora}) async {},
      notificarSupervisores: (_) async {},
      desvincularSupervisor: (_) async => throw Exception('non autorizado'),
      obterUid: () async => null,
      obterToken: () async => null,
      xerarCodigoVinculacion:
          ({required uidPaciente, required tokenPaciente}) async => '',
    );

    expect(await vm.desvincular(supervisor), isFalse);
    expect(vm.erro, 'non autorizado');
    expect(vm.desvinculandoId, isNull);
  });

  test('xera o QR ou informa de credenciais e cifrado erróneos', () async {
    final vm = crearVm();
    expect(await vm.xerarCodigoQr(), 'paciente-1:token-paciente');

    final senUid = crearVm(obterUid: () async => null);
    expect(await senUid.xerarCodigoQr(), isNull);
    expect(senUid.erro, 'Non se puido xerar o código QR');

    final erroCifrado = crearVm(
      xerarQr: ({required uidPaciente, required tokenPaciente}) async {
        throw Exception('cifrado');
      },
    );
    expect(await erroCifrado.xerarCodigoQr(), isNull);
    expect(erroCifrado.erro, 'Non se puido xerar o código QR');
  });
}
