import 'dart:async';

import 'package:flutter/foundation.dart';

import '../servizos/servizo_base_datos.dart';
import '../servizos/servizo_sincronizacion_p2p.dart';

class InicioSupervisorViewModel extends ChangeNotifier {
  final Future<List<Map<String, dynamic>>> Function() _obterPacientes;
  final Future<void> Function() _solicitarSincronizacion;
  final Stream<String> _actualizacions;
  final Future<void> Function(Duration) _agardar;

  InicioSupervisorViewModel({
    ServizoBaseDatos? database,
    ServizoSincronizacionP2P? sincronizacion,
    Future<void> Function(Duration)? agardar,
  }) : this.conDependencias(
         obterPacientes:
             (database ?? ServizoBaseDatos()).obterPacientesSupervisor,
         solicitarSincronizacion: (sincronizacion ?? ServizoSincronizacionP2P())
             .solicitarSincronizacion,
         actualizacions:
             (sincronizacion ?? ServizoSincronizacionP2P()).actualizacions,
         agardar: agardar,
       );

  InicioSupervisorViewModel.conDependencias({
    required Future<List<Map<String, dynamic>>> Function() obterPacientes,
    required Future<void> Function() solicitarSincronizacion,
    required Stream<String> actualizacions,
    Future<void> Function(Duration)? agardar,
  }) : _obterPacientes = obterPacientes,
       _solicitarSincronizacion = solicitarSincronizacion,
       _actualizacions = actualizacions,
       _agardar = agardar ?? Future<void>.delayed;

  List<Map<String, dynamic>> _pacientes = const [];
  bool _actualizando = false;
  String? _erro;
  Timer? _timer;
  StreamSubscription<String>? _subscricion;

  List<Map<String, dynamic>> get pacientes => _pacientes;
  bool get actualizando => _actualizando;
  String? get erro => _erro;

  void iniciar() {
    _subscricion ??= _actualizacions.listen((evento) {
      if (evento.startsWith('supervisor:')) cargar();
    });
    cargar();
    sincronizar();
    _timer ??= Timer.periodic(const Duration(hours: 1), (_) => sincronizar());
  }

  Future<void> cargar() async {
    try {
      _pacientes = await _obterPacientes();
      _erro = null;
      notifyListeners();
    } catch (e) {
      _erro = 'Non se puideron cargar os pacientes';
      notifyListeners();
    }
  }

  Future<void> sincronizar() async {
    if (_actualizando) return;
    _actualizando = true;
    _erro = null;
    notifyListeners();
    try {
      await _solicitarSincronizacion();
      await _agardar(const Duration(seconds: 2));
      _pacientes = await _obterPacientes();
    } catch (e) {
      _erro = 'Non se puideron actualizar os pacientes';
    } finally {
      _actualizando = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscricion?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}
