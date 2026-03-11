import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth/setup_escanear_viewmodel.dart';

class SetupEscanearScreen extends StatelessWidget {
  const SetupEscanearScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SetupEscanearViewModel>();

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
                'Rexistro de pautas',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Quen vai escanear os informes do médico?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Color(0xFF34495E)),
              ),
              const SizedBox(height: 40),

              // Opción: Escanear eu mesmo
              _buildOptionCard(
                title: 'Escanear eu mesmo',
                subtitle: 'Eu farei as fotos ás follas de Sintrom cando vaia ao centro.',
                icon: Icons.image_outlined,
                onTap: () async {
                  await vm.seleccionarPreferencia(true);
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/home'); // Á home final
                  }
                },
              ),

              const SizedBox(height: 20),

              // Opción: Farao outra persoa
              _buildOptionCard(
                title: 'Farao outra persoa',
                subtitle: 'Unha persoa de confianza subirá a información por min.',
                icon: Icons.file_upload_outlined,
                onTap: () async {
                  await vm.seleccionarPreferencia(false);
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/home');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 20.0),
          child: Column(
            children: [
              Icon(icon, size: 48, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF34495E)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}