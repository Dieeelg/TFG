import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SetupEscanearViewModel extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  bool _estaCargando = false;

  bool get estaCargando => _estaCargando;

  /// Gardamos a preferencia de quen escanea
  /// [euMesmo] será true se o paciente quere facer el as fotos
  Future<void> seleccionarPreferencia(bool euMesmo) async {
    _estaCargando = true;
    notifyListeners();

    try {
      // Gardamos localmente: 'paciente' ou 'coidador'
      await _storage.write(
          key: 'quene_escanea',
          value: euMesmo ? 'PACIENTE' : 'COIDADOR'
      );

      // Aquí poderiamos facer unha chamada á túa API se queres que
      // o servidor tamén saiba esta preferencia.

    } catch (e) {
      debugPrint("Erro ao gardar preferencia de escaneo: $e");
    } finally {
      _estaCargando = false;
      notifyListeners();
    }
  }
}