import 'package:flutter/material.dart'; // Configuración adicional inicial.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../servizos/servizo_sincronizacion_p2p.dart';
import '../../servizos/servizo_notificacions_locais.dart';

class AdditionalSettingsScreen extends StatefulWidget {
  const AdditionalSettingsScreen({super.key});

  @override
  State<AdditionalSettingsScreen> createState() => _AdditionalSettingsScreenState();
}

class _AdditionalSettingsScreenState extends State<AdditionalSettingsScreen> {
  final _nomeController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  TimeOfDay _hora = const TimeOfDay(hour: 20, minute: 0);
  bool _gardando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarHora() async {
    final novaHora = await showTimePicker(
      context: context,
      initialTime: _hora,
      helpText: 'Selecciona a hora habitual da toma',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (novaHora != null && mounted) setState(() => _hora = novaHora);
  }

  Future<void> _continuar() async {
    setState(() => _gardando = true);
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) {
      await _storage.delete(key: 'nome_usuario');
    } else {
      await _storage.write(key: 'nome_usuario', value: nome);
    }
    await _storage.write(
      key: 'hora_toma',
      value: '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}',
    );
    await _storage.write(key: 'configuracion_finalizada', value: 'true');
    final horaTexto = '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}';
    await LocalNotificationService().programarTomas(
      identificador: 'paciente_local',
      nome: nome,
      hora: horaTexto,
    );
    await P2PSyncService().notificarCoidador('ESTADO_COMPLETO');
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final horaTexto = '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}';
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
          child: Column(
            children: [
              const Icon(Icons.tune_rounded, color: Colors.blue, size: 52),
              const SizedBox(height: 14),
              const Text(
                'Configuracións adicionais',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Personaliza a aplicación. Poderá cambiar estes datos máis adiante desde Axustes.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, height: 1.35, color: Colors.black54),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 12, offset: const Offset(0, 5))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nome da persoa usuaria', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Opcional', style: TextStyle(fontSize: 14, color: Colors.black54)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nomeController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'Como quere que lle chamemos?',
                        prefixIcon: const Icon(Icons.person_outline),
                        filled: true,
                        fillColor: const Color(0xFFF4F7FA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text('Hora habitual da toma', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Empregarase para mostrar a hora e configurar os futuros recordatorios.', style: TextStyle(fontSize: 15, height: 1.3, color: Colors.black54)),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _seleccionarHora,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        decoration: BoxDecoration(color: const Color(0xFFE7F4FF), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue.shade100)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.schedule, size: 36, color: Colors.blue),
                            const SizedBox(width: 14),
                            Text(horaTexto, style: const TextStyle(fontSize: 38, color: Colors.blue, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            const Icon(Icons.edit_outlined, color: Colors.blue),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              ElevatedButton(
                onPressed: _gardando ? null : _continuar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF333333),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _gardando
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Continuar ao inicio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
