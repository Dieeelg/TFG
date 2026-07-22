import 'package:flutter/material.dart'; // Axustes do coidador.
import '../servizos/servizo_base_datos.dart';
import '../servizos/servizo_sincronizacion_p2p.dart';

class AxustesCoidadorScreen extends StatefulWidget {
  const AxustesCoidadorScreen({super.key});

  @override
  State<AxustesCoidadorScreen> createState() => _AxustesCoidadorScreenState();
}

class _AxustesCoidadorScreenState extends State<AxustesCoidadorScreen> {
  List<Map<String, dynamic>> _pacientes = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final pacientes = await DatabaseService().obterPacientesCoidador();
    if (mounted) setState(() { _pacientes = pacientes; _cargando = false; });
  }

  Future<void> _eliminar(Map<String, dynamic> paciente, int indice) async {
    final datos = paciente['datos'] as Map<String, dynamic>;
    final nome = (datos['nome'] as String?)?.trim();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar paciente?'),
        content: Text('Deixarás de supervisar a ${nome?.isNotEmpty == true ? nome : 'Persoa ${indice + 1}'}. Tamén se cancelarán os seus avisos neste dispositivo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await P2PSyncService().desvincularPaciente(
        uid: paciente['uid'] as String,
        tokenPaciente: paciente['token'] as String,
      );
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(title: const Text('Axustes do coidador', style: TextStyle(fontWeight: FontWeight.bold))),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('Pacientes vinculados', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_pacientes.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('Non hai pacientes vinculados.', style: TextStyle(fontSize: 17)))),
                  for (var i = 0; i < _pacientes.length; i++)
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(
                          ((_pacientes[i]['datos'] as Map<String, dynamic>)['nome'] as String?)?.trim().isNotEmpty == true
                              ? ((_pacientes[i]['datos'] as Map<String, dynamic>)['nome'] as String)
                              : 'Persoa ${i + 1}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        trailing: IconButton(
                          tooltip: 'Quitar paciente',
                          onPressed: () => _eliminar(_pacientes[i], i),
                          icon: const Icon(Icons.person_remove_outlined, color: Colors.red, size: 30),
                        ),
                      ),
                    ),
                ],
              ),
      );
}
