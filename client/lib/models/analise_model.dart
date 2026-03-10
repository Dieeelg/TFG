import 'cabeceira_model.dart';
import 'dose_dia_model.dart';
import 'historico_model.dart';

class AnaliseModel{
  final CabeceiraModel cabeceira;
  final List<DoseDiaModel> calendario;
  final List<ItemHistoricoModel> historico;

  AnaliseModel({
    required this.cabeceira,
    required this.calendario,
    required this.historico,
  });

  factory AnaliseModel.fromJson(Map<String, dynamic> json) {
    return AnaliseModel(
      cabeceira: CabeceiraModel.fromJson(json['cabeceira']),
      calendario: (json['calendario'] as List)
          .map((i) => DoseDiaModel.fromJson(i))
          .toList(),
      historico: (json['historico'] as List)
          .map((i) => ItemHistoricoModel.fromJson(i))
          .toList(),
    );
  }
}