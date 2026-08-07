enum TipoRecordatorioToma { toma, esquecemento }

class RecordatorioToma {
  const RecordatorioToma({
    required this.data,
    required this.instante,
    required this.tipo,
  });

  final String data;
  final DateTime instante;
  final TipoRecordatorioToma tipo;
}

class PlanificadorRecordatorios {
  const PlanificadorRecordatorios._();

  static bool eDoseTomable(Object? dose) {
    final valor = dose?.toString().trim().toUpperCase().replaceAll(',', '.');
    if (valor == null || valor.isEmpty || valor == 'CTRL' || valor == 'NON') {
      return false;
    }
    if (valor.contains('/')) {
      final partes = valor.split('/');
      final numerador = double.tryParse(partes.first);
      final denominador = double.tryParse(partes.last);
      return numerador != null &&
          denominador != null &&
          denominador != 0 &&
          numerador != 0;
    }
    return double.tryParse(valor) != 0;
  }

  static List<RecordatorioToma> crear({
    required DateTime agora,
    required String hora,
    required Iterable<String> datasConToma,
    Map<String, String> estados = const {},
    int marxeEsquecementoMinutos = 30,
  }) {
    final partesHora = hora.split(':');
    if (partesHora.length != 2) return const [];
    final horaNumero = int.tryParse(partesHora[0]);
    final minutoNumero = int.tryParse(partesHora[1]);
    if (horaNumero == null ||
        minutoNumero == null ||
        horaNumero < 0 ||
        horaNumero > 23 ||
        minutoNumero < 0 ||
        minutoNumero > 59) {
      return const [];
    }

    final resultado = <RecordatorioToma>[];
    final datasOrdenadas = datasConToma.toSet().toList()..sort();
    for (final data in datasOrdenadas) {
      if (_estadoPechado(estados[data])) continue;
      final partesData = data.split('-');
      if (partesData.length != 3) continue;
      final ano = int.tryParse(partesData[0]);
      final mes = int.tryParse(partesData[1]);
      final dia = int.tryParse(partesData[2]);
      if (ano == null || mes == null || dia == null) continue;

      final toma = DateTime(ano, mes, dia, horaNumero, minutoNumero);
      if (toma.year != ano || toma.month != mes || toma.day != dia) continue;
      final esquecemento = toma.add(
        Duration(minutes: marxeEsquecementoMinutos),
      );
      if (toma.isAfter(agora)) {
        resultado.add(
          RecordatorioToma(
            data: data,
            instante: toma,
            tipo: TipoRecordatorioToma.toma,
          ),
        );
      }
      if (esquecemento.isAfter(agora)) {
        resultado.add(
          RecordatorioToma(
            data: data,
            instante: esquecemento,
            tipo: TipoRecordatorioToma.esquecemento,
          ),
        );
      }
    }
    return resultado;
  }

  static bool _estadoPechado(String? estado) =>
      estado == 'TOMADA' ||
      estado == 'TOMADA_FORA_HORA' ||
      estado == 'NON_TOMADA';
}
