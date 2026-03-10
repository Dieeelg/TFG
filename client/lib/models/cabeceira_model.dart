class CabeceiraModel {
  final String? dataInforme;
  final String? inr;
  final String? farmaco;
  final String? doseSemanal;
  final String? proximaVisita;
  final String? centro;

  CabeceiraModel({
    this.dataInforme,
    this.inr,
    this.farmaco,
    this.doseSemanal,
    this.proximaVisita,
    this.centro,
  });

  factory CabeceiraModel.fromJson(Map<String, dynamic> json) {
    return CabeceiraModel(
      dataInforme: json['dataInforme'],
      inr: json['inr'],
      farmaco: json['farmaco'],
      doseSemanal: json['doseSemanal'],
      proximaVisita: json['proximaVisita'],
      centro: json['centro'],
    );
  }
}