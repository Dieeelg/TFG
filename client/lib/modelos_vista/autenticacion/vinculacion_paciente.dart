import 'package:flutter/material.dart'; // Estado da vinculación do paciente.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import '../../servizos/servizo_cifrado_p2p.dart';

class VinculacionPacienteViewModel extends ChangeNotifier {
  String? _datosQR; //A información que conterá o QR
  bool _cargando = false;
  Timer? _timer; //Para comprobar se xa se escaneou o QR ou non
  final _storage = const FlutterSecureStorage();
  final _cifrado = ServizoCifradoP2P();
  bool _tenCoidador = false;

  bool get tenCoidador => _tenCoidador;
  String? get datosQR => _datosQR;
  bool get cargando => _cargando;

  Future<void> xerarDatosVinculacion() async {
    _cargando = true;
    notifyListeners();

    try {
      final user =
          FirebaseAuth.instance.currentUser; //Pedimoslle a firebase o noso UID
      final String uid = user?.uid ?? "sen_id";

      String? token = await FirebaseMessaging.instance
          .getToken(); //Pedimos o token para enviar mensaxes

      if (token == null || token.isEmpty) {
        throw Exception('Non se puido obter o token de mensaxería');
      }
      _datosQR = await _cifrado.xerarCodigoVinculacion(
        uidPaciente: uid,
        tokenPaciente: token,
      );

      _iniciarChequeoAutomatico(); //Unha vez temos os datos do QR comezamos a comprobar se xa se escaneou ou non
    } catch (e) {
      _datosQR = "erro_datos";
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  void _iniciarChequeoAutomatico() {
    //Miramos cada dous segundos se xa esta no storage o UID do coidador
    _timer?.cancel(); // Cancelamos se houbera un previo
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await comprobarEstadoVinculacion();
      if (_tenCoidador) {
        timer.cancel(); // Se xa temos coidador, paramos o timer
      }
    });
  }

  Future<void> comprobarEstadoVinculacion() async {
    String? tokenCoidador = await _storage.read(key: 'token_coidador');
    if (tokenCoidador != null && !_tenCoidador) {
      _tenCoidador = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    //Para eliminar o timer unha vez se salga da pantalla de vinculación
    _timer?.cancel();
    super.dispose();
  }
}
