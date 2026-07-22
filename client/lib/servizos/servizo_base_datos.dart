
import 'package:sqflite/sqflite.dart'; // Persistencia local.
import 'package:path/path.dart';
import 'dart:convert';
import '../modelos/dose_dia.dart';
import '../modelos/analise.dart';
import '../modelos/cabeceira.dart';
import '../modelos/historico.dart';

class DatabaseService {

  // PATRÓN SINGLETON: Evita que se abran múltiples conexións á base de datos á vez. Sempre devolve a mesma instancia.
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  DatabaseService._internal();
  factory DatabaseService() => _instance;

  // Si la DB ya está abierta, la devuelve. Si no, la inicializa.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'sintrom.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pautas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            data TEXT,
            dia INTEGER,
            dose TEXT,
            accion TEXT,
            eControl INTEGER,
            diaSemanaTexto TEXT
            ,estado TEXT NOT NULL DEFAULT 'PENDENTE',
            horaConfirmacion TEXT,
            desviacionMinutos INTEGER
          )
        ''');
        await _crearTaboaAnalise(db);
      },
    );
  }

  static Future<void> _crearTaboaAnalise(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS analise_actual (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        dataInforme TEXT,
        proximaVisita TEXT,
        centro TEXT,
        farmaco TEXT,
        doseSemanal TEXT
        ,documentoId TEXT
        ,inr TEXT
      )
    ''');
    await _crearTaboaHistorico(db);
    await _crearTaboaPacientesCoidador(db);
  }

  static Future<void> _crearTaboaPacientesCoidador(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pacientes_coidador (
        uid TEXT PRIMARY KEY,
        token TEXT NOT NULL,
        nome TEXT,
        payload TEXT,
        actualizadoEn TEXT
      )
    ''');
  }

  Future<void> gardarPacienteCoidador({
    required String uid,
    required String token,
    String? nome,
    Map<String, dynamic>? payload,
  }) async {
    final db = await database;
    final anterior = await db.query('pacientes_coidador', where: 'uid = ?', whereArgs: [uid], limit: 1);
    await db.insert('pacientes_coidador', {
      'uid': uid,
      'token': token,
      'nome': nome ?? (anterior.isEmpty ? null : anterior.first['nome']),
      'payload': payload == null
          ? (anterior.isEmpty ? null : anterior.first['payload'])
          : jsonEncode(payload),
      'actualizadoEn': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> obterPacientesCoidador() async {
    final db = await database;
    final rows = await db.query('pacientes_coidador', orderBy: 'actualizadoEn DESC');
    return rows.map((row) {
      final resultado = Map<String, dynamic>.from(row);
      final payload = row['payload'] as String?;
      resultado['datos'] = payload == null ? <String, dynamic>{} : jsonDecode(payload);
      return resultado;
    }).toList();
  }

  Future<void> eliminarPacienteCoidador(String uid) async {
    final db = await database;
    await db.delete('pacientes_coidador', where: 'uid = ?', whereArgs: [uid]);
  }

  static Future<void> _crearTaboaHistorico(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS historico_visitas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT,
        inr TEXT,
        farmaco TEXT,
        dose TEXT,
        apttInyectable TEXT,
        doseInyectable TEXT,
        proximaVisita TEXT,
        comentarios TEXT
      )
    ''');
  }

  String _identificadorDocumento(AnaliseModel analise) {
    String limpar(String? valor) => (valor ?? '').trim().toUpperCase();
    final calendario = [...analise.calendario]..sort((a, b) => a.data.compareTo(b.data));
    return [
      limpar(analise.cabeceira.dataInforme),
      limpar(analise.cabeceira.proximaVisita),
      limpar(analise.cabeceira.centro),
      limpar(analise.cabeceira.farmaco),
      ...calendario.map((dia) => '${dia.data}|${limpar(dia.dose)}|${limpar(dia.accion)}'),
    ].join('::');
  }

  Future<void> gardarAnalise(AnaliseModel analise) async {
    final db = await database;
    await db.transaction((txn) async {
      final documentoId = _identificadorDocumento(analise);
      final actual = await txn.query(
        'analise_actual',
        columns: ['documentoId'],
        where: 'id = 1',
        limit: 1,
      );
      final eMesmaFolla = actual.isNotEmpty && actual.first['documentoId'] == documentoId;
      final rexistrosAnteriores = <String, Map<String, Object?>>{};
      if (eMesmaFolla) {
        final filas = await txn.query('pautas', columns: ['data', 'estado', 'horaConfirmacion', 'desviacionMinutos']);
        for (final fila in filas) {
          rexistrosAnteriores[fila['data'] as String] = fila;
        }
      }

      await txn.delete('pautas');
      for (final dia in analise.calendario) {
        await txn.insert('pautas', {
          'data': dia.data,
          'dia': dia.dia,
          'dose': dia.dose,
          'accion': dia.accion,
          'eControl': dia.eControl ? 1 : 0,
          'diaSemanaTexto': dia.diaSemanaTexto,
          'estado': rexistrosAnteriores[dia.data]?['estado'] ?? 'PENDENTE',
          'horaConfirmacion': rexistrosAnteriores[dia.data]?['horaConfirmacion'],
          'desviacionMinutos': rexistrosAnteriores[dia.data]?['desviacionMinutos'],
        });
      }

      // A folla nova xa contén o resumo clínico actualizado, polo que o substitúmos.
      await txn.delete('historico_visitas');
      for (final visita in analise.historico) {
        await txn.insert('historico_visitas', {
          'data': visita.data,
          'inr': visita.inr,
          'farmaco': visita.farmaco,
          'dose': visita.dose,
          'apttInyectable': visita.apttInyectable,
          'doseInyectable': visita.doseInyectable,
          'proximaVisita': visita.proximaVisita,
          'comentarios': visita.comentarios,
        });
      }
      await txn.insert(
        'analise_actual',
        {
          'id': 1,
          'dataInforme': analise.cabeceira.dataInforme,
          'proximaVisita': analise.cabeceira.proximaVisita,
          'centro': analise.cabeceira.centro,
          'farmaco': analise.cabeceira.farmaco,
          'doseSemanal': analise.cabeceira.doseSemanal,
          'documentoId': documentoId,
          'inr': analise.cabeceira.inr,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> gardarPauta(List<DoseDiaModel> calendario) async {
    final db = await database;
    await db.delete('pautas');
    for (var dia in calendario) {
      await db.insert('pautas', {
        'data': dia.data,
        'dia': dia.dia,
        'dose': dia.dose,
        'accion': dia.accion,
        'eControl': dia.eControl ? 1 : 0,
        'diaSemanaTexto': dia.diaSemanaTexto,
      });
    }
  }

  Future<List<DoseDiaModel>> obterPauta() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('pautas');
    return List.generate(maps.length, (i) {
      return DoseDiaModel(
        data: maps[i]['data'],
        dia: maps[i]['dia'],
        dose: maps[i]['dose'],
        accion: maps[i]['accion'],
        eControl: maps[i]['eControl'] == 1,
        diaSemanaTexto: maps[i]['diaSemanaTexto'],
      );
    });
  }

  Future<CabeceiraModel?> obterCabeceira() async {
    final db = await database;
    final rows = await db.query('analise_actual', limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return CabeceiraModel(
      dataInforme: row['dataInforme'] as String?,
      proximaVisita: row['proximaVisita'] as String?,
      centro: row['centro'] as String?,
      farmaco: row['farmaco'] as String?,
      doseSemanal: row['doseSemanal'] as String?,
      inr: row['inr'] as String?,
    );
  }

  Future<List<ItemHistoricoModel>> obterHistorico() async {
    final db = await database;
    final rows = await db.query('historico_visitas', orderBy: 'data ASC');
    return rows.map((row) => ItemHistoricoModel(
      data: row['data'] as String?,
      inr: row['inr'] as String?,
      farmaco: row['farmaco'] as String?,
      dose: row['dose'] as String?,
      apttInyectable: row['apttInyectable'] as String?,
      doseInyectable: row['doseInyectable'] as String?,
      proximaVisita: row['proximaVisita'] as String?,
      comentarios: row['comentarios'] as String?,
    )).toList();
  }

  Future<Map<String, String>> obterEstados() async {
    final db = await database;
    final rows = await db.query('pautas', columns: ['data', 'estado']);
    return {for (final row in rows) row['data'] as String: row['estado'] as String};
  }

  Future<void> actualizarEstado(String data, String estado) async {
    final db = await database;
    await db.update('pautas', {'estado': estado}, where: 'data = ?', whereArgs: [data]);
  }

  Future<void> rexistrarToma({
    required String data,
    required DateTime instante,
    required int desviacionMinutos,
    required bool foraDeHora,
  }) async {
    final db = await database;
    await db.update('pautas', {
      'estado': foraDeHora ? 'TOMADA_FORA_HORA' : 'TOMADA',
      'horaConfirmacion': instante.toIso8601String(),
      'desviacionMinutos': desviacionMinutos,
    }, where: 'data = ?', whereArgs: [data]);
  }

  Future<void> pecharTomasVencidas() async {
    final db = await database;
    final hoxe = DateTime.now().toIso8601String().substring(0, 10);
    await db.update(
      'pautas',
      {'estado': 'NON_TOMADA'},
      where: "data < ? AND estado = 'PENDENTE' AND eControl = 0 AND dose != '0'",
      whereArgs: [hoxe],
    );
  }

  Future<List<Map<String, Object?>>> obterRexistrosCumprimento() async {
    final db = await database;
    return db.query(
      'pautas',
      columns: ['data', 'estado', 'horaConfirmacion', 'desviacionMinutos'],
      where: "estado IN ('TOMADA', 'TOMADA_FORA_HORA', 'NON_TOMADA')",
      orderBy: 'data ASC',
    );
  }
}
