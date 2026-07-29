import 'package:firebase_auth/firebase_auth.dart'; // Axustes do paciente.
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../servizos/servizo_notificacions_locais.dart';
import '../servizos/servizo_sincronizacion_p2p.dart';

class AxustesPacienteScreen extends StatefulWidget {
  const AxustesPacienteScreen({super.key});

  @override
  State<AxustesPacienteScreen> createState() => _AxustesPacienteScreenState();
}

class _AxustesPacienteScreenState extends State<AxustesPacienteScreen> {
  final _storage = const FlutterSecureStorage();
  final _nomeController = TextEditingController();
  TimeOfDay _hora = const TimeOfDay(hour: 20, minute: 0);
  bool _modoSinxelo = false;
  bool _cargando = true;
  bool _gardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final nome = await _storage.read(key: 'nome_usuario') ?? '';
    final hora = await _storage.read(key: 'hora_toma') ?? '20:00';
    final modoSinxelo = await _storage.read(key: 'modo_sinxelo') == 'true';
    final partes = hora.split(':');
    if (!mounted) return;
    setState(() {
      _nomeController.text = nome;
      if (partes.length == 2) {
        _hora = TimeOfDay(
          hour: int.tryParse(partes[0]) ?? 20,
          minute: int.tryParse(partes[1]) ?? 0,
        );
      }
      _modoSinxelo = modoSinxelo;
      _cargando = false;
    });
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
    setState(() => _modoSinxelo = activar);
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
    setState(() => _gardando = true);
    final nome = _nomeController.text.trim();
    final hora =
        '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}';
    if (nome.isEmpty) {
      await _storage.delete(key: 'nome_usuario');
    } else {
      await _storage.write(key: 'nome_usuario', value: nome);
    }
    await _storage.write(key: 'hora_toma', value: hora);
    await _storage.write(
      key: 'modo_sinxelo',
      value: _modoSinxelo ? 'true' : 'false',
    );
    await LocalNotificationService().programarTomas(
      identificador: 'paciente_local',
      nome: nome,
      hora: hora,
    );
    await P2PSyncService().notificarCoidador('ESTADO_COMPLETO');
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _mostrarQr() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final token = await FirebaseMessaging.instance.getToken();
    if (!mounted) return;
    if (uid == null || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Non se puido xerar o código QR')),
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
            QrImageView(data: '$uid|$token', size: 230),
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F9FA),
    appBar: AppBar(
      title: const Text(
        'Axustes',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
    body: _cargando
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
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Mostra unicamente a toma e o acceso aos axustes.',
                  ),
                  value: _modoSinxelo,
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
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Vincular a aplicación con outra persoa coidadora.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _mostrarQr,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _gardando ? null : _gardar,
                icon: _gardando
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
