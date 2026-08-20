import 'package:flutter/foundation.dart';

import '../servizos/servizo_sincronizacion_p2p.dart';

class CaregiverPatientSettingsViewModel extends ChangeNotifier {
  final P2PSyncService _sincronizacion;

  CaregiverPatientSettingsViewModel({P2PSyncService? sincronizacion})
    : _sincronizacion = sincronizacion ?? P2PSyncService();

  bool _enviando = false;
  String? _erro;

  bool get enviando => _enviando;
  String? get erro => _erro;

  Future<bool> gardar({
    required String tokenPaciente,
    required String nome,
    required String hora,
  }) async {
    if (_enviando) return false;
    _enviando = true;
    _erro = null;
    notifyListeners();
    try {
      await _sincronizacion.enviarConfiguracionPaciente(
        tokenPaciente: tokenPaciente,
        nome: nome.trim(),
        horaToma: hora,
      );
      return true;
    } catch (e) {
      _erro = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _enviando = false;
      notifyListeners();
    }
  }
}
