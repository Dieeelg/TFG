import 'package:flutter/material.dart'; // Estado da vinculación do coidador.
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../servizos/servizo_api.dart';
import '../../servizos/servizo_base_datos.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

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
    // LECTURA DE QR: Separa o QR polo símbolo '|' e garda o UID e o TOKEN do paciente na nosa memoria segura.

    final partes = codigoQR.split('|');
    if (partes.length < 2) {
    _erro = "Código QR non válido.";
    return false;
    }

    final uidPaciente = partes[0];
    final tokenPaciente = partes[1];


    await DatabaseService().gardarPacienteCoidador(
      uid: uidPaciente,
      token: tokenPaciente,
    );

    //Ocoidador pídelle a Firebase cal é o seu token.
    String? oMeuToken = await FirebaseMessaging.instance.getToken();

    //Unha vez btido enviaselle unha notificación ao paciente
    final exitoSaudo = await _apiService.enviarNotificacion(
    tokenDestino: tokenPaciente,
    payload: jsonEncode({
      'token': oMeuToken ?? '',
      'coidadorUid': FirebaseAuth.instance.currentUser?.uid,
    }),
    tipoAviso: "VINCULACION_INICIAL",
    );

    if (!exitoSaudo) {
    _erro = "Non se puido completar a vinculación co paciente.";
    }

    if (exitoSaudo) {
      await _storage.write(key: 'configuracion_finalizada', value: 'true');
      await _storage.write(key: 'rol_usuario', value: 'COIDADOR');
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
