import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../modelos_vista/axustes_paciente.dart';

class AxustesPacienteScreen extends StatelessWidget {
  const AxustesPacienteScreen({super.key, this.viewModel});

  final AxustesPacienteViewModel? viewModel;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => viewModel ?? (AxustesPacienteViewModel()..cargar()),
    child: const _AxustesPacienteView(),
  );
}

class _AxustesPacienteView extends StatefulWidget {
  const _AxustesPacienteView();

  @override
  State<_AxustesPacienteView> createState() => _AxustesPacienteViewState();
}

class _AxustesPacienteViewState extends State<_AxustesPacienteView> {
  final _nomeController = TextEditingController();
  TimeOfDay _hora = const TimeOfDay(hour: 20, minute: 0);
  bool _datosAplicados = false;

  Future<void> _desvincularSupervisor(
    VinculacionP2P vinculacion,
    int indice,
  ) async {
    final vm = context.read<AxustesPacienteViewModel>();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar persoa supervisora?'),
        content: Text(
          'A persoa supervisora ${indice + 1} deixará de consultar o teu tratamento, recibir avisos e engadir follas no teu nome.',
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
    if (confirmar != true || !mounted) return;
    final desvinculado = await vm.desvincular(vinculacion);
    if (!mounted) return;
    if (!desvinculado) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.erro ?? 'Non se puido quitar a vinculación')),
      );
    }
  }

  Future<void> _cambiarModo(bool activar) async {
    if (!activar) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Desactivar o modo sinxelo?'),
          content: const Text(
            'Volveranse mostrar as gráficas, o calendario e o resto das opcións da aplicación.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Desactivar'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
    }
    if (mounted) {
      context.read<AxustesPacienteViewModel>().cambiarModoSinxelo(activar);
    }
  }

  Future<void> _seleccionarHora() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: _hora,
      helpText: 'Hora habitual da toma',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (hora != null && mounted) setState(() => _hora = hora);
  }

  Future<void> _gardar() async {
    final vm = context.read<AxustesPacienteViewModel>();
    final hora =
        '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}';
    final gardado = await vm.gardar(nome: _nomeController.text, hora: hora);
    if (!mounted) return;
    if (gardado) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.erro ?? 'Non se puideron gardar os cambios')),
      );
    }
  }

  Future<void> _mostrarQr() async {
    final vm = context.read<AxustesPacienteViewModel>();
    final codigoQr = await vm.xerarCodigoQr();
    if (!mounted) return;
    if (codigoQr == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.erro ?? 'Non se puido xerar o código QR')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vincular outra persoa', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'A outra persoa debe escanear este código desde a súa aplicación. Ao vinculala, poderá consultar o tratamento e engadir novas follas no teu nome.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            QrImageView(data: codigoQr, size: 230),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Pechar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AxustesPacienteViewModel>();
    if (vm.cargado && !_datosAplicados) {
      _nomeController.text = vm.nome;
      final partes = vm.hora.split(':');
      if (partes.length == 2) {
        _hora = TimeOfDay(
          hour: int.tryParse(partes[0]) ?? 20,
          minute: int.tryParse(partes[1]) ?? 0,
        );
      }
      _datosAplicados = true;
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Axustes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: vm.cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Datos persoais',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nomeController,
                          decoration: const InputDecoration(
                            labelText: 'Nome (opcional)',
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.access_time,
                            color: Colors.blue,
                            size: 34,
                          ),
                          title: const Text(
                            'Hora da toma',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            _hora.format(context),
                            style: const TextStyle(fontSize: 20),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _seleccionarHora,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.all(18),
                    secondary: const Icon(
                      Icons.visibility_outlined,
                      color: Colors.blue,
                      size: 34,
                    ),
                    title: const Text(
                      'Modo sinxelo',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Mostra unicamente a toma e o acceso aos axustes.',
                    ),
                    value: vm.modoSinxelo,
                    onChanged: _cambiarModo,
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(18),
                    leading: const Icon(
                      Icons.qr_code_2,
                      color: Colors.blue,
                      size: 38,
                    ),
                    title: const Text(
                      'Mostrar código QR',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Vincular a aplicación con outra persoa supervisora.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _mostrarQr,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Persoas supervisoras vinculadas',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (vm.supervisores.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Non hai persoas supervisoras vinculadas.',
                        style: TextStyle(fontSize: 17),
                      ),
                    ),
                  ),
                for (var i = 0; i < vm.supervisores.length; i++)
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      leading: const CircleAvatar(
                        child: Icon(Icons.supervisor_account_outlined),
                      ),
                      title: Text(
                        'Persoa supervisora ${i + 1}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Pode consultar e actualizar a pauta',
                      ),
                      trailing: vm.desvinculandoId == vm.supervisores[i].id
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              tooltip: 'Quitar persoa supervisora',
                              onPressed: () =>
                                  _desvincularSupervisor(vm.supervisores[i], i),
                              icon: const Icon(
                                Icons.person_remove_outlined,
                                color: Colors.red,
                                size: 30,
                              ),
                            ),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: vm.gardando ? null : _gardar,
                  icon: vm.gardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text(
                    'Gardar cambios',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                  ),
                ),
              ],
            ),
    );
  }
}
