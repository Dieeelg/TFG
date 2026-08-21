import 'package:flutter/material.dart'; // Inicio da configuración.
import 'package:provider/provider.dart';
import '../../modelos_vista/autenticacion/configuracion_inicial.dart';
import 'vinculacion_paciente.dart';
import 'vinculacion_coidador.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  Future<void> _manexarSeleccion(BuildContext context, bool esPaciente) async {
    final vm = context.read<SetupViewModel>();

    final resultado = await vm.autenticar(esPaciente: esPaciente);

    if (!context.mounted) return;

    if (resultado == AuthResult.exito) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => esPaciente
              ? const VinculacionScreen()
              : const VincularCoidadorScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro ao conectar con Firebase")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final setupVM = context.watch<SetupViewModel>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
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
                  title: 'Para min',
                  subtitle: 'Vou xestionar o meu propio tratamento.',
                  icon: Icons.person_outline,
                  estaCargando: setupVM.estaCargando,
                  onTap: () => _manexarSeleccion(context, true),
                ),

                const SizedBox(height: 20),

                _buildOptionCard(
                  title: 'Para outra persoa',
                  subtitle: 'Vou axudar a outra persoa co seu tratamento.',
                  icon: Icons.people_outline,
                  estaCargando: setupVM.estaCargando,
                  onTap: () => _manexarSeleccion(context, false),
                ),
              ],
            ),
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
    bool estaCargando = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Opacity(
        opacity: estaCargando ? 0.6 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: estaCargando ? null : onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 40.0,
                  horizontal: 24.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (estaCargando)
                      const CircularProgressIndicator()
                    else
                      Icon(icon, size: 64, color: Colors.blue),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF34495E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
