import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:tfg_sintrom/views/auth/vinculacion_exitosa_screen.dart';
import '../../viewmodels/auth/vinculacion_coidador_viewmodel.dart';

class VincularCoidadorScreen extends StatefulWidget {
  const VincularCoidadorScreen({super.key});

  @override
  State<VincularCoidadorScreen> createState() => _VincularCoidadorScreenState();
}

class _VincularCoidadorScreenState extends State<VincularCoidadorScreen> {
  final MobileScannerController controller = MobileScannerController();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VinculacionCoidadorViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vincular Paciente'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 1. ESCÁNER DE CÁMARA
          MobileScanner(
            controller: controller,
            onDetect: (capture) async {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && !vm.escaneando) {
                  // Chamamos ao ViewModel para procesar o QR
                  final exito = await vm.vincularPaciente(barcode.rawValue!);

                  if (exito && context.mounted) {
                    _mostrarMensaxe(context, "Vinculación completada con éxito", Colors.green);
                    // En lugar de un SnackBar, imos á nova pantalla de éxito
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const VinculacionExitosaScreen()),
                    );
                  } else if (vm.erro != null && context.mounted) {
                    // Se hai erro, mostramos o aviso pero deixamos seguir intentando
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(vm.erro!), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
          ),

          // 2. MÁSCARA VISUAL (O cadro guía)
          _buildOverlay(context),

          // 3. INDICADOR DE CARGA (Se a API está traballando)
          if (vm.escaneando)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 4),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Enfoca o código QR do paciente',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarMensaxe(BuildContext context, String texto, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: cor),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}