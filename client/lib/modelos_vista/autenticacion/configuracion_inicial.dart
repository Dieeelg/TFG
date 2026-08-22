import 'package:firebase_auth/firebase_auth.dart'; // Estado da configuración inicial.
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AuthResult { exito, erro }

class SetupViewModel extends ChangeNotifier {
  final Future<void> Function() _iniciarSesion;
  final Future<void> Function(String rol) _gardarRol;

  SetupViewModel({
    FirebaseAuth? autenticacion,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : this.conDependencias(
         iniciarSesion: () async {
           await (autenticacion ?? FirebaseAuth.instance).signInAnonymously();
         },
         gardarRol: (rol) => storage.write(key: 'rol_usuario', value: rol),
       );

  SetupViewModel.conDependencias({
    required Future<void> Function() iniciarSesion,
    required Future<void> Function(String rol) gardarRol,
  }) : _iniciarSesion = iniciarSesion,
       _gardarRol = gardarRol;

  bool _estaCargando = false;
  bool get estaCargando => _estaCargando;

  Future<AuthResult> autenticar({required bool esPaciente}) async {
    if (_estaCargando) return AuthResult.erro;

    _setEstado(true);
    try {
      await _iniciarSesion();
      await _gardarRol(esPaciente ? 'PACIENTE' : 'COIDADOR');
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
