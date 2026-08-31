import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Importación dos ViewModels
import 'modelos_vista/autenticacion/configuracion_inicial.dart';
import 'modelos_vista/autenticacion/configuracion_adicional.dart';
import 'modelos_vista/autenticacion/vinculacion_paciente.dart';
import 'modelos_vista/autenticacion/vinculacion_supervisor.dart';
import 'modelos_vista/inicio_paciente.dart';
import 'modelos_vista/configuracion_paciente_supervisado.dart';

//Importación das views
import 'views/inicio_paciente.dart';
import 'views/autenticacion/configuracion_inicial.dart';
import 'views/autenticacion/vinculacion_supervisor.dart';
import 'views/autenticacion/vinculacion_paciente.dart';
import 'views/autenticacion/configuracion_adicional.dart';
import 'views/inicio_supervisor.dart';
import 'views/camara/captura_informe.dart';
import 'servizos/inicializador_aplicacion.dart';
import 'servizos/servizo_sincronizacion_p2p.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await ServizoSincronizacionP2P().procesarMensaxe(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final inicializacion = await InicializadorAplicacion().inicializar(
    backgroundHandler: _firebaseMessagingBackgroundHandler,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConfiguracionInicialViewModel()),
        ChangeNotifierProvider(
          create: (_) => ConfiguracionAdicionalViewModel(),
        ),
        ChangeNotifierProvider(create: (_) => VinculacionPacienteViewModel()),
        ChangeNotifierProvider(create: (_) => VinculacionSupervisorViewModel()),
        ChangeNotifierProvider(create: (_) => InicioPacienteViewModel()),
        ChangeNotifierProvider(
          create: (_) => ConfiguracionPacienteSupervisadoViewModel(),
        ),
      ],
      child: SintromApp(
        xaConfigurado: inicializacion.xaConfigurado,
        rolUsuario: inicializacion.rolUsuario,
      ),
    ),
  );
}

class SintromApp extends StatelessWidget {
  final bool xaConfigurado;
  final String? rolUsuario;
  const SintromApp({
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
          ? (rolUsuario == 'SUPERVISOR' ? '/supervisor' : '/paciente')
          : '/',
      routes: {
        '/': (context) => const ConfiguracionInicialScreen(),
        '/vincular_supervisor': (context) =>
            const VinculacionSupervisorScreen(),
        '/vincular_paciente': (context) => const VinculacionPacienteScreen(),
        '/configuracion_adicional': (context) =>
            const ConfiguracionAdicionalScreen(),
        '/paciente': (context) => const InicioPacienteScreen(),
        '/supervisor': (context) => const InicioSupervisorScreen(),
        '/captura': (context) => const CapturaInformeScreen(),
      },
    );
  }
}
