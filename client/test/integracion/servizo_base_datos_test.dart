import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tfg_sintrom/modelos/analise.dart';
import 'package:tfg_sintrom/modelos/cabeceira.dart';
import 'package:tfg_sintrom/modelos/dose_dia.dart';
import 'package:tfg_sintrom/servizos/servizo_base_datos.dart';

import '../axuda/datos_proba.dart';

void main() {
  late DatabaseService servizo;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final ruta = join(await getDatabasesPath(), 'sintrom.db');
    await databaseFactory.deleteDatabase(ruta);
    servizo = DatabaseService();
    await servizo.database;
  });

  setUp(() async {
    final db = await servizo.database;
    await db.delete('pautas');
    await db.delete('historico_visitas');
    await db.delete('analise_actual');
    await db.delete('pacientes_coidador');
  });

  test('persiste e reconstrúe unha análise completa', () async {
    final analise = crearAnaliseProba();
    await servizo.gardarAnalise(analise);

    final pauta = await servizo.obterPauta();
    final cabeceira = await servizo.obterCabeceira();
    final historico = await servizo.obterHistorico();

    expect(pauta, hasLength(1));
    expect(pauta.single.data, '2026-08-21');
    expect(pauta.single.dose, '1/2');
    expect(cabeceira?.farmaco, 'Sintrom 4 mg');
    expect(cabeceira?.inr, '2,5');
    expect(historico.single.data, '2026-08-01');
    expect(historico.single.dose, '6,5 mg');
  });

  test('conserva a toma ao reimportar exactamente a mesma folla', () async {
    final analise = crearAnaliseProba();
    await servizo.gardarAnalise(analise);
    await servizo.rexistrarToma(
      data: '2026-08-21',
      instante: DateTime(2026, 8, 21, 20, 10),
      desviacionMinutos: 10,
      foraDeHora: true,
    );

    await servizo.gardarAnalise(analise);
    final cumprimento = await servizo.obterRexistrosCumprimento();

    expect(cumprimento.single['estado'], 'TOMADA_FORA_HORA');
    expect(cumprimento.single['desviacionMinutos'], 10);
    expect(cumprimento.single['horaConfirmacion'], isNotNull);
  });

  test('unha folla distinta reinicia os estados da pauta', () async {
    final anterior = crearAnaliseProba();
    await servizo.gardarAnalise(anterior);
    await servizo.actualizarEstado('2026-08-21', 'TOMADA');

    final nova = AnaliseModel(
      cabeceira: CabeceiraModel(
        dataInforme: '2026-08-22',
        farmaco: anterior.cabeceira.farmaco,
        centro: anterior.cabeceira.centro,
        proximaVisita: anterior.cabeceira.proximaVisita,
      ),
      calendario: anterior.calendario,
      historico: const [],
    );
    await servizo.gardarAnalise(nova);

    expect((await servizo.obterEstados())['2026-08-21'], 'PENDENTE');
    expect(await servizo.obterHistorico(), isEmpty);
  });

  test('garda, actualiza e elimina pacientes do coidador', () async {
    await servizo.gardarPacienteCoidador(
      uid: 'p1',
      token: 'token-1',
      nome: 'Ana',
      payload: {'inrActual': '2,4'},
    );
    await servizo.gardarPacienteCoidador(
      uid: 'p1',
      token: 'token-2',
      payload: {'inrActual': '2,7'},
    );

    final pacientes = await servizo.obterPacientesCoidador();
    expect(pacientes, hasLength(1));
    expect(pacientes.single['nome'], 'Ana');
    expect(pacientes.single['token'], 'token-2');
    expect(pacientes.single['datos'], {'inrActual': '2,7'});

    await servizo.eliminarPacienteCoidador('p1');
    expect(await servizo.obterPacientesCoidador(), isEmpty);
  });

  test('pecha só tomas vencidas reais, non controis nin dose cero', () async {
    DoseDiaModel dia(String data, String? dose, {bool control = false}) =>
        DoseDiaModel(
          data: data,
          dia: DateTime.parse(data).day,
          dose: dose,
          accion: control ? 'CONTROL' : 'TOMAR',
          eControl: control,
          diaSemanaTexto: 'LUNS',
        );
    await servizo.gardarPauta([
      dia('2020-01-01', '1/2'),
      dia('2020-01-02', '0'),
      dia('2020-01-03', null, control: true),
      dia('2099-01-01', '1'),
    ]);

    final vencidas = await servizo.pecharTomasVencidas();
    final estados = await servizo.obterEstados();

    expect(vencidas, ['2020-01-01']);
    expect(estados['2020-01-01'], 'NON_TOMADA');
    expect(estados['2020-01-02'], 'PENDENTE');
    expect(estados['2020-01-03'], 'PENDENTE');
    expect(estados['2099-01-01'], 'PENDENTE');
    expect(await servizo.pecharTomasVencidas(), isEmpty);
  });

  test('obter cumprimento filtra estados aínda pendentes', () async {
    final analise = crearAnaliseProba();
    await servizo.gardarAnalise(analise);
    expect(await servizo.obterRexistrosCumprimento(), isEmpty);

    await servizo.actualizarEstado('2026-08-21', 'NON_TOMADA');
    final cumprimento = await servizo.obterRexistrosCumprimento();
    expect(cumprimento, hasLength(1));
    expect(cumprimento.single['data'], '2026-08-21');
  });

  test('cabeceira ausente devolve null', () async {
    expect(await servizo.obterCabeceira(), isNull);
  });
}
