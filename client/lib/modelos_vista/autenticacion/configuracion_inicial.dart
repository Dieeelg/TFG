import 'package:firebase_auth/firebase_auth.dart'; // Estado da configuración inicial.
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum ResultadoAutenticacion { exito, erro }

class ConfiguracionInicialViewModel extends ChangeNotifier {
  final Future<void> Function() _iniciarSesion;
  final Future<void> Function(String rol) _gardarRol;

  ConfiguracionInicialViewModel({
    FirebaseAuth? autenticacion,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : this.conDependencias(
         iniciarSesion: () async {
           await (autenticacion ?? FirebaseAuth.instance).signInAnonymously();
         },
         gardarRol: (rol) => storage.write(key: 'rol_usuario', value: rol),
       );

  ConfiguracionInicialViewModel.conDependencias({
    required Future<void> Function() iniciarSesion,
    required Future<void> Function(String rol) gardarRol,
  }) : _iniciarSesion = iniciarSesion,
       _gardarRol = gardarRol;

  bool _estaCargando = false;
  bool get estaCargando => _estaCargando;

  Future<ResultadoAutenticacion> autenticar({required bool esPaciente}) async {
    if (_estaCargando) return ResultadoAutenticacion.erro;

    _setEstado(true);
    try {
      await _iniciarSesion();
      await _gardarRol(esPaciente ? 'PACIENTE' : 'SUPERVISOR');
      _setEstado(false);
      return ResultadoAutenticacion.exito;
    } catch (e) {
      _setEstado(false);
      debugPrint("Erro en ConfiguracionInicialViewModel: $e");
      return ResultadoAutenticacion.erro;
    }
  }

  void _setEstado(bool valor) {
    _estaCargando = valor;
    notifyListeners();
  }
}
