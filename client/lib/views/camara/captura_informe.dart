import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../modelos/analise.dart';
import '../../modelos_vista/captura_informe.dart';
import '../../compoñentes/barra_navegacion_inferior.dart';
import 'revision_pauta.dart';

class CapturaInformeScreen extends StatelessWidget {
  final String? tokenPacienteDestino;
  final CapturaInformeViewModel? viewModel;
  const CapturaInformeScreen({
    super.key,
    this.tokenPacienteDestino,
    this.viewModel,
  });

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => viewModel ?? CapturaInformeViewModel(),
    child: _CapturaInformeView(tokenPacienteDestino: tokenPacienteDestino),
  );
}

class _CapturaInformeView extends StatefulWidget {
  final String? tokenPacienteDestino;
  const _CapturaInformeView({this.tokenPacienteDestino});

  @override
  State<_CapturaInformeView> createState() => _CapturaInformeViewState();
}

class _CapturaInformeViewState extends State<_CapturaInformeView> {
  String? get tokenPacienteDestino => widget.tokenPacienteDestino;

  final ImagePicker _selectorImaxes = ImagePicker();

  Future<void> _escollerImaxe(ImageSource orixe) async {
    final imaxe = await _selectorImaxes.pickImage(
      source: orixe,
      imageQuality: 92,
    );
    if (imaxe != null) await _procesarFicheiro(File(imaxe.path), imaxe.name);
  }

  Future<void> _escollerPdf() async {
    final resultado = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
    );
    final ficheiro = resultado?.files.single;
    if (ficheiro?.path != null) {
      await _procesarFicheiro(File(ficheiro!.path!), ficheiro.name);
    }
  }

  Future<void> _procesarFicheiro(File ficheiro, String nome) async {
    final vm = context.read<CapturaInformeViewModel>();
    final analiseExtraida = await vm.extraer(ficheiro, nome);
    if (!mounted) return;
    if (analiseExtraida != null) {
      final analise = await Navigator.push<AnaliseModel>(
        context,
        MaterialPageRoute(
          builder: (_) => RevisionPautaScreen(
            analise: analiseExtraida,
            paraEnviar: tokenPacienteDestino != null,
          ),
        ),
      );
      if (analise == null || !mounted) return;
      final completado = await vm.completar(
        analise,
        tokenPacienteDestino: tokenPacienteDestino,
      );
      if (!mounted) return;
      if (!completado) {
        _mostrarErro(context, vm.erro);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF268F5A),
          content: Text(
            tokenPacienteDestino == null
                ? 'Informe revisado e gardado correctamente'
                : 'Informe revisado e enviado ao paciente',
          ),
        ),
      );
      Navigator.pop(context, true);
    } else {
      _mostrarErro(context, vm.erro);
    }
  }

  void _mostrarErro(BuildContext context, String? erro) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
        content: Text(erro ?? 'Non se puido procesar o informe', maxLines: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CapturaInformeViewModel>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: tokenPacienteDestino != null,
        backgroundColor: const Color(0xFFF8F9FA),
        title: const Text(
          'Engadir un informe',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F4FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sube a túa folla de tratamento',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tokenPacienteDestino == null
                        ? 'Extraeremos automaticamente a pauta, as doses e a próxima cita.'
                        : 'Extraeremos os datos e enviarémolos ao paciente que estás supervisando.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.35,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (vm.procesando)
              _tarxetaProcesando(vm.nomeFicheiro)
            else ...[
              const Text(
                'Como queres engadir o documento?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              _opcion(
                icona: Icons.camera_alt_outlined,
                cor: Colors.blue,
                titulo: 'Sacar unha foto',
                descricion: 'Abre a cámara para fotografar o informe agora.',
                onTap: () => _escollerImaxe(ImageSource.camera),
              ),
              const SizedBox(height: 12),
              _opcion(
                icona: Icons.photo_library_outlined,
                cor: const Color(0xFF268F5A),
                titulo: 'Escoller da galería',
                descricion: 'Selecciona unha foto que xa teñas no dispositivo.',
                onTap: () => _escollerImaxe(ImageSource.gallery),
              ),
              const SizedBox(height: 12),
              _opcion(
                icona: Icons.picture_as_pdf_outlined,
                cor: Colors.red.shade700,
                titulo: 'Seleccionar un PDF',
                descricion: 'Busca unha folla de tratamento gardada como PDF.',
                onTap: _escollerPdf,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, color: Color(0xFF9A6A00)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Para obter mellores resultados, comproba que o documento estea completo, enfocado e con boa iluminación.',
                        style: TextStyle(fontSize: 15, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: widget.tokenPacienteDestino == null
          ? const BarraNavegacionInferior(currentIndex: 2)
          : null,
    );
  }

  Widget _opcion({
    required IconData icona,
    required Color cor,
    required String titulo,
    required String descricion,
    required VoidCallback onTap,
  }) => Card(
    margin: EdgeInsets.zero,
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: cor.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icona, color: cor, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descricion,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.3,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 30, color: Colors.black45),
          ],
        ),
      ),
    ),
  );

  Widget _tarxetaProcesando(String? nomeFicheiro) => Card(
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      child: Column(
        children: [
          const SizedBox(
            width: 54,
            height: 54,
            child: CircularProgressIndicator(strokeWidth: 5),
          ),
          const SizedBox(height: 22),
          const Text(
            'Procesando o informe',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (nomeFicheiro != null)
            Text(
              nomeFicheiro,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, color: Colors.blueGrey),
            ),
          const SizedBox(height: 12),
          const Text(
            'Estamos extraendo a información. Este proceso pode tardar uns segundos.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.35, color: Colors.black54),
          ),
        ],
      ),
    ),
  );
}
