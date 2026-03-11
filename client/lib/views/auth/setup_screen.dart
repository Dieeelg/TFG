import 'package:flutter/material.dart';
import '../../core/constants.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              const Text(
                'Benvido',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Quen vai usar a aplicación?',
                style: TextStyle(fontSize: 18, color: Color(0xFF34495E)),
              ),
              const SizedBox(height: 40),

              _buildOptionCard(
                context,
                title: 'Para min',
                subtitle: 'Vou xestionar o meu propio tratamento.',
                icon: Icons.person_outline,
                onTap: () {
                  // Navegar á seguinte pantalla de rexistro/login para o paciente
                  print("Seleccionado: Para min");
                },
              ),

              const SizedBox(height: 20),

              // Tarxeta "Para outra persoa"
              _buildOptionCard(
                context,
                title: 'Para outra persoa',
                subtitle: 'Vou axudar a outra persoa co seu tratamento.',
                icon: Icons.people_outline,
                onTap: () {
                  // Navegar á seguinte pantalla para o coidador
                  print("Seleccionado: Para outra persoa");
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(BuildContext context,
      {required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 40.0, horizontal: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 64, color: Colors.blue),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16,
                        color: Color(0xFF34495E)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}