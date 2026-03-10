class DoseDiaModel{
  final String data;
  final int dia;
  final String? dose; //Recordemos que dose pode ser null por que o día do control non ten dose.
  final String accion;
  final bool eControl;
  final String diaSemanaTexto;

  DoseDiaModel({
    required this.data,
    required this.dia,
    this.dose,
    required this.accion,
    required this.eControl,
    required this.diaSemanaTexto,
  });

  factory DoseDiaModel.fromJson(Map<String, dynamic> json) {
    return DoseDiaModel(
      data: json['data'],
      dia: json['dia'],
      dose: json['dose'],
      accion: json['accion'],
      eControl: json['eControl'],
      diaSemanaTexto: json['diaSemanaTexto'],
    );
  }
}