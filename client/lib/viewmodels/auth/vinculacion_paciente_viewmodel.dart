import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';

class VinculacionPacienteViewModel extends ChangeNotifier {
  String? _datosQR;
  bool _cargando = false;

  Timer? _timer;

  final _storage = const FlutterSecureStorage();
  bool _tenCoidador = false;

  bool get tenCoidador => _tenCoidador;

  String? get datosQR => _datosQR;
  bool get cargando => _cargando;

  Future<void> xerarDatosVinculacion() async {
    _cargando = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      final String uid = user?.uid ?? "sen_id";

      String? token = await FirebaseMessaging.instance.getToken();

      _datosQR = "$uid|${token ?? 'sen_token'}";

      _iniciarChequeoAutomatico();

    } catch (e) {
      _datosQR = "erro_datos";
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  void _iniciarChequeoAutomatico() {
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
    _timer?.cancel(); // Importante: limpar o timer ao saír da pantalla
    super.dispose();
  }

  Future<void> configurarEscaneoAutomaticoPaciente() async {
    // Se salta a vinculación, asumimos que o paciente escanea el mesmo
    await _storage.write(key: 'quene_escanea', value: 'PACIENTE');
    notifyListeners();
  }
}