class ItemHistoricoModel {
  final String? data;
  final String? inr;
  final String? farmaco;
  final String? dose;
  final String? apttInyectable;
  final String? doseInyectable;
  final String? proximaVisita;
  final String? comentarios;

  ItemHistoricoModel({
    this.data,
    this.inr,
    this.farmaco,
    this.dose,
    this.apttInyectable,
    this.doseInyectable,
    this.proximaVisita,
    this.comentarios,
  });

  factory ItemHistoricoModel.fromJson(Map<String, dynamic> json) {
    return ItemHistoricoModel(
      data: json['data'],
      inr: json['inr'],
      farmaco: json['farmaco'],
      dose: json['dose'],
      apttInyectable: json['apttInyectable'],
      doseInyectable: json['doseInyectable'],
      proximaVisita: json['proximaVisita'],
      comentarios: json['comentarios'],
    );
  }
}