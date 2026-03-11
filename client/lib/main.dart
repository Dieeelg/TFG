import 'package:flutter/material.dart';
import 'package:tfg_sintrom/views/auth/setup_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App de Diego',
      debugShowCheckedModeBanner: false, // Quita a banda vermella de "Debug"
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), // Podes cambialo a azul para que vaia coas túas tarxetas
        useMaterial3: true,
      ),
      home: const SetupScreen(),
    );
  }
}