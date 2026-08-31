import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../servizos/servizo_notificacions_locais.dart';
import '../../servizos/servizo_sincronizacion_p2p.dart';

class ConfiguracionAdicionalViewModel extends ChangeNotifier {
  final Future<void> Function(String key) _eliminar;
  final Future<void> Function(String key, String value) _escribir;
  final Future<void> Function({required String nome, required String hora})
  _programarTomas;
  final Future<void> Function(String tipo) _notificarSupervisores;

  ConfiguracionAdicionalViewModel({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    ServizoNotificacionsLocais? notificacions,
    ServizoSincronizacionP2P? sincronizacion,
  }) : this.conDependencias(
         eliminar: (key) => storage.delete(key: key),
         escribir: (key, value) => storage.write(key: key, value: value),
         programarTomas: (notificacions ?? ServizoNotificacionsLocais())
             .programarTomasPaciente,
         notificarSupervisores: (sincronizacion ?? ServizoSincronizacionP2P())
             .notificarSupervisores,
       );

  ConfiguracionAdicionalViewModel.conDependencias({
    required Future<void> Function(String key) eliminar,
    required Future<void> Function(String key, String value) escribir,
    required Future<void> Function({required String nome, required String hora})
    programarTomas,
    required Future<void> Function(String tipo) notificarSupervisores,
  }) : _eliminar = eliminar,
       _escribir = escribir,
       _programarTomas = programarTomas,
       _notificarSupervisores = notificarSupervisores;

  bool _gardando = false;
  String? _erro;

  bool get gardando => _gardando;
  String? get erro => _erro;

  Future<bool> gardar({required String nome, required String hora}) async {
    if (_gardando) return false;
    _gardando = true;
    _erro = null;
    notifyListeners();
    try {
      final nomeLimpo = nome.trim();
      if (nomeLimpo.isEmpty) {
        await _eliminar('nome_usuario');
      } else {
        await _escribir('nome_usuario', nomeLimpo);
      }
      await _escribir('hora_toma', hora);
      await _escribir('configuracion_finalizada', 'true');
      await _programarTomas(nome: nomeLimpo, hora: hora);
      await _notificarSupervisores('ESTADO_COMPLETO');
      return true;
    } catch (e) {
      _erro = 'Non se puido gardar a configuración';
      return false;
    } finally {
      _gardando = false;
      notifyListeners();
    }
  }
}
