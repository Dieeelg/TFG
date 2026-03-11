import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SetupViewModel extends ChangeNotifier {
  bool _estaCargando = false;
  bool get estaCargando => _estaCargando;

  Future<bool> iniciarSesionPaciente() async {
    _setEstado(true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
      _setEstado(false);
      return true;
    } catch (e) {
      _setEstado(false);
      debugPrint("Erro en SetupViewModel: $e");
      return false;
    }
  }

  void _setEstado(bool valor) {
    _estaCargando = valor;
    notifyListeners();
  }
}