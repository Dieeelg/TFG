import 'cabeceira.dart';
import 'dose_dia.dart';
import 'historico.dart';

class AnaliseModel {
  final CabeceiraModel cabeceira;
  final List<DoseDiaModel> calendario;
  final List<ItemHistoricoModel> historico;

  AnaliseModel({
    //Constructor
    required this.cabeceira,
    required this.calendario,
    required this.historico,
  });

  //Trducimos os datos que recibimos da API aos nosos modelos Dart
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
