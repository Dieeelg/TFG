import 'package:flutter/material.dart'; // Configuración remota do paciente.
import '../servizos/servizo_sincronizacion_p2p.dart';

class CaregiverPatientSettingsScreen extends StatefulWidget {
  final String tokenPaciente;
  final String nomeInicial;
  const CaregiverPatientSettingsScreen({super.key, required this.tokenPaciente, required this.nomeInicial});
  @override
  State<CaregiverPatientSettingsScreen> createState() => _CaregiverPatientSettingsScreenState();
}

class _CaregiverPatientSettingsScreenState extends State<CaregiverPatientSettingsScreen> {
  late final TextEditingController _nome = TextEditingController(text: widget.nomeInicial);
  TimeOfDay _hora = const TimeOfDay(hour: 20, minute: 0);
  bool _enviando = false;

  @override
  void dispose() { _nome.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Configuración do paciente')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Complete estes datos para personalizar o seguimento.', style: TextStyle(fontSize: 18)),
      const SizedBox(height: 24),
      TextField(controller: _nome, decoration: const InputDecoration(labelText: 'Nome', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder())),
      const SizedBox(height: 20),
      ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), tileColor: const Color(0xFFE7F4FF),
        leading: const Icon(Icons.schedule, color: Colors.blue, size: 34),
        title: const Text('Hora habitual da toma'),
        subtitle: Text(_hora.format(context), style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold, color: Colors.blue)),
        onTap: () async { final h = await showTimePicker(context: context, initialTime: _hora); if (h != null && mounted) setState(() => _hora = h); },
      ),
      const SizedBox(height: 28),
      ElevatedButton(
        onPressed: _enviando ? null : () async {
          setState(() => _enviando = true);
          final hora = '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}';
          await P2PSyncService().enviarConfiguracionPaciente(tokenPaciente: widget.tokenPaciente, nome: _nome.text.trim(), horaToma: hora);
          if (!context.mounted) return;
          Navigator.pop(context, true);
        },
        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56), backgroundColor: const Color(0xFF333333), foregroundColor: Colors.white),
        child: const Text('Gardar e enviar', style: TextStyle(fontSize: 18)),
      ),
    ]),
  );
}
