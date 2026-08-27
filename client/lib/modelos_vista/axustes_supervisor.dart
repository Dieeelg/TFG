import 'package:flutter/foundation.dart';

import '../servizos/servizo_base_datos.dart';
import '../servizos/servizo_sincronizacion_p2p.dart';

class AxustesSupervisorViewModel extends ChangeNotifier {
  final Future<List<Map<String, dynamic>>> Function() _obterPacientes;
  final Future<void> Function({
    required String uid,
    required String tokenPaciente,
  })
  _desvincularPaciente;

  AxustesSupervisorViewModel({
    ServizoBaseDatos? database,
    ServizoSincronizacionP2P? sincronizacion,
  }) : this.conDependencias(
         obterPacientes:
             (database ?? ServizoBaseDatos()).obterPacientesSupervisor,
         desvincularPaciente:
             (sincronizacion ?? ServizoSincronizacionP2P()).desvincularPaciente,
       );

  AxustesSupervisorViewModel.conDependencias({
    required Future<List<Map<String, dynamic>>> Function() obterPacientes,
    required Future<void> Function({
      required String uid,
      required String tokenPaciente,
    })
    desvincularPaciente,
  }) : _obterPacientes = obterPacientes,
       _desvincularPaciente = desvincularPaciente;

  List<Map<String, dynamic>> _pacientes = const [];
  bool _cargando = false;
  String? _eliminandoUid;
  String? _erro;

  List<Map<String, dynamic>> get pacientes => _pacientes;
  bool get cargando => _cargando;
  String? get eliminandoUid => _eliminandoUid;
  String? get erro => _erro;

  Future<void> cargar() async {
    _cargando = true;
    _erro = null;
    notifyListeners();
    try {
      _pacientes = await _obterPacientes();
    } catch (e) {
      _erro = 'Non se puideron cargar os pacientes';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> eliminar(Map<String, dynamic> paciente) async {
    final uid = paciente['uid'] as String;
    _eliminandoUid = uid;
    _erro = null;
    notifyListeners();
    try {
      await _desvincularPaciente(
        uid: uid,
        tokenPaciente: paciente['token'] as String,
      );
      _pacientes = await _obterPacientes();
      return true;
    } catch (e) {
      _erro = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _eliminandoUid = null;
      notifyListeners();
    }
  }

  String nomePaciente(int indice) {
    final datos = _pacientes[indice]['datos'] as Map<String, dynamic>;
    final nome = (datos['nome'] as String?)?.trim();
    return nome?.isNotEmpty == true ? nome! : 'Persoa ${indice + 1}';
  }
}
