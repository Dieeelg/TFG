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
  const InicializadorAplicacion();

  Future<ResultadoInicializacion> inicializar({
    required Future<void> Function(RemoteMessage) backgroundHandler,
  }) async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(backgroundHandler);
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await LocalNotificationService().inicializar();
    FirebaseMessaging.onMessage.listen(P2PSyncService().procesarMensaxe);

    const storage = FlutterSecureStorage();
    final configuracionFinalizada = await storage.read(
      key: 'configuracion_finalizada',
    );
    final rolUsuario = await storage.read(key: 'rol_usuario');

    if (configuracionFinalizada != null && rolUsuario == 'PACIENTE') {
      await _restaurarRecordatoriosPaciente(storage);
    }

    return ResultadoInicializacion(
      xaConfigurado: configuracionFinalizada != null,
      rolUsuario: rolUsuario,
    );
  }

  Future<void> _restaurarRecordatoriosPaciente(
    FlutterSecureStorage storage,
  ) async {
    final hora = await storage.read(key: 'hora_toma');
    if (hora == null) return;

    final nome = await storage.read(key: 'nome_usuario') ?? '';
    await LocalNotificationService().programarTomasPaciente(
      nome: nome,
      hora: hora,
    );

    final hoxe = DateTime.now().toIso8601String().substring(0, 10);
    final estados = await DatabaseService().obterEstados();
    if (estados[hoxe] == 'TOMADA' || estados[hoxe] == 'TOMADA_FORA_HORA') {
      await LocalNotificationService().cancelarEsquecementoHoxe(
        identificador: 'paciente_local',
      );
    }
  }
}
