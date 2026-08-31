import 'package:flutter/foundation.dart';

import '../modelos/cabeceira.dart';
import '../modelos/historico.dart';
import '../servizos/servizo_base_datos.dart';

class ProgresoViewModel extends ChangeNotifier {
  final Future<List<ItemHistoricoModel>> Function() _obterHistorico;
  final Future<CabeceiraModel?> Function() _obterCabeceira;
  final Future<List<Map<String, Object?>>> Function() _obterCumprimento;

  ProgresoViewModel({ServizoBaseDatos? database})
    : this.conDependencias(
        obterHistorico: (database ?? ServizoBaseDatos()).obterHistorico,
        obterCabeceira: (database ?? ServizoBaseDatos()).obterCabeceira,
        obterCumprimento:
            (database ?? ServizoBaseDatos()).obterRexistrosCumprimento,
      );

  ProgresoViewModel.conDependencias({
    required Future<List<ItemHistoricoModel>> Function() obterHistorico,
    required Future<CabeceiraModel?> Function() obterCabeceira,
    required Future<List<Map<String, Object?>>> Function() obterCumprimento,
  }) : _obterHistorico = obterHistorico,
       _obterCabeceira = obterCabeceira,
       _obterCumprimento = obterCumprimento;

  List<ItemHistoricoModel> _historico = const [];
  String _inrActual = '--';
  String _doseActual = '--';
  List<Map<String, Object?>> _cumprimento = const [];
  bool _cargando = false;
  String? _erro;

  List<ItemHistoricoModel> get historico => _historico;
  String get inrActual => _inrActual;
  String get doseActual => _doseActual;
  List<Map<String, Object?>> get cumprimento => _cumprimento;
  bool get cargando => _cargando;
  String? get erro => _erro;

  List<Map<String, Object?>> get rexistrosConDesviacion =>
      _cumprimento.where((r) => r['desviacionMinutos'] != null).toList();

  int get tomasForaDeHora =>
      _cumprimento.where((r) => r['estado'] == 'TOMADA_FORA_HORA').length;

  int? get desviacionMedia {
    final rexistros = rexistrosConDesviacion;
    if (rexistros.isEmpty) return null;
    final total = rexistros
        .map((r) => (r['desviacionMinutos'] as int).abs())
        .reduce((a, b) => a + b);
    return (total / rexistros.length).round();
  }

  List<double> get valoresInr => [
    ..._historico.map((e) => numero(e.inr)).whereType<double>(),
    if (numero(_inrActual) case final valor?) valor,
  ];

  List<double> get valoresDose => [
    ..._historico.map((e) => numero(e.dose)).whereType<double>(),
    if (numero(_doseActual) case final valor?) valor,
  ];

  Future<void> cargar() async {
    _cargando = true;
    _erro = null;
    notifyListeners();
    try {
      final resultados = await Future.wait<Object?>([
        _obterHistorico(),
        _obterCabeceira(),
        _obterCumprimento(),
      ]);
      _historico = resultados[0] as List<ItemHistoricoModel>;
      final cabeceira = resultados[1] as CabeceiraModel?;
      _inrActual = cabeceira?.inr ?? '--';
      _doseActual = cabeceira?.doseSemanal ?? '--';
      _cumprimento = resultados[2] as List<Map<String, Object?>>;
    } catch (e) {
      _erro = 'Non se puideron cargar os datos de progreso';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  static double? numero(String? texto) {
    if (texto == null) return null;
    final normalizado = texto.trim().replaceAll(',', '.');
    final fraccion = RegExp(
      r'(?:(\d+(?:\.\d+)?)\s*\+\s*)?(\d+)\s*/\s*(\d+)',
    ).firstMatch(normalizado);
    if (fraccion != null) {
      final denominador = int.parse(fraccion.group(3)!);
      if (denominador == 0) return null;
      final enteiro = double.tryParse(fraccion.group(1) ?? '0') ?? 0;
      return enteiro + int.parse(fraccion.group(2)!) / denominador;
    }
    final decimal = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(normalizado);
    return decimal == null ? null : double.tryParse(decimal.group(0)!);
  }
}
