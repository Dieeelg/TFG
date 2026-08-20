import 'package:firebase_auth/firebase_auth.dart'; // Estado da configuración inicial.
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AuthResult { exito, erro }

class SetupViewModel extends ChangeNotifier {
  bool _estaCargando = false;
  bool get estaCargando => _estaCargando;

  Future<AuthResult> autenticar({required bool esPaciente}) async {
    if (_estaCargando) return AuthResult.erro;

    _setEstado(true);
    try {
      await FirebaseAuth.instance
          .signInAnonymously(); //Obtemos o UID do usuario
      await const FlutterSecureStorage().write(
        key: 'rol_usuario',
        value: esPaciente ? 'PACIENTE' : 'COIDADOR',
      );
      _setEstado(false);
      return AuthResult.exito;
    } catch (e) {
      _setEstado(false);
      debugPrint("Erro en SetupViewModel: $e");
      return AuthResult.erro;
    }
  }

  void _setEstado(bool valor) {
    _estaCargando = valor;
    notifyListeners();
  }
}
