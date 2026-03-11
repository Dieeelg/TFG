import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/api_service.dart';

class VinculacionCoidadorViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();

  bool _escaneando = false;
  bool get escaneando => _escaneando;

  String? _erro;
  String? get erro => _erro;

  Future<bool> vincularPaciente(String codigoQR) async {
    _escaneando = true;
    _erro = null;
    notifyListeners();

    try {
      final apiOk = await _apiService.checkHealth();
    if (!apiOk) {
    _erro = "A API non está dispoñible. Comproba a túa conexión.";
    return false;
    }

    final partes = codigoQR.split('|');
    if (partes.length < 2) {
    _erro = "Código QR non válido.";
    return false;
    }

    final uidPaciente = partes[0];
    final tokenPaciente = partes[1];


    await _storage.write(key: 'paciente_vinculado_uid', value: uidPaciente);
    await _storage.write(key: 'paciente_vinculado_token', value: tokenPaciente);


    String? oMeuToken = await FirebaseMessaging.instance.getToken();

    final exitoSaudo = await _apiService.enviarNotificacion(
    tokenDestino: tokenPaciente,
    payload: oMeuToken ?? "",
    tipoAviso: "VINCULACION_INICIAL",
    );

    if (!exitoSaudo) {
    _erro = "Non se puido completar a vinculación co paciente.";
    }

    return exitoSaudo;
    } catch (e) {
    _erro = "Erro inesperado: $e";
    return false;
    } finally {
    _escaneando = false;
    notifyListeners();
    }
  }
}