import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../servizos/servizo_cifrado_p2p.dart';
import '../servizos/servizo_notificacions_locais.dart';
import '../servizos/servizo_sincronizacion_p2p.dart';

export '../servizos/servizo_cifrado_p2p.dart' show VinculacionP2P;

class PatientSettingsViewModel extends ChangeNotifier {
  final Future<String?> Function(String key) _ler;
  final Future<void> Function(String key, String value) _escribir;
  final Future<void> Function(String key) _eliminar;
  final Future<List<VinculacionP2P>> Function() _obterSupervisores;
  final Future<void> Function({required String nome, required String hora})
  _programarTomas;
  final Future<void> Function(String tipo) _notificarCoidador;
  final Future<void> Function(VinculacionP2P vinculacion) _desvincularCoidador;
  final Future<String?> Function() _obterUid;
  final Future<String?> Function() _obterToken;
  final Future<String> Function({
    required String uidPaciente,
    required String tokenPaciente,
  })
  _xerarCodigoVinculacion;

  PatientSettingsViewModel({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    ServizoCifradoP2P? cifrado,
    LocalNotificationService? notificacions,
    P2PSyncService? sincronizacion,
    Future<String?> Function()? obterUid,
    Future<String?> Function()? obterToken,
  }) : this.conDependencias(
         ler: (key) => storage.read(key: key),
         escribir: (key, value) => storage.write(key: key, value: value),
         eliminar: (key) => storage.delete(key: key),
         obterSupervisores: () =>
             (cifrado ?? ServizoCifradoP2P()).obterPorRolRemoto('COIDADOR'),
         programarTomas: (notificacions ?? LocalNotificationService())
             .programarTomasPaciente,
         notificarCoidador:
             (sincronizacion ?? P2PSyncService()).notificarCoidador,
         desvincularCoidador:
             (sincronizacion ?? P2PSyncService()).desvincularCoidador,
         obterUid:
             obterUid ?? (() async => FirebaseAuth.instance.currentUser?.uid),
         obterToken:
             obterToken ?? (() => FirebaseMessaging.instance.getToken()),
         xerarCodigoVinculacion:
             (cifrado ?? ServizoCifradoP2P()).xerarCodigoVinculacion,
       );

  PatientSettingsViewModel.conDependencias({
    required Future<String?> Function(String key) ler,
    required Future<void> Function(String key, String value) escribir,
    required Future<void> Function(String key) eliminar,
    required Future<List<VinculacionP2P>> Function() obterSupervisores,
    required Future<void> Function({required String nome, required String hora})
    programarTomas,
    required Future<void> Function(String tipo) notificarCoidador,
    required Future<void> Function(VinculacionP2P vinculacion)
    desvincularCoidador,
    required Future<String?> Function() obterUid,
    required Future<String?> Function() obterToken,
    required Future<String> Function({
      required String uidPaciente,
      required String tokenPaciente,
    })
    xerarCodigoVinculacion,
  }) : _ler = ler,
       _escribir = escribir,
       _eliminar = eliminar,
       _obterSupervisores = obterSupervisores,
       _programarTomas = programarTomas,
       _notificarCoidador = notificarCoidador,
       _desvincularCoidador = desvincularCoidador,
       _obterUid = obterUid,
       _obterToken = obterToken,
       _xerarCodigoVinculacion = xerarCodigoVinculacion;

  String _nome = '';
  String _hora = '20:00';
  bool _modoSinxelo = false;
  bool _cargando = false;
  bool _cargado = false;
  bool _gardando = false;
  String? _desvinculandoId;
  String? _erro;
  List<VinculacionP2P> _supervisores = const [];

  String get nome => _nome;
  String get hora => _hora;
  bool get modoSinxelo => _modoSinxelo;
  bool get cargando => _cargando;
  bool get cargado => _cargado;
  bool get gardando => _gardando;
  String? get desvinculandoId => _desvinculandoId;
  String? get erro => _erro;
  List<VinculacionP2P> get supervisores => _supervisores;

  Future<void> cargar() async {
    _cargando = true;
    _erro = null;
    notifyListeners();
    try {
      final resultados = await Future.wait<Object?>([
        _ler('nome_usuario'),
        _ler('hora_toma'),
        _ler('modo_sinxelo'),
        _obterSupervisores(),
      ]);
      _nome = (resultados[0] as String?) ?? '';
      _hora = (resultados[1] as String?) ?? '20:00';
      _modoSinxelo = resultados[2] == 'true';
      _supervisores = resultados[3] as List<VinculacionP2P>;
      _cargado = true;
    } catch (e) {
      _erro = 'Non se puideron cargar os axustes';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  void cambiarModoSinxelo(bool activar) {
    _modoSinxelo = activar;
    notifyListeners();
  }

  Future<bool> gardar({required String nome, required String hora}) async {
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
      await _escribir('modo_sinxelo', _modoSinxelo ? 'true' : 'false');
      await _programarTomas(nome: nomeLimpo, hora: hora);
      await _notificarCoidador('ESTADO_COMPLETO');
      _nome = nomeLimpo;
      _hora = hora;
      return true;
    } catch (e) {
      _erro = 'Non se puideron gardar os cambios';
      return false;
    } finally {
      _gardando = false;
      notifyListeners();
    }
  }

  Future<bool> desvincular(VinculacionP2P vinculacion) async {
    _desvinculandoId = vinculacion.id;
    _erro = null;
    notifyListeners();
    try {
      await _desvincularCoidador(vinculacion);
      _supervisores = await _obterSupervisores();
      return true;
    } catch (e) {
      _erro = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _desvinculandoId = null;
      notifyListeners();
    }
  }

  Future<String?> xerarCodigoQr() async {
    _erro = null;
    final resultados = await Future.wait<String?>([_obterUid(), _obterToken()]);
    final uid = resultados[0];
    final token = resultados[1];
    if (uid == null || token == null) {
      _erro = 'Non se puido xerar o código QR';
      notifyListeners();
      return null;
    }
    try {
      return await _xerarCodigoVinculacion(
        uidPaciente: uid,
        tokenPaciente: token,
      );
    } catch (e) {
      _erro = 'Non se puido xerar o código QR';
      notifyListeners();
      return null;
    }
  }
}
