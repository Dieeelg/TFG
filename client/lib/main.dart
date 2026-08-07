import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Importación dos ViewModels
import 'modelos_vista/autenticacion/configuracion_inicial.dart';
import 'modelos_vista/autenticacion/vinculacion_paciente.dart';
import 'modelos_vista/autenticacion/vinculacion_coidador.dart';
import 'modelos_vista/inicio.dart';

//Importación das views
import 'views/inicio_paciente.dart';
import 'views/autenticacion/configuracion_inicial.dart';
import 'views/autenticacion/vinculacion_coidador.dart';
import 'views/autenticacion/vinculacion_paciente.dart';
import 'views/autenticacion/configuracion_adicional.dart';
import 'views/inicio_coidador.dart';
import 'views/camara/captura_informe.dart';
import 'servizos/servizo_sincronizacion_p2p.dart';
import 'servizos/servizo_notificacions_locais.dart';
import 'servizos/servizo_base_datos.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await P2PSyncService().procesarMensaxe(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); //Inicia a conexión con Firebase
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  await LocalNotificationService().inicializar();
  await _configurarEscoitaVinculacion(); //Iniciamos a función para escoitar as notificacións de vinculación
  //TODO: Revisar se ten sentizo iniciar

  const storage = FlutterSecureStorage();
  String? configuracionFinalizada = await storage.read(
    key: 'configuracion_finalizada',
  );
  String? rolUsuario = await storage.read(key: 'rol_usuario');
  if (configuracionFinalizada != null && rolUsuario == 'PACIENTE') {
    final hora = await storage.read(key: 'hora_toma');
    final nome = await storage.read(key: 'nome_usuario') ?? '';
    if (hora != null) {
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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SetupViewModel()),
        ChangeNotifierProvider(create: (_) => VinculacionPacienteViewModel()),
        ChangeNotifierProvider(create: (_) => VinculacionCoidadorViewModel()),
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
      ],
      child: MyApp(
        xaConfigurado: configuracionFinalizada != null,
        rolUsuario: rolUsuario,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool xaConfigurado;
  final String? rolUsuario;
  const MyApp({
    super.key,
    required this.xaConfigurado,
    required this.rolUsuario,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SintromApp',
      debugShowCheckedModeBanner: false, // Quita a banda  de Debug
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),

      // Se o setup non rematou, sempre comeza na primeira pantalla.
      initialRoute: xaConfigurado
          ? (rolUsuario == 'COIDADOR' ? '/coidador' : '/home')
          : '/',
      routes: {
        '/': (context) => const SetupScreen(),
        '/vincular_coidador': (context) => const VincularCoidadorScreen(),
        '/vincular_paciente': (context) => const VinculacionScreen(),
        '/configuracion_adicional': (context) =>
            const AdditionalSettingsScreen(),
        '/home': (context) => const PacienteHomeScreen(),
        '/coidador': (context) => const CaregiverHomeScreen(),
        '/captura': (context) => const CapturaInformeScreen(),
      },
    );
  }
}

Future<void> _configurarEscoitaVinculacion() async {
  FirebaseMessaging.onMessage.listen(P2PSyncService().procesarMensaxe);
}
