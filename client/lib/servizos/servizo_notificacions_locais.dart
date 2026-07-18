import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Avisos locais.
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

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
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    _inicializado = true;
  }

  int _baseId(String identificador) => identificador.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x3fffffff) % 100000 * 10;

  Future<void> programarTomas({
    required String identificador,
    required String nome,
    required String hora,
    int marxeEsquecementoMinutos = 30,
    bool desdeManha = false,
  }) async {
    await inicializar();
    final partes = hora.split(':');
    if (partes.length != 2) return;
    final h = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    if (h == null || m == null) return;
    final base = _baseId(identificador);
    await _plugin.cancel(id: base);
    await _plugin.cancel(id: base + 1);
    final agora = tz.TZDateTime.now(tz.local);
    final dataBase = desdeManha ? agora.add(const Duration(days: 1)) : agora;
    var toma = tz.TZDateTime(tz.local, dataBase.year, dataBase.month, dataBase.day, h, m);
    if (!toma.isAfter(agora)) toma = toma.add(const Duration(days: 1));
    final esquecemento = toma.add(Duration(minutes: marxeEsquecementoMinutos));
    await _plugin.zonedSchedule(
      id: base,
      title: 'Hora da toma',
      body: nome.isEmpty ? 'É hora de tomar a medicación.' : '$nome: é hora de tomar a medicación.',
      scheduledDate: toma,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'toma:$identificador',
    );
    await _plugin.zonedSchedule(
      id: base + 1,
      title: 'Toma sen confirmar',
      body: nome.isEmpty ? 'A toma segue pendente de confirmar.' : 'A toma de $nome segue pendente de confirmar.',
      scheduledDate: esquecemento,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'esquecemento:$identificador',
    );
  }

  Future<void> cancelarEsquecementoHoxe({
    required String identificador,
    required String nome,
    required String hora,
  }) async {
    await inicializar();
    await _plugin.cancel(id: _baseId(identificador) + 1);
    // Reprograma a serie desde mañá para non perder os avisos dos días seguintes.
    await programarTomas(
      identificador: identificador,
      nome: nome,
      hora: hora,
      desdeManha: true,
    );
  }

  Future<void> cancelarTomas(String identificador) async {
    await inicializar();
    final base = _baseId(identificador);
    await _plugin.cancel(id: base);
    await _plugin.cancel(id: base + 1);
  }
}
