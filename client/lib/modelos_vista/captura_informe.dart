import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../modelos/analise.dart';
import '../servizos/servizo_api.dart';
import '../servizos/servizo_base_datos.dart';
import '../servizos/servizo_notificacions_locais.dart';
import '../servizos/servizo_sincronizacion_p2p.dart';

class ReportCaptureViewModel extends ChangeNotifier {
  final ApiService _api;
  final DatabaseService _database;
  final LocalNotificationService _notificacions;
  final P2PSyncService _sincronizacion;
  final FlutterSecureStorage _storage;

  ReportCaptureViewModel({
    ApiService? api,
    DatabaseService? database,
    LocalNotificationService? notificacions,
    P2PSyncService? sincronizacion,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _api = api ?? ApiService(),
       _database = database ?? DatabaseService(),
       _notificacions = notificacions ?? LocalNotificationService(),
       _sincronizacion = sincronizacion ?? P2PSyncService(),
       _storage = storage;

  bool _procesando = false;
  String? _nomeFicheiro;
  String? _erro;

  bool get procesando => _procesando;
  String? get nomeFicheiro => _nomeFicheiro;
  String? get erro => _erro;

  Future<AnaliseModel?> extraer(File ficheiro, String nome) async {
    _procesando = true;
    _nomeFicheiro = nome;
    _erro = null;
    notifyListeners();
    try {
      return await _api.enviarInforme(ficheiro);
    } catch (e) {
      _erro = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      _procesando = false;
      notifyListeners();
    }
  }

  Future<bool> completar(
    AnaliseModel analise, {
    String? tokenPacienteDestino,
  }) async {
    _procesando = true;
    _erro = null;
    notifyListeners();
    try {
      if (tokenPacienteDestino == null) {
        await _database.gardarAnalise(analise);
        final hora = await _storage.read(key: 'hora_toma');
        if (hora != null) {
          await _notificacions.programarTomasPaciente(
            nome: await _storage.read(key: 'nome_usuario') ?? '',
            hora: hora,
          );
        }
        await _sincronizacion.notificarCoidador('NOVO_INFORME');
      } else {
        await _sincronizacion.enviarInformeRemoto(
          analise,
          tokenPacienteDestino,
        );
      }
      return true;
    } catch (e) {
      _erro = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _procesando = false;
      notifyListeners();
    }
  }
}
