import 'package:flutter/material.dart'; // Configuración remota do paciente.
import 'package:provider/provider.dart';
import '../modelos_vista/configuracion_paciente_supervisado.dart';

class ConfiguracionPacienteSupervisadoScreen extends StatefulWidget {
  final String tokenPaciente;
  final String nomeInicial;
  const ConfiguracionPacienteSupervisadoScreen({
    super.key,
    required this.tokenPaciente,
    required this.nomeInicial,
  });
  @override
  State<ConfiguracionPacienteSupervisadoScreen> createState() =>
      _ConfiguracionPacienteSupervisadoScreenState();
}

class _ConfiguracionPacienteSupervisadoScreenState
    extends State<ConfiguracionPacienteSupervisadoScreen> {
  late final TextEditingController _nome = TextEditingController(
    text: widget.nomeInicial,
  );
  TimeOfDay _hora = const TimeOfDay(hour: 20, minute: 0);

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ConfiguracionPacienteSupervisadoViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración do paciente')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Complete estes datos para personalizar o seguimento.',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nome,
            decoration: const InputDecoration(
              labelText: 'Nome',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            tileColor: const Color(0xFFE7F4FF),
            leading: const Icon(Icons.schedule, color: Colors.blue, size: 34),
            title: const Text('Hora habitual da toma'),
            subtitle: Text(
              _hora.format(context),
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            onTap: () async {
              final h = await showTimePicker(
                context: context,
                initialTime: _hora,
              );
              if (h != null && mounted) setState(() => _hora = h);
            },
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: vm.enviando
                ? null
                : () async {
                    final hora =
                        '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}';
                    final gardado = await vm.gardar(
                      tokenPaciente: widget.tokenPaciente,
                      nome: _nome.text,
                      hora: hora,
                    );
                    if (!context.mounted) return;
                    if (gardado) {
                      Navigator.pop(context, true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(vm.erro ?? 'Non se puido enviar'),
                        ),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: const Color(0xFF333333),
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Gardar e enviar',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}
