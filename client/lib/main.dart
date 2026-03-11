import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tfg_sintrom/viewmodels/auth/setup_escanear_viewmodel.dart';
import 'package:tfg_sintrom/viewmodels/auth/vinculacion_coidador_viewmodel.dart';
import 'package:tfg_sintrom/views/auth/setup_scanear_screen.dart';
import 'package:tfg_sintrom/views/auth/setup_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tfg_sintrom/views/auth/vinculacion_coidador_screen.dart';
import 'package:tfg_sintrom/views/auth/vinculacion_paciente_screen.dart';


// Importación dos ViewModels
import 'viewmodels/auth/setup_viewmodel.dart';
import 'viewmodels/auth/vinculacion_paciente_viewmodel.dart';




void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _configurarEscoitaVinculacion();

  const storage = FlutterSecureStorage();
  String? configuracionFinalizada = await storage.read(key: 'quene_escanea');

  runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SetupViewModel()),
          ChangeNotifierProvider(create: (_) => VinculacionPacienteViewModel()),
          ChangeNotifierProvider(create: (_) => VinculacionCoidadorViewModel()),
          ChangeNotifierProvider(create: (_) => SetupEscanearViewModel()),
        ],
        child: MyApp(xaConfigurado: configuracionFinalizada != null),
      ),
  );
}

class MyApp extends StatelessWidget {
  final bool xaConfigurado;
  const MyApp({super.key, required this.xaConfigurado});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SintromApp',
      debugShowCheckedModeBanner: false, // Quita a banda  de Debug
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: xaConfigurado ? '/home' : '/',
      routes: {
        '/': (context) => const SetupScreen(),
        '/setup_escanear': (context) => const SetupEscanearScreen(),
        '/vincular_coidador': (context) => const VincularCoidadorScreen(),
        '/vincular_paciente': (context) => const VinculacionScreen(),


        //'/home': (context) => const PacienteHomeScreen(),

      },
    );
  }
}

Future<void> _configurarEscoitaVinculacion() async {
  const storage = FlutterSecureStorage();

  // Escoitar mensaxes coa App aberta
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    if (message.data['tipo_aviso'] == 'VINCULACION_INICIAL') {
      String tokenCoidador = message.data['payload'];

      await storage.write(key: 'token_coidador', value: tokenCoidador);
      print("Vinculación P2P: Token do coidador gardado localmente.");
    }
  });
}