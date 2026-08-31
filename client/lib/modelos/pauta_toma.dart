/// A diferenza de `DoseDiaModel` (que contén a receita médica estática da API),
/// `PautaTomaModel` engade a xestión do [estado] interactivo da dose.
/// Utilízase na pantalla principal para que a aplicación poida rexistrar
/// se o paciente xa tomou a pastilla hoxe, se está pendente, ou se a saltou.
class PautaTomaModel {
  final String data;
  final String dia;
  final String dose;
  final String estado; // PENDENTE, TOMADA, TOMADA_FORA_HORA ou NON_TOMADA
  final bool eControl;

  PautaTomaModel({
    required this.data,
    required this.dia,
    required this.dose,
    required this.estado,
    required this.eControl,
  });
}
