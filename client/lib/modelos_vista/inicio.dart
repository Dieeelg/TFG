import 'package:flutter/material.dart'; // Estado da pantalla de inicio.
import '../modelos/pauta_toma.dart';
import '../modelos/analise.dart';
import '../modelos/cabeceira.dart';
import '../servizos/servizo_base_datos.dart';
import '../servizos/servizo_sincronizacion_p2p.dart';
import '../servizos/servizo_notificacions_locais.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HomeViewModel extends ChangeNotifier {
  bool _cargando = false;
  AnaliseModel? _ultimaAnalise;
  CabeceiraModel? _cabeceira;

  bool get cargando => _cargando;
  CabeceiraModel? get cabeceira => _cabeceira;
  PautaToma? get tomaHoxe {
    if (pautaSemanal.isEmpty) return null;
    final hoxe = DateTime.now().toIso8601String().substring(0, 10);
    return pautaSemanal.where((toma) => toma.data == hoxe).firstOrNull ??
        pautaSemanal.where((toma) => toma.data.compareTo(hoxe) > 0).firstOrNull;
  }

  List<PautaToma> pautaSemanal = [];

  String get doseHoxe {
    if (_ultimaAnalise == null || _ultimaAnalise!.calendario.isEmpty) {
      return "--";
    }
    return tomaHoxe?.dose ?? "--";
  }

  Future<void> cargarDatosHome() async {
    _cargando = true;
    notifyListeners();

    try {
      final novasTomasEsquecidas = await DatabaseService()
          .pecharTomasVencidas();
      final pautaBD = await DatabaseService().obterPauta();
      final estados = await DatabaseService().obterEstados();
      _cabeceira = await DatabaseService().obterCabeceira();
      final hoxe = DateTime.now().toIso8601String().substring(0, 10);

      pautaSemanal = [];
      _ultimaAnalise = null;

      if (pautaBD.isNotEmpty) {
        pautaSemanal = pautaBD
            .map(
              (dia) => PautaToma(
                data: dia.data,
                dia: "${dia.diaSemanaTexto.substring(0, 3)} ${dia.dia}",
                dose: dia.eControl
                    ? "CTRL"
                    : (dia.dose == '0' ? "NON" : (dia.dose ?? "0")),
                estado:
                    estados[dia.data] == 'PENDENTE' &&
                        dia.data.compareTo(hoxe) < 0
                    ? 'NON_TOMADA'
                    : (estados[dia.data] ?? 'PENDENTE'),
                eControl: dia.eControl,
              ),
            )
            .toList();

        _ultimaAnalise = AnaliseModel(
          cabeceira: CabeceiraModel(farmaco: "Sintrom"),
          calendario: pautaBD,
          historico: [],
        );
      }
      if (novasTomasEsquecidas.isNotEmpty) {
        await P2PSyncService().notificarCoidador('TOMA_ESQUECIDA');
      }
    } catch (e) {
      debugPrint("Erro ao cargar datos da BD: $e");
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> confirmarTomaHoxe() async {
    final toma = tomaHoxe;
    if (toma == null || toma.eControl || toma.dose == 'NON') return;
    const storage = FlutterSecureStorage();
    final agora = DateTime.now();
    final horaConfigurada = await storage.read(key: 'hora_toma');
    var desviacion = 0;
    var foraDeHora = false;
    if (horaConfigurada != null) {
      final partes = horaConfigurada.split(':');
      if (partes.length == 2) {
        final prevista = DateTime(
          agora.year,
          agora.month,
          agora.day,
          int.tryParse(partes[0]) ?? 0,
          int.tryParse(partes[1]) ?? 0,
        );
        desviacion = agora.difference(prevista).inMinutes;
        foraDeHora = desviacion > 0;
      }
    }
    await DatabaseService().rexistrarToma(
      data: toma.data,
      instante: agora,
      desviacionMinutos: desviacion,
      foraDeHora: foraDeHora,
    );
    await cargarDatosHome();
    await P2PSyncService().notificarCoidador('TOMA_CONFIRMADA');
    final hora = horaConfigurada;
    if (hora != null) {
      await LocalNotificationService().cancelarEsquecementoHoxe(
        identificador: 'paciente_local',
      );
    }
  }

  Future<void> confirmarToma(String tokenCoidador, String payload) async {
    // Aquí podes usar o método enviarNotificacion que xa existe en ApiService
    bool ok = await P2PSyncService().enviarPayloadParaToken(
      tokenDestino: tokenCoidador,
      payload: payload,
      tipoAviso: "TOMA_CONFIRMADA",
    );

    if (ok) {
      debugPrint("Coidador notificado correctamente");
    }
    notifyListeners();
  }
}
