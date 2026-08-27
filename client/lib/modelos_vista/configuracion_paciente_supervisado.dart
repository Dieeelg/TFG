import 'package:flutter/foundation.dart';

import '../servizos/servizo_sincronizacion_p2p.dart';

class ConfiguracionPacienteSupervisadoViewModel extends ChangeNotifier {
  final Future<void> Function({
    required String tokenPaciente,
    required String nome,
    required String horaToma,
  })
  _enviarConfiguracion;

  ConfiguracionPacienteSupervisadoViewModel({
    ServizoSincronizacionP2P? sincronizacion,
  }) : this.conDependencias(
         enviarConfiguracion: (sincronizacion ?? ServizoSincronizacionP2P())
             .enviarConfiguracionPaciente,
       );

  ConfiguracionPacienteSupervisadoViewModel.conDependencias({
    required Future<void> Function({
      required String tokenPaciente,
      required String nome,
      required String horaToma,
    })
    enviarConfiguracion,
  }) : _enviarConfiguracion = enviarConfiguracion;

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
      await _enviarConfiguracion(
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
