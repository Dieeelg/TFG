import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Avisos locais.
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'servizo_base_datos.dart';
import 'planificador_recordatorios.dart';

class ServizoNotificacionsLocais {
  static final ServizoNotificacionsLocais _instance =
      ServizoNotificacionsLocais._internal();
  factory ServizoNotificacionsLocais() => _instance;
  ServizoNotificacionsLocais._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inicializado = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'recordatorios_toma_alarma_v2',
      'Alarmas da toma',
      channelDescription: 'Avisos da hora da toma e tomas sen confirmar',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> inicializar() async {
    if (_inicializado) return;
    tz_data.initializeTimeZones();
    try {
      final zona = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zona.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Madrid'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    _inicializado = true;
  }

  int _baseId(String identificador) =>
      identificador.codeUnits.fold<int>(
        0,
        (a, b) => (a * 31 + b) & 0x3fffffff,
      ) %
      100000 *
      10;

  int _idData(String identificador, String data, TipoRecordatorioToma tipo) {
    final valor = '$identificador|$data|${tipo.name}';
    return valor.codeUnits.fold<int>(
      0,
      (anterior, actual) => (anterior * 31 + actual) & 0x7fffffff,
    );
  }

  Future<void> programarTomasPaciente({
    required String nome,
    required String hora,
  }) async {
    final pauta = await ServizoBaseDatos().obterPauta();
    final estados = await ServizoBaseDatos().obterEstados();
    await programarTomas(
      identificador: 'paciente_local',
      nome: nome,
      hora: hora,
      datasConToma: pauta
          .where(
            (dia) =>
                !dia.eControl &&
                PlanificadorRecordatorios.eDoseTomable(dia.dose),
          )
          .map((dia) => dia.data),
      estados: estados,
    );
  }

  Future<void> programarTomas({
    required String identificador,
    required String nome,
    required String hora,
    required Iterable<String> datasConToma,
    Map<String, String> estados = const {},
    int marxeEsquecementoMinutos = 30,
  }) async {
    await inicializar();
    await cancelarTomas(identificador);
    final agora = DateTime.now();
    final recordatorios = PlanificadorRecordatorios.crear(
      agora: agora,
      hora: hora,
      datasConToma: datasConToma,
      estados: estados,
      marxeEsquecementoMinutos: marxeEsquecementoMinutos,
    );
    for (final recordatorio in recordatorios) {
      final eToma = recordatorio.tipo == TipoRecordatorioToma.toma;
      final instante = recordatorio.instante;
      await _plugin.zonedSchedule(
        id: _idData(identificador, recordatorio.data, recordatorio.tipo),
        title: eToma ? 'Hora da toma' : 'Toma sen confirmar',
        body: eToma
            ? (nome.isEmpty
                  ? 'É hora de tomar a medicación.'
                  : '$nome: é hora de tomar a medicación.')
            : (nome.isEmpty
                  ? 'A toma segue pendente de confirmar.'
                  : 'A toma de $nome segue pendente de confirmar.'),
        scheduledDate: tz.TZDateTime(
          tz.local,
          instante.year,
          instante.month,
          instante.day,
          instante.hour,
          instante.minute,
        ),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: eToma
            ? 'toma:$identificador:${recordatorio.data}'
            : 'esquecemento:$identificador:${recordatorio.data}',
      );
    }
  }

  Future<void> cancelarEsquecementoHoxe({required String identificador}) async {
    await inicializar();
    final agora = DateTime.now();
    final hoxe =
        '${agora.year.toString().padLeft(4, '0')}-'
        '${agora.month.toString().padLeft(2, '0')}-'
        '${agora.day.toString().padLeft(2, '0')}';
    await _plugin.cancel(
      id: _idData(identificador, hoxe, TipoRecordatorioToma.esquecemento),
    );
  }

  Future<void> cancelarTomas(String identificador) async {
    await inicializar();
    final base = _baseId(identificador);
    await _plugin.cancel(id: base);
    await _plugin.cancel(id: base + 1);
    final pendentes = await _plugin.pendingNotificationRequests();
    for (final peticion in pendentes) {
      final payload = peticion.payload;
      if (payload?.startsWith('toma:$identificador:') == true ||
          payload?.startsWith('esquecemento:$identificador:') == true) {
        await _plugin.cancel(id: peticion.id);
      }
    }
  }
}
