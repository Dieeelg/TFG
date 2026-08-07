import 'package:flutter/material.dart'; // Estado da vinculación do coidador.
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../servizos/servizo_api.dart';
import '../../servizos/servizo_base_datos.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../../servizos/servizo_cifrado_p2p.dart';

class VinculacionCoidadorViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  final _cifrado = ServizoCifradoP2P();

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
      final datosQr = _cifrado.lerCodigoVinculacion(codigoQR);
      final vinculacionProvisional = datosQr.comoPacienteRemoto();
      final vinculacion = vinculacionProvisional.copyWith(
        claveBase64: await _cifrado.xerarClaveBase64(),
      );

      //Ocoidador pídelle a Firebase cal é o seu token.
      String? oMeuToken = await FirebaseMessaging.instance.getToken();
      if (oMeuToken == null || oMeuToken.isEmpty) {
        _erro = "Non se puido identificar este dispositivo.";
        return false;
      }

      const tipoAviso = 'VINCULACION_INICIAL';
      final payloadCifrado = await _cifrado.cifrarPayload(
        vinculacion: vinculacionProvisional,
        tipoAviso: tipoAviso,
        payload: jsonEncode({
          'token': oMeuToken,
          'coidadorUid': FirebaseAuth.instance.currentUser?.uid,
          'clavePermanente': vinculacion.claveBase64,
        }),
      );

      //Unha vez btido enviaselle unha notificación ao paciente
      final exitoSaudo = await _apiService.enviarNotificacion(
        tokenDestino: datosQr.tokenPaciente,
        payload: payloadCifrado,
        tipoAviso: tipoAviso,
      );

      if (!exitoSaudo) {
        _erro = "Non se puido completar a vinculación co paciente.";
      }

      if (exitoSaudo) {
        await _cifrado.gardarVinculacion(vinculacion);
        await DatabaseService().gardarPacienteCoidador(
          uid: datosQr.uidPaciente,
          token: datosQr.tokenPaciente,
        );
        await _storage.write(key: 'configuracion_finalizada', value: 'true');
        await _storage.write(key: 'rol_usuario', value: 'COIDADOR');
      }

      return exitoSaudo;
    } on MensaxeP2PNonValida catch (e) {
      _erro = e.motivo;
      return false;
    } catch (e) {
      _erro = "Erro inesperado: $e";
      return false;
    } finally {
      _escaneando = false;
      notifyListeners();
    }
  }
}
