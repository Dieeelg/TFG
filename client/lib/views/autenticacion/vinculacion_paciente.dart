import 'package:flutter/material.dart'; // Vinculación desde o paciente.
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../modelos_vista/autenticacion/vinculacion_paciente.dart';

class VinculacionScreen extends StatefulWidget {
  const VinculacionScreen({super.key});

  @override
  State<VinculacionScreen> createState() => _VinculacionScreenState();
}

class _VinculacionScreenState extends State<VinculacionScreen> {
  @override
  void initState() {
    super.initState();
    // Iniciamos a xeración do QR e o chequeo automático do Timer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VinculacionPacienteViewModel>().xerarDatosVinculacion();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Consumer<VinculacionPacienteViewModel>(
                  builder: (context, vm, child) {
                    return Column(
                      children: [
                        const Text(
                          'Vinculación',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Amosa este código á persoa que te vai acompañar no teu seguimento. Ao vinculala, poderá consultar o tratamento e engadir novas follas no teu nome.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF34495E),
                          ),
                        ),

                        SizedBox(
                          height: constraints.maxHeight >= 760 ? 24 : 12,
                        ),

                        if (vm.cargando)
                          const SizedBox(
                            height: 250,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (vm.datosQR != null)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 15,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: QrImageView(
                              //Xeramos o QR
                              data: vm.datosQR!,
                              version: QrVersions.auto,
                              size: 250.0,
                              gapless: false,
                            ),
                          )
                        else
                          const Text("Erro ao cargar os datos de vinculación"),

                        SizedBox(
                          height: constraints.maxHeight >= 760 ? 24 : 12,
                        ),

                        _buildAvisoNotificacions(),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: vm.tenCoidador
                                ? () {
                                    Navigator.pushReplacementNamed(
                                      context,
                                      '/configuracion_adicional',
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: vm.tenCoidador ? 4 : 0,
                            ),
                            child: vm.tenCoidador
                                ? const Text(
                                    'Continuar á App',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Agardando polo coidador...',
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // --- BOTÓN PARA SALTAR ---
                        // Só o mostramos se aínda non se vinculou ninguén
                        if (!vm.tenCoidador) _buildBotonSaltar(context),

                        const SizedBox(height: 10),

                        // Refresco manual por se o timer non funciona
                        if (!vm.tenCoidador)
                          TextButton(
                            onPressed: () => vm.comprobarEstadoVinculacion(),
                            child: Text(
                              "Xa me escaneou? Preme aquí",
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ),

                        const SizedBox(height: 20),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvisoNotificacions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: Colors.amber, width: 4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFF856404)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Enviaranse notificacións sobre as túas tomas ademais dun resumo dos teus datos.',
              style: TextStyle(
                color: Color(0xFF856404),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonSaltar(BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.pushReplacementNamed(context, '/configuracion_adicional');
      },
      child: const Text(
        'Saltar vinculación',
        style: TextStyle(
          color: Color(0xFF333333),
          fontSize: 16,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
