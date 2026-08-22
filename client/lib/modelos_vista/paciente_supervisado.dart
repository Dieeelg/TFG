import 'dart:async';

import 'package:flutter/foundation.dart';

import '../servizos/servizo_base_datos.dart';
import '../servizos/servizo_sincronizacion_p2p.dart';

class SupervisedPatientViewModel extends ChangeNotifier {
  final Future<List<Map<String, dynamic>>> Function() _obterPacientes;
  final Stream<String> _actualizacions;
  final int numero;
  StreamSubscription<String>? _subscricion;

  SupervisedPatientViewModel({
    required Map<String, dynamic> paciente,
    required int numero,
    DatabaseService? database,
    P2PSyncService? sincronizacion,
  }) : this.conDependencias(
         paciente: paciente,
         numero: numero,
         obterPacientes: (database ?? DatabaseService()).obterPacientesCoidador,
         actualizacions: (sincronizacion ?? P2PSyncService()).actualizacions,
       );

  SupervisedPatientViewModel.conDependencias({
    required Map<String, dynamic> paciente,
    required this.numero,
    required Future<List<Map<String, dynamic>>> Function() obterPacientes,
    required Stream<String> actualizacions,
  }) : _paciente = paciente,
       _obterPacientes = obterPacientes,
       _actualizacions = actualizacions;

  Map<String, dynamic> _paciente;
  String? _erro;

  Map<String, dynamic> get paciente => _paciente;
  Map<String, dynamic> get datos => _paciente['datos'] as Map<String, dynamic>;
  String? get erro => _erro;
  String get nomeVisible {
    final nome = (datos['nome'] as String?)?.trim();
    return nome?.isNotEmpty == true ? nome! : 'Persoa $numero';
  }

  List<double> get valoresInr =>
      _valoresHistoricos(campo: 'inr', actual: datos['inrActual']);

  List<double> get valoresDose =>
      _valoresHistoricos(campo: 'dose', actual: datos['doseSemanalActual']);

  void iniciar() {
    _subscricion ??= _actualizacions.listen((evento) {
      if (evento == 'coidador:${_paciente['uid']}') recargar();
    });
  }

  Future<void> recargar() async {
    try {
      final pacientes = await _obterPacientes();
      final atopados = pacientes.where((p) => p['uid'] == _paciente['uid']);
      if (atopados.isNotEmpty) {
        _paciente = atopados.first;
        _erro = null;
        notifyListeners();
      }
    } catch (e) {
      _erro = 'Non se puideron actualizar os datos do paciente';
      notifyListeners();
    }
  }

  List<double> _valoresHistoricos({
    required String campo,
    required dynamic actual,
  }) {
    final historico =
        (datos['historico'] as List?)?.whereType<Map>().toList() ?? const [];
    return [
      ...historico.map((h) => numeroDesde(h[campo])).whereType<double>(),
      if (numeroDesde(actual) case final valor?) valor,
    ];
  }

  static double? numeroDesde(dynamic valor) {
    if (valor == null) return null;
    return double.tryParse(
      valor.toString().replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), ''),
    );
  }

  @override
  void dispose() {
    _subscricion?.cancel();
    super.dispose();
  }
}
