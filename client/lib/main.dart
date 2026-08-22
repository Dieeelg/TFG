import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Importación dos ViewModels
import 'modelos_vista/autenticacion/configuracion_inicial.dart';
import 'modelos_vista/autenticacion/configuracion_adicional.dart';
import 'modelos_vista/autenticacion/vinculacion_paciente.dart';
import 'modelos_vista/autenticacion/vinculacion_coidador.dart';
import 'modelos_vista/inicio.dart';
import 'modelos_vista/configuracion_paciente_supervisado.dart';

//Importación das views
import 'views/inicio_paciente.dart';
import 'views/autenticacion/configuracion_inicial.dart';
import 'views/autenticacion/vinculacion_coidador.dart';
import 'views/autenticacion/vinculacion_paciente.dart';
import 'views/autenticacion/configuracion_adicional.dart';
import 'views/inicio_coidador.dart';
import 'views/camara/captura_informe.dart';
import 'servizos/inicializador_aplicacion.dart';
import 'servizos/servizo_sincronizacion_p2p.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await P2PSyncService().procesarMensaxe(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final inicializacion = await InicializadorAplicacion().inicializar(
    backgroundHandler: _firebaseMessagingBackgroundHandler,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SetupViewModel()),
        ChangeNotifierProvider(create: (_) => AdditionalSettingsViewModel()),
        ChangeNotifierProvider(create: (_) => VinculacionPacienteViewModel()),
        ChangeNotifierProvider(create: (_) => VinculacionCoidadorViewModel()),
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(
          create: (_) => CaregiverPatientSettingsViewModel(),
        ),
      ],
      child: MyApp(
        xaConfigurado: inicializacion.xaConfigurado,
        rolUsuario: inicializacion.rolUsuario,
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
