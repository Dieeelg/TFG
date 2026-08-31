import 'package:flutter/material.dart'; // Axustes do supervisor.
import 'package:provider/provider.dart';
import '../modelos_vista/axustes_supervisor.dart';

class AxustesSupervisorScreen extends StatelessWidget {
  const AxustesSupervisorScreen({super.key, this.viewModel});

  final AxustesSupervisorViewModel? viewModel;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => viewModel ?? (AxustesSupervisorViewModel()..cargar()),
    child: const _AxustesSupervisorView(),
  );
}

class _AxustesSupervisorView extends StatelessWidget {
  const _AxustesSupervisorView();

  Future<void> _eliminar(
    BuildContext context,
    Map<String, dynamic> paciente,
    int indice,
  ) async {
    final vm = context.read<AxustesSupervisorViewModel>();
    final datos = paciente['datos'] as Map<String, dynamic>;
    final nome = (datos['nome'] as String?)?.trim();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar paciente?'),
        content: Text(
          'Deixarás de supervisar a ${nome?.isNotEmpty == true ? nome : 'Persoa ${indice + 1}'}. Tamén se cancelarán os seus avisos neste dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
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
      final eliminado = await vm.eliminar(paciente);
      if (!context.mounted) return;
      if (!eliminado) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.erro ?? 'Non se puido quitar o paciente')),
        );
      }
    } catch (_) {
      // O ViewModel xa converte os erros de dominio nun estado presentable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AxustesSupervisorViewModel>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Axustes do supervisor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: vm.cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Pacientes vinculados',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (vm.pacientes.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Non hai pacientes vinculados.',
                        style: TextStyle(fontSize: 17),
                      ),
                    ),
                  ),
                for (var i = 0; i < vm.pacientes.length; i++)
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(
                        vm.nomePaciente(i),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'Quitar paciente',
                        onPressed: vm.eliminandoUid == vm.pacientes[i]['uid']
                            ? null
                            : () => _eliminar(context, vm.pacientes[i], i),
                        icon: vm.eliminandoUid == vm.pacientes[i]['uid']
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.person_remove_outlined,
                                color: Colors.red,
                                size: 30,
                              ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
