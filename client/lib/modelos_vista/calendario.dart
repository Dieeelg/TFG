import 'package:flutter/foundation.dart';

import '../modelos/cabeceira.dart';
import '../modelos/dose_dia.dart';
import '../servizos/servizo_base_datos.dart';

class CalendarViewModel extends ChangeNotifier {
  final Future<void> Function() _pecharTomasVencidas;
  final Future<List<DoseDiaModel>> Function() _obterPauta;
  final Future<Map<String, String>> Function() _obterEstados;
  final Future<CabeceiraModel?> Function() _obterCabeceira;
  final DateTime Function() _agora;

  CalendarViewModel({DatabaseService? database, DateTime Function()? agora})
    : this.conDependencias(
        pecharTomasVencidas:
            (database ?? DatabaseService()).pecharTomasVencidas,
        obterPauta: (database ?? DatabaseService()).obterPauta,
        obterEstados: (database ?? DatabaseService()).obterEstados,
        obterCabeceira: (database ?? DatabaseService()).obterCabeceira,
        agora: agora,
      );

  CalendarViewModel.conDependencias({
    required Future<void> Function() pecharTomasVencidas,
    required Future<List<DoseDiaModel>> Function() obterPauta,
    required Future<Map<String, String>> Function() obterEstados,
    required Future<CabeceiraModel?> Function() obterCabeceira,
    DateTime Function()? agora,
  }) : _pecharTomasVencidas = pecharTomasVencidas,
       _obterPauta = obterPauta,
       _obterEstados = obterEstados,
       _obterCabeceira = obterCabeceira,
       _agora = agora ?? DateTime.now;

  List<DoseDiaModel> _pauta = const [];
  Map<String, String> _estados = const {};
  String? _proximaVisita;
  bool _cargando = false;
  String? _erro;

  List<DoseDiaModel> get pauta => _pauta;
  Map<String, String> get estados => _estados;
  String? get proximaVisita => _proximaVisita;
  bool get cargando => _cargando;
  String? get erro => _erro;

  String get hoxe => _agora().toIso8601String().substring(0, 10);

  int get tomadas => _tomables.where((d) => _eTomada(_estados[d.data])).length;

  int get esquecidas => _tomables
      .where((d) => !_eTomada(_estados[d.data]) && d.data.compareTo(hoxe) < 0)
      .length;

  int get cumprimento {
    final decididas = tomadas + esquecidas;
    return decididas == 0 ? 0 : (tomadas * 100 / decididas).round();
  }

  int? get diasAtaCita {
    final texto = _proximaVisita;
    if (texto == null || texto.trim().isEmpty) return null;
    final partes = texto.split(RegExp(r'[-/]'));
    DateTime? cita;
    if (partes.length == 3) {
      cita = partes[0].length == 4
          ? DateTime.tryParse(
              '${partes[0]}-${partes[1].padLeft(2, '0')}-${partes[2].padLeft(2, '0')}',
            )
          : DateTime.tryParse(
              '${partes[2]}-${partes[1].padLeft(2, '0')}-${partes[0].padLeft(2, '0')}',
            );
    }
    if (cita == null) return null;
    final agora = _agora();
    return cita.difference(DateTime(agora.year, agora.month, agora.day)).inDays;
  }

  String? estadoDe(String data) => _estados[data];

  Future<void> cargar() async {
    _cargando = true;
    _erro = null;
    notifyListeners();
    try {
      await _pecharTomasVencidas();
      final resultados = await Future.wait<Object?>([
        _obterPauta(),
        _obterEstados(),
        _obterCabeceira(),
      ]);
      _pauta = resultados[0] as List<DoseDiaModel>;
      _estados = resultados[1] as Map<String, String>;
      _proximaVisita = (resultados[2] as CabeceiraModel?)?.proximaVisita;
    } catch (e) {
      _erro = 'Non se puido cargar o calendario';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  List<DoseDiaModel> get _tomables =>
      _pauta.where((d) => !d.eControl && d.dose != '0').toList();

  bool _eTomada(String? estado) =>
      estado == 'TOMADA' || estado == 'TOMADA_FORA_HORA';
}
