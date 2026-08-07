import 'analise.dart';
import 'cabeceira.dart';
import 'dose_dia.dart';

class RevisionPauta {
  static const List<String> _diasSemana = [
    'LUNS',
    'MARTES',
    'MÉRCORES',
    'XOVES',
    'VENRES',
    'SÁBADO',
    'DOMINGO',
  ];

  static DateTime? interpretarData(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return null;

    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(texto);
    if (iso != null) {
      return _crearDataExacta(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }

    final europea = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(texto);
    if (europea != null) {
      return _crearDataExacta(
        int.parse(europea.group(3)!),
        int.parse(europea.group(2)!),
        int.parse(europea.group(1)!),
      );
    }
    return null;
  }

  static DateTime? _crearDataExacta(int ano, int mes, int dia) {
    if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;
    final data = DateTime(ano, mes, dia);
    return data.year == ano && data.month == mes && data.day == dia
        ? data
        : null;
  }

  static String formatoIso(DateTime data) =>
      '${data.year.toString().padLeft(4, '0')}-'
      '${data.month.toString().padLeft(2, '0')}-'
      '${data.day.toString().padLeft(2, '0')}';

  static String formatoVisita(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}/'
      '${data.year.toString().padLeft(4, '0')}';

  static String diaSemana(DateTime data) => _diasSemana[data.weekday - 1];

  static AnaliseModel actualizarDia(
    AnaliseModel analise,
    int indice, {
    DateTime? data,
    String? dose,
    bool? eControl,
  }) {
    final anterior = analise.calendario[indice];
    final novaData = data ?? interpretarData(anterior.data)!;
    final novoControl = eControl ?? anterior.eControl;
    final novaDose = novoControl ? null : (dose ?? anterior.dose ?? '0').trim();
    final novaAccion = novoControl
        ? 'CONTROL'
        : novaDose == '0'
        ? 'NON TOMAR'
        : 'TOMAR';

    final calendario = [...analise.calendario];
    calendario[indice] = DoseDiaModel(
      data: formatoIso(novaData),
      dia: novaData.day,
      dose: novaDose,
      accion: novaAccion,
      eControl: novoControl,
      diaSemanaTexto: diaSemana(novaData),
    );
    return AnaliseModel(
      cabeceira: analise.cabeceira,
      calendario: calendario,
      historico: analise.historico,
    );
  }

  static AnaliseModel actualizarProximaVisita(
    AnaliseModel analise,
    DateTime? data,
  ) {
    final cabeceira = analise.cabeceira;
    return AnaliseModel(
      cabeceira: CabeceiraModel(
        dataInforme: cabeceira.dataInforme,
        inr: cabeceira.inr,
        farmaco: cabeceira.farmaco,
        doseSemanal: cabeceira.doseSemanal,
        proximaVisita: data == null ? null : formatoVisita(data),
        centro: cabeceira.centro,
      ),
      calendario: analise.calendario,
      historico: analise.historico,
    );
  }

  static AnaliseModel ordenar(AnaliseModel analise) {
    final calendario = [...analise.calendario]
      ..sort((a, b) => a.data.compareTo(b.data));
    return AnaliseModel(
      cabeceira: analise.cabeceira,
      calendario: calendario,
      historico: analise.historico,
    );
  }

  static List<String> validar(AnaliseModel analise) {
    final erros = <String>[];
    if (analise.calendario.isEmpty) {
      erros.add('A pauta debe conter polo menos un día.');
      return erros;
    }

    final datas = <String>{};
    for (var i = 0; i < analise.calendario.length; i++) {
      final dia = analise.calendario[i];
      if (interpretarData(dia.data) == null) {
        erros.add('A data da fila ${i + 1} non é válida.');
      } else if (!datas.add(dia.data)) {
        erros.add('A data ${dia.data} está repetida.');
      }

      if (!dia.eControl) {
        final dose = dia.dose?.trim() ?? '';
        if (dose.isEmpty) {
          erros.add('Falta a dose do ${dia.data}.');
        } else if (!_doseValida(dose)) {
          erros.add('A dose «$dose» do ${dia.data} non é válida.');
        }
      }
    }

    final visita = analise.cabeceira.proximaVisita?.trim() ?? '';
    if (visita.isNotEmpty && interpretarData(visita) == null) {
      erros.add('A data da seguinte visita non é válida.');
    }
    return erros;
  }

  static bool _doseValida(String dose) {
    final normalizada = dose.replaceAll(' ', '').replaceAll(',', '.');
    if (RegExp(r'^\d+(?:\.\d+)?$').hasMatch(normalizada)) return true;

    final fraccion = RegExp(
      r'^(?:(\d+)\+)?(\d+)/(\d+)$',
    ).firstMatch(normalizada);
    if (fraccion == null) return false;
    return int.parse(fraccion.group(3)!) != 0;
  }
}
