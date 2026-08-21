import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../modelos/analise.dart';
import '../servizos/servizo_api.dart';
import '../servizos/servizo_base_datos.dart';
import '../servizos/servizo_notificacions_locais.dart';
import '../servizos/servizo_sincronizacion_p2p.dart';

class ReportCaptureViewModel extends ChangeNotifier {
  final Future<AnaliseModel> Function(File ficheiro) _enviarInforme;
  final Future<void> Function(AnaliseModel analise) _gardarAnalise;
  final Future<String?> Function(String key) _ler;
  final Future<void> Function({required String nome, required String hora})
  _programarTomas;
  final Future<void> Function(String tipo) _notificarCoidador;
  final Future<void> Function(AnaliseModel analise, String token)
  _enviarInformeRemoto;

  ReportCaptureViewModel({
    ApiService? api,
    DatabaseService? database,
    LocalNotificationService? notificacions,
    P2PSyncService? sincronizacion,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : this.conDependencias(
         enviarInforme: (api ?? ApiService()).enviarInforme,
         gardarAnalise: (database ?? DatabaseService()).gardarAnalise,
         ler: (key) => storage.read(key: key),
         programarTomas: (notificacions ?? LocalNotificationService())
             .programarTomasPaciente,
         notificarCoidador:
             (sincronizacion ?? P2PSyncService()).notificarCoidador,
         enviarInformeRemoto:
             (sincronizacion ?? P2PSyncService()).enviarInformeRemoto,
       );

  ReportCaptureViewModel.conDependencias({
    required Future<AnaliseModel> Function(File ficheiro) enviarInforme,
    required Future<void> Function(AnaliseModel analise) gardarAnalise,
    required Future<String?> Function(String key) ler,
    required Future<void> Function({required String nome, required String hora})
    programarTomas,
    required Future<void> Function(String tipo) notificarCoidador,
    required Future<void> Function(AnaliseModel analise, String token)
    enviarInformeRemoto,
  }) : _enviarInforme = enviarInforme,
       _gardarAnalise = gardarAnalise,
       _ler = ler,
       _programarTomas = programarTomas,
       _notificarCoidador = notificarCoidador,
       _enviarInformeRemoto = enviarInformeRemoto;

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
      return await _enviarInforme(ficheiro);
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
        await _gardarAnalise(analise);
        final hora = await _ler('hora_toma');
        if (hora != null) {
          await _programarTomas(
            nome: await _ler('nome_usuario') ?? '',
            hora: hora,
          );
        }
        await _notificarCoidador('NOVO_INFORME');
      } else {
        await _enviarInformeRemoto(analise, tokenPacienteDestino);
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
