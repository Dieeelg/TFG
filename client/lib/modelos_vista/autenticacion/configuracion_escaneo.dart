import 'package:flutter/material.dart'; // Estado da selección de escaneo.
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
          key: 'quen_escanea',
          value: euMesmo ? 'PACIENTE' : 'COIDADOR'
      );

      if (euMesmo) {
        // Aínda falta indicar o nome e a hora da toma.
        await _storage.delete(key: 'configuracion_finalizada');
      } else {
        // Se escanea outra persoa, non precisamos configurar a hora neste dispositivo.
        await _storage.write(key: 'configuracion_finalizada', value: 'true');
      }

    } catch (e) {
      debugPrint("Erro ao gardar preferencia de escaneo: $e");
    } finally {
      _estaCargando = false;
      notifyListeners();
    }
  }
}
