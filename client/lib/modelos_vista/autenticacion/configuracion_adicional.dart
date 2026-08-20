import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../servizos/servizo_notificacions_locais.dart';
import '../../servizos/servizo_sincronizacion_p2p.dart';

class AdditionalSettingsViewModel extends ChangeNotifier {
  final FlutterSecureStorage _storage;
  final Future<void> Function({required String nome, required String hora})
  _programarTomas;
  final Future<void> Function(String tipo) _notificarCoidador;

  AdditionalSettingsViewModel({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    LocalNotificationService? notificacions,
    P2PSyncService? sincronizacion,
  }) : _storage = storage,
       _programarTomas =
           (notificacions ?? LocalNotificationService()).programarTomasPaciente,
       _notificarCoidador =
           (sincronizacion ?? P2PSyncService()).notificarCoidador;

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
        await _storage.delete(key: 'nome_usuario');
      } else {
        await _storage.write(key: 'nome_usuario', value: nomeLimpo);
      }
      await _storage.write(key: 'hora_toma', value: hora);
      await _storage.write(key: 'configuracion_finalizada', value: 'true');
      await _programarTomas(nome: nomeLimpo, hora: hora);
      await _notificarCoidador('ESTADO_COMPLETO');
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
