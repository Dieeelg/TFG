import 'dart:async';

import 'package:flutter/material.dart'; // Estado da pantalla de inicio.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../modelos/pauta_toma.dart';
import '../modelos/analise.dart';
import '../modelos/cabeceira.dart';
import '../servizos/servizo_api.dart';
import '../servizos/servizo_base_datos.dart';
import '../servizos/servizo_sincronizacion_p2p.dart';
import '../servizos/servizo_notificacions_locais.dart';

class HomeViewModel extends ChangeNotifier {
  bool _cargando = false;
  bool _preferenciasCargadas = false;
  bool _modoSinxelo = false;
  String? _nomeUsuario;
  String _horaToma = '20:00';
  AnaliseModel? _ultimaAnalise;
  CabeceiraModel? _cabeceira;
  StreamSubscription<String>? _syncSubscription;
  Timer? _pecheDiaTimer;
  bool _iniciado = false;

  bool get cargando => _cargando;
  bool get preferenciasCargadas => _preferenciasCargadas;
  bool get modoSinxelo => _modoSinxelo;
  String? get nomeUsuario => _nomeUsuario;
  String get horaToma => _horaToma;
  CabeceiraModel? get cabeceira => _cabeceira;
  PautaToma? get tomaHoxe {
    if (pautaSemanal.isEmpty) return null;
    final hoxe = DateTime.now().toIso8601String().substring(0, 10);
    return pautaSemanal.where((toma) => toma.data == hoxe).firstOrNull ??
        pautaSemanal.where((toma) => toma.data.compareTo(hoxe) > 0).firstOrNull;
  }

  List<PautaToma> pautaSemanal = [];

  Future<void> iniciar() async {
    if (_iniciado) return;
    _iniciado = true;
    _programarPecheDoDia();
    _syncSubscription = P2PSyncService().actualizacions.listen((evento) {
      if (evento == 'paciente_local') {
        cargarPreferencias();
        cargarDatosHome();
      }
    });
    await Future.wait([cargarPreferencias(), cargarDatosHome()]);
  }

  Future<void> reactivar() async {
    await Future.wait([cargarPreferencias(), cargarDatosHome()]);
  }

  Future<void> cargarPreferencias() async {
    const storage = FlutterSecureStorage();
    final nome = await storage.read(key: 'nome_usuario');
    final hora = await storage.read(key: 'hora_toma');
    final modoSinxelo = await storage.read(key: 'modo_sinxelo') == 'true';

    _nomeUsuario = nome?.trim().isEmpty == true ? null : nome?.trim();
    _horaToma = hora ?? '20:00';
    _modoSinxelo = modoSinxelo;
    _preferenciasCargadas = true;
    notifyListeners();
  }

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

  Future<String> buscarTelefonoCentro(String centro) async {
    final info = await ApiService().buscarCentro(centro);
    final telefono = info['telefono'] as String?;
    if (telefono == null || telefono.trim().isEmpty) {
      throw Exception('O centro non ten un telÃ©fono dispoÃ±ible');
    }
    return telefono.trim();
  }

  void _programarPecheDoDia() {
    _pecheDiaTimer?.cancel();
    final agora = DateTime.now();
    final medianoite = DateTime(agora.year, agora.month, agora.day + 1);
    _pecheDiaTimer = Timer(
      medianoite.difference(agora) + const Duration(seconds: 1),
      () {
        cargarDatosHome();
        _programarPecheDoDia();
      },
    );
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _pecheDiaTimer?.cancel();
    super.dispose();
  }
}
