import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'servizo_base_datos.dart';
import 'servizo_notificacions_locais.dart';
import 'servizo_sincronizacion_p2p.dart';

class ResultadoInicializacion {
  const ResultadoInicializacion({
    required this.xaConfigurado,
    required this.rolUsuario,
  });

  final bool xaConfigurado;
  final String? rolUsuario;
}

class InicializadorAplicacion {
  InicializadorAplicacion({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    LocalNotificationService? notificacions,
    P2PSyncService? sincronizacion,
    DatabaseService? database,
    DateTime Function()? agora,
  }) : this.conDependencias(
         inicializarFirebase: () async {
           await Firebase.initializeApp();
         },
         rexistrarBackground: FirebaseMessaging.onBackgroundMessage,
         solicitarPermisos: () async {
           await FirebaseMessaging.instance.requestPermission(
             alert: true,
             badge: true,
             sound: true,
           );
         },
         inicializarNotificacions:
             (notificacions ?? LocalNotificationService()).inicializar,
         escoitarMensaxes: (handler) {
           FirebaseMessaging.onMessage.listen(handler);
         },
         procesarMensaxe: (sincronizacion ?? P2PSyncService()).procesarMensaxe,
         ler: (key) => storage.read(key: key),
         programarTomas: (notificacions ?? LocalNotificationService())
             .programarTomasPaciente,
         obterEstados: (database ?? DatabaseService()).obterEstados,
         cancelarEsquecemento: (notificacions ?? LocalNotificationService())
             .cancelarEsquecementoHoxe,
         agora: agora,
       );

  InicializadorAplicacion.conDependencias({
    required Future<void> Function() inicializarFirebase,
    required void Function(Future<void> Function(RemoteMessage))
    rexistrarBackground,
    required Future<void> Function() solicitarPermisos,
    required Future<void> Function() inicializarNotificacions,
    required void Function(Future<void> Function(RemoteMessage))
    escoitarMensaxes,
    required Future<void> Function(RemoteMessage) procesarMensaxe,
    required Future<String?> Function(String key) ler,
    required Future<void> Function({required String nome, required String hora})
    programarTomas,
    required Future<Map<String, String>> Function() obterEstados,
    required Future<void> Function({required String identificador})
    cancelarEsquecemento,
    DateTime Function()? agora,
  }) : _inicializarFirebase = inicializarFirebase,
       _rexistrarBackground = rexistrarBackground,
       _solicitarPermisos = solicitarPermisos,
       _inicializarNotificacions = inicializarNotificacions,
       _escoitarMensaxes = escoitarMensaxes,
       _procesarMensaxe = procesarMensaxe,
       _ler = ler,
       _programarTomas = programarTomas,
       _obterEstados = obterEstados,
       _cancelarEsquecemento = cancelarEsquecemento,
       _agora = agora ?? DateTime.now;

  final Future<void> Function() _inicializarFirebase;
  final void Function(Future<void> Function(RemoteMessage))
  _rexistrarBackground;
  final Future<void> Function() _solicitarPermisos;
  final Future<void> Function() _inicializarNotificacions;
  final void Function(Future<void> Function(RemoteMessage)) _escoitarMensaxes;
  final Future<void> Function(RemoteMessage) _procesarMensaxe;
  final Future<String?> Function(String key) _ler;
  final Future<void> Function({required String nome, required String hora})
  _programarTomas;
  final Future<Map<String, String>> Function() _obterEstados;
  final Future<void> Function({required String identificador})
  _cancelarEsquecemento;
  final DateTime Function() _agora;

  Future<ResultadoInicializacion> inicializar({
    required Future<void> Function(RemoteMessage) backgroundHandler,
  }) async {
    await _inicializarFirebase();
    _rexistrarBackground(backgroundHandler);
    await _solicitarPermisos();
    await _inicializarNotificacions();
    _escoitarMensaxes(_procesarMensaxe);

    final configuracionFinalizada = await _ler('configuracion_finalizada');
    final rolUsuario = await _ler('rol_usuario');

    if (configuracionFinalizada != null && rolUsuario == 'PACIENTE') {
      await _restaurarRecordatoriosPaciente();
    }

    return ResultadoInicializacion(
      xaConfigurado: configuracionFinalizada != null,
      rolUsuario: rolUsuario,
    );
  }

  Future<void> _restaurarRecordatoriosPaciente() async {
    final hora = await _ler('hora_toma');
    if (hora == null) return;

    final nome = await _ler('nome_usuario') ?? '';
    await _programarTomas(nome: nome, hora: hora);

    final hoxe = _agora().toIso8601String().substring(0, 10);
    final estados = await _obterEstados();
    if (estados[hoxe] == 'TOMADA' || estados[hoxe] == 'TOMADA_FORA_HORA') {
      await _cancelarEsquecemento(identificador: 'paciente_local');
    }
  }
}
