import 'package:tfg_sintrom/modelos/analise.dart';
import 'package:tfg_sintrom/modelos/cabeceira.dart';
import 'package:tfg_sintrom/modelos/dose_dia.dart';
import 'package:tfg_sintrom/modelos/historico.dart';

AnaliseModel crearAnaliseProba() => AnaliseModel(
  cabeceira: CabeceiraModel(
    dataInforme: '2026-08-20',
    inr: '2,5',
    farmaco: 'Sintrom 4 mg',
    doseSemanal: '7 mg',
    proximaVisita: '27/08/2026',
    centro: 'Centro de saúde',
  ),
  calendario: [
    DoseDiaModel(
      data: '2026-08-21',
      dia: 21,
      dose: '1/2',
      accion: 'TOMAR',
      eControl: false,
      diaSemanaTexto: 'VENRES',
    ),
  ],
  historico: [
    ItemHistoricoModel(data: '2026-08-01', inr: '2,3', dose: '6,5 mg'),
  ],
);

Map<String, dynamic> crearPacienteProba({
  String uid = 'paciente-1',
  String nome = 'Ana',
}) => {
  'uid': uid,
  'token': 'token-$uid',
  'datos': {
    'nome': nome,
    'inrActual': '2,5',
    'doseSemanalActual': '7 mg',
    'historico': [
      {'inr': '2,2', 'dose': '6,5 mg'},
    ],
  },
};
