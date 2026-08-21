import 'package:flutter/material.dart'; // Estado da vinculación do coidador.
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../servizos/servizo_api.dart';
import '../../servizos/servizo_base_datos.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../../servizos/servizo_cifrado_p2p.dart';

class VinculacionCoidadorViewModel extends ChangeNotifier {
  final Future<bool> Function() _comprobarApi;
  final DatosQrVinculacion Function(String codigo) _lerCodigo;
  final Future<String> Function() _xerarClave;
  final Future<String?> Function() _obterToken;
  final Future<String?> Function() _obterUid;
  final Future<String> Function({
    required VinculacionP2P vinculacion,
    required String tipoAviso,
    required String payload,
  })
  _cifrarPayload;
  final Future<bool> Function({
    required String tokenDestino,
    required String payload,
    required String tipoAviso,
  })
  _enviarNotificacion;
  final Future<void> Function(VinculacionP2P vinculacion) _gardarVinculacion;
  final Future<void> Function({required String uid, required String token})
  _gardarPaciente;
  final Future<void> Function(String key, String value) _escribir;

  VinculacionCoidadorViewModel({
    ApiService? api,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    ServizoCifradoP2P? cifrado,
    DatabaseService? database,
    FirebaseMessaging? mensaxeria,
    FirebaseAuth? autenticacion,
  }) : this.conDependencias(
         comprobarApi: (api ?? ApiService()).checkHealth,
         lerCodigo: (cifrado ?? ServizoCifradoP2P()).lerCodigoVinculacion,
         xerarClave: (cifrado ?? ServizoCifradoP2P()).xerarClaveBase64,
         obterToken: () =>
             (mensaxeria ?? FirebaseMessaging.instance).getToken(),
         obterUid: () async =>
             (autenticacion ?? FirebaseAuth.instance).currentUser?.uid,
         cifrarPayload: (cifrado ?? ServizoCifradoP2P()).cifrarPayload,
         enviarNotificacion: (api ?? ApiService()).enviarNotificacion,
         gardarVinculacion: (cifrado ?? ServizoCifradoP2P()).gardarVinculacion,
         gardarPaciente: ({required uid, required token}) =>
             (database ?? DatabaseService()).gardarPacienteCoidador(
               uid: uid,
               token: token,
             ),
         escribir: (key, value) => storage.write(key: key, value: value),
       );

  VinculacionCoidadorViewModel.conDependencias({
    required Future<bool> Function() comprobarApi,
    required DatosQrVinculacion Function(String codigo) lerCodigo,
    required Future<String> Function() xerarClave,
    required Future<String?> Function() obterToken,
    required Future<String?> Function() obterUid,
    required Future<String> Function({
      required VinculacionP2P vinculacion,
      required String tipoAviso,
      required String payload,
    })
    cifrarPayload,
    required Future<bool> Function({
      required String tokenDestino,
      required String payload,
      required String tipoAviso,
    })
    enviarNotificacion,
    required Future<void> Function(VinculacionP2P vinculacion)
    gardarVinculacion,
    required Future<void> Function({required String uid, required String token})
    gardarPaciente,
    required Future<void> Function(String key, String value) escribir,
  }) : _comprobarApi = comprobarApi,
       _lerCodigo = lerCodigo,
       _xerarClave = xerarClave,
       _obterToken = obterToken,
       _obterUid = obterUid,
       _cifrarPayload = cifrarPayload,
       _enviarNotificacion = enviarNotificacion,
       _gardarVinculacion = gardarVinculacion,
       _gardarPaciente = gardarPaciente,
       _escribir = escribir;

  bool _escaneando = false;
  bool get escaneando => _escaneando;

  String? _erro;
  String? get erro => _erro;

  Future<bool> vincularPaciente(String codigoQR) async {
    _escaneando = true;
    _erro = null;
    notifyListeners();

    try {
      final apiOk = await _comprobarApi();
      if (!apiOk) {
        _erro = "A API non está dispoñible. Comproba a túa conexión.";
        return false;
      }
      final datosQr = _lerCodigo(codigoQR);
      final vinculacionProvisional = datosQr.comoPacienteRemoto();
      final vinculacion = vinculacionProvisional.copyWith(
        claveBase64: await _xerarClave(),
      );

      //Ocoidador pídelle a Firebase cal é o seu token.
      String? oMeuToken = await _obterToken();
      if (oMeuToken == null || oMeuToken.isEmpty) {
        _erro = "Non se puido identificar este dispositivo.";
        return false;
      }

      const tipoAviso = 'VINCULACION_INICIAL';
      final payloadCifrado = await _cifrarPayload(
        vinculacion: vinculacionProvisional,
        tipoAviso: tipoAviso,
        payload: jsonEncode({
          'token': oMeuToken,
          'coidadorUid': await _obterUid(),
          'clavePermanente': vinculacion.claveBase64,
        }),
      );

      //Unha vez btido enviaselle unha notificación ao paciente
      final exitoSaudo = await _enviarNotificacion(
        tokenDestino: datosQr.tokenPaciente,
        payload: payloadCifrado,
        tipoAviso: tipoAviso,
      );

      if (!exitoSaudo) {
        _erro = "Non se puido completar a vinculación co paciente.";
      }

      if (exitoSaudo) {
        await _gardarVinculacion(vinculacion);
        await _gardarPaciente(
          uid: datosQr.uidPaciente,
          token: datosQr.tokenPaciente,
        );
        await _escribir('configuracion_finalizada', 'true');
        await _escribir('rol_usuario', 'COIDADOR');
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
