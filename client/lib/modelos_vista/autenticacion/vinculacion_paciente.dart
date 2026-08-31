import 'package:flutter/material.dart'; // Estado da vinculación do paciente.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import '../../servizos/servizo_cifrado_p2p.dart';

class VinculacionPacienteViewModel extends ChangeNotifier {
  String? _datosQR; //A información que conterá o QR
  bool _cargando = false;
  Timer? _timer; //Para comprobar se xa se escaneou o QR ou non
  final Future<String?> Function() _obterUid;
  final Future<String?> Function() _obterToken;
  final Future<String> Function({
    required String uidPaciente,
    required String tokenPaciente,
  })
  _xerarCodigo;
  final Future<String?> Function(String key) _ler;
  final bool _activarTimer;
  bool _tenSupervisor = false;
  String? _erro;

  VinculacionPacienteViewModel({
    FirebaseAuth? autenticacion,
    FirebaseMessaging? mensaxeria,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    ServizoCifradoP2P? cifrado,
  }) : this.conDependencias(
         obterUid: () async =>
             (autenticacion ?? FirebaseAuth.instance).currentUser?.uid,
         obterToken: () =>
             (mensaxeria ?? FirebaseMessaging.instance).getToken(),
         xerarCodigo: (cifrado ?? ServizoCifradoP2P()).xerarCodigoVinculacion,
         ler: (key) => storage.read(key: key),
         activarTimer: true,
       );

  VinculacionPacienteViewModel.conDependencias({
    required Future<String?> Function() obterUid,
    required Future<String?> Function() obterToken,
    required Future<String> Function({
      required String uidPaciente,
      required String tokenPaciente,
    })
    xerarCodigo,
    required Future<String?> Function(String key) ler,
    bool activarTimer = false,
  }) : _obterUid = obterUid,
       _obterToken = obterToken,
       _xerarCodigo = xerarCodigo,
       _ler = ler,
       _activarTimer = activarTimer;

  bool get tenSupervisor => _tenSupervisor;
  String? get datosQR => _datosQR;
  bool get cargando => _cargando;
  String? get erro => _erro;

  Future<void> xerarDatosVinculacion() async {
    _cargando = true;
    _datosQR = null;
    _erro = null;
    notifyListeners();

    try {
      final String uid = await _obterUid() ?? "sen_id";
      final token = await _obterToken().timeout(const Duration(seconds: 15));

      if (token == null || token.isEmpty) {
        throw Exception('Non se puido obter o token de mensaxería');
      }
      _datosQR = await _xerarCodigo(uidPaciente: uid, tokenPaciente: token);

      if (_activarTimer) _iniciarChequeoAutomatico();
    } catch (e) {
      _datosQR = null;
      _erro =
          'Non se puido crear o código. Comproba a conexión e téntao de novo.';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  void _iniciarChequeoAutomatico() {
    //Miramos cada dous segundos se xa esta no storage o UID do supervisor
    _timer?.cancel(); // Cancelamos se houbera un previo
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await comprobarEstadoVinculacion();
      if (_tenSupervisor) {
        timer.cancel(); // Se xa temos supervisor, paramos o timer
      }
    });
  }

  Future<void> comprobarEstadoVinculacion() async {
    String? tokenSupervisor = await _ler('token_supervisor');
    if (tokenSupervisor != null && !_tenSupervisor) {
      _tenSupervisor = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    //Para eliminar o timer unha vez se salga da pantalla de vinculación
    _timer?.cancel();
    super.dispose();
  }
}
