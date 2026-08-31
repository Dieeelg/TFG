import 'dart:async';

import 'package:flutter/material.dart'; // Estado da pantalla de inicio.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../modelos/pauta_toma.dart';
import '../modelos/analise.dart';
import '../modelos/cabeceira.dart';
import '../modelos/dose_dia.dart';
import '../servizos/servizo_api.dart';
import '../servizos/servizo_base_datos.dart';
import '../servizos/servizo_sincronizacion_p2p.dart';
import '../servizos/servizo_notificacions_locais.dart';

class InicioPacienteViewModel extends ChangeNotifier {
  final Future<String?> Function(String key) _ler;
  final Future<List<String>> Function() _pecharTomasVencidas;
  final Future<List<DoseDiaModel>> Function() _obterPauta;
  final Future<Map<String, String>> Function() _obterEstados;
  final Future<CabeceiraModel?> Function() _obterCabeceira;
  final Future<void> Function({
    required String data,
    required DateTime instante,
    required int desviacionMinutos,
    required bool foraDeHora,
  })
  _rexistrarToma;
  final Future<void> Function(String tipo) _notificarSupervisores;
  final Future<void> Function({required String identificador})
  _cancelarEsquecemento;
  final Future<bool> Function({
    required String tokenDestino,
    required String payload,
    required String tipoAviso,
  })
  _enviarPayload;
  final Future<Map<String, dynamic>> Function(String centro) _buscarCentro;
  final Stream<String> _actualizacions;
  final DateTime Function() _agora;

  InicioPacienteViewModel({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    ServizoBaseDatos? database,
    ServizoSincronizacionP2P? sincronizacion,
    ServizoNotificacionsLocais? notificacions,
    ServizoApi? api,
    DateTime Function()? agora,
  }) : this.conDependencias(
         ler: (key) => storage.read(key: key),
         pecharTomasVencidas:
             (database ?? ServizoBaseDatos()).pecharTomasVencidas,
         obterPauta: (database ?? ServizoBaseDatos()).obterPauta,
         obterEstados: (database ?? ServizoBaseDatos()).obterEstados,
         obterCabeceira: (database ?? ServizoBaseDatos()).obterCabeceira,
         rexistrarToma: (database ?? ServizoBaseDatos()).rexistrarToma,
         notificarSupervisores: (sincronizacion ?? ServizoSincronizacionP2P())
             .notificarSupervisores,
         cancelarEsquecemento: (notificacions ?? ServizoNotificacionsLocais())
             .cancelarEsquecementoHoxe,
         enviarPayload: (sincronizacion ?? ServizoSincronizacionP2P())
             .enviarPayloadParaToken,
         buscarCentro: (api ?? ServizoApi()).buscarCentro,
         actualizacions:
             (sincronizacion ?? ServizoSincronizacionP2P()).actualizacions,
         agora: agora,
       );

  InicioPacienteViewModel.conDependencias({
    required Future<String?> Function(String key) ler,
    required Future<List<String>> Function() pecharTomasVencidas,
    required Future<List<DoseDiaModel>> Function() obterPauta,
    required Future<Map<String, String>> Function() obterEstados,
    required Future<CabeceiraModel?> Function() obterCabeceira,
    required Future<void> Function({
      required String data,
      required DateTime instante,
      required int desviacionMinutos,
      required bool foraDeHora,
    })
    rexistrarToma,
    required Future<void> Function(String tipo) notificarSupervisores,
    required Future<void> Function({required String identificador})
    cancelarEsquecemento,
    required Future<bool> Function({
      required String tokenDestino,
      required String payload,
      required String tipoAviso,
    })
    enviarPayload,
    required Future<Map<String, dynamic>> Function(String centro) buscarCentro,
    required Stream<String> actualizacions,
    DateTime Function()? agora,
  }) : _ler = ler,
       _pecharTomasVencidas = pecharTomasVencidas,
       _obterPauta = obterPauta,
       _obterEstados = obterEstados,
       _obterCabeceira = obterCabeceira,
       _rexistrarToma = rexistrarToma,
       _notificarSupervisores = notificarSupervisores,
       _cancelarEsquecemento = cancelarEsquecemento,
       _enviarPayload = enviarPayload,
       _buscarCentro = buscarCentro,
       _actualizacions = actualizacions,
       _agora = agora ?? DateTime.now;

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
  PautaTomaModel? get tomaHoxe {
    if (pautaSemanal.isEmpty) return null;
    final hoxe = _agora().toIso8601String().substring(0, 10);
    return pautaSemanal.where((toma) => toma.data == hoxe).firstOrNull ??
        pautaSemanal.where((toma) => toma.data.compareTo(hoxe) > 0).firstOrNull;
  }

  List<PautaTomaModel> pautaSemanal = [];

  Future<void> iniciar() async {
    if (_iniciado) return;
    _iniciado = true;
    _programarPecheDoDia();
    _syncSubscription = _actualizacions.listen((evento) {
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
    final nome = await _ler('nome_usuario');
    final hora = await _ler('hora_toma');
    final modoSinxelo = await _ler('modo_sinxelo') == 'true';

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
      final novasTomasEsquecidas = await _pecharTomasVencidas();
      final pautaBD = await _obterPauta();
      final estados = await _obterEstados();
      _cabeceira = await _obterCabeceira();
      final hoxe = _agora().toIso8601String().substring(0, 10);

      pautaSemanal = [];
      _ultimaAnalise = null;

      if (pautaBD.isNotEmpty) {
        pautaSemanal = pautaBD
            .map(
              (dia) => PautaTomaModel(
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
        await _notificarSupervisores('TOMA_ESQUECIDA');
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
    final agora = _agora();
    final horaConfigurada = await _ler('hora_toma');
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
    await _rexistrarToma(
      data: toma.data,
      instante: agora,
      desviacionMinutos: desviacion,
      foraDeHora: foraDeHora,
    );
    await cargarDatosHome();
    await _notificarSupervisores('TOMA_CONFIRMADA');
    final hora = horaConfigurada;
    if (hora != null) {
      await _cancelarEsquecemento(identificador: 'paciente_local');
    }
  }

  Future<void> confirmarToma(String tokenSupervisor, String payload) async {
    // Aquí podes usar o método enviarNotificacion que xa existe en ServizoApi
    bool ok = await _enviarPayload(
      tokenDestino: tokenSupervisor,
      payload: payload,
      tipoAviso: "TOMA_CONFIRMADA",
    );

    if (ok) {
      debugPrint("Supervisor notificado correctamente");
    }
    notifyListeners();
  }

  Future<String> buscarTelefonoCentro(String centro) async {
    final info = await _buscarCentro(centro);
    final telefono = info['telefono'] as String?;
    if (telefono == null || telefono.trim().isEmpty) {
      throw Exception('O centro non ten un teléfono dispoñible');
    }
    return telefono.trim();
  }

  void _programarPecheDoDia() {
    _pecheDiaTimer?.cancel();
    final agora = _agora();
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
