import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/analise_model.dart';

// Definimos o modelo de datos para a pauta semanal
class PautaToma {
  final String dia;
  final String dose;
  final String estado; // 'PENDENTE', 'CONFIRMADA', 'SALTADA'

  PautaToma({required this.dia, required this.dose, required this.estado});
}

class HomeViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _cargando = false;
  AnaliseModel? _ultimaAnalise;

  bool get cargando => _cargando;
  AnaliseModel? get ultimaAnalise => _ultimaAnalise;

  // ESTA É A LISTA QUE FALTA E CORRIXE O ERRO
  List<PautaToma> pautaSemanal = [
    PautaToma(dia: "Lun 6", dose: "1/2", estado: "CONFIRMADA"),
    PautaToma(dia: "Mar 7", dose: "1/4", estado: "CONFIRMADA"),
    PautaToma(dia: "Mér 8", dose: "1/2", estado: "CONFIRMADA"),
    PautaToma(dia: "Xov 9", dose: "NON", estado: "SALTADA"),
    PautaToma(dia: "Ven 10", dose: "1/2", estado: "PENDENTE"),
    PautaToma(dia: "Sab 11", dose: "1/3", estado: "PENDENTE"),
    PautaToma(dia: "Dom 12", dose: "1/2", estado: "PENDENTE"),
  ];

  String get doseHoxe {
    if (_ultimaAnalise == null || _ultimaAnalise!.calendario.isEmpty) return "3/4";
    return _ultimaAnalise!.calendario.first.dose ?? "3/4";
  }

  Future<void> cargarDatosHome() async {
    _cargando = true;
    notifyListeners();

    try {
      // Aquí irá a chamada real á API no futuro
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      debugPrint("Erro ao cargar datos: $e");
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }
}