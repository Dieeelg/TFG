import 'package:flutter/material.dart'; // Pantalla de inicio do paciente.
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../modelos/pauta_toma.dart';
import '../modelos_vista/inicio.dart';
import '../compoñentes/representacion_dose.dart';
import 'camara/captura_informe.dart';
import 'progreso.dart';
import 'calendario.dart';
import 'axustes_paciente.dart';

class PacienteHomeScreen extends StatefulWidget {
  const PacienteHomeScreen({super.key});

  @override
  State<PacienteHomeScreen> createState() => _PacienteHomeScreenState();
}

class _PacienteHomeScreenState extends State<PacienteHomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeViewModel>().iniciar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: vm.cargando || !vm.preferenciasCargadas
            ? const Center(
                child: CircularProgressIndicator(),
              ) // Indicador de carga
            : RefreshIndicator(
                // Para poder refrescar arrastrando cara abaixo
                onRefresh: () => vm.cargarDatosHome(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      if (vm.pautaSemanal.isEmpty)
                        _buildEmptyState(context)
                      else if (vm.modoSinxelo) ...[
                        if (vm.tomaHoxe == null)
                          _buildNoPendingState()
                        else if (vm.tomaHoxe!.eControl)
                          _buildControlState(vm)
                        else
                          _buildCardProximaToma(context, vm),
                      ] else ...[
                        if (vm.tomaHoxe == null)
                          _buildNoPendingState()
                        else if (vm.tomaHoxe!.eControl)
                          _buildControlState(vm)
                        else
                          _buildCardProximaToma(context, vm),
                        const SizedBox(height: 20),
                        if (vm.tomaHoxe != null &&
                            vm.tomaHoxe?.eControl != true) ...[
                          _buildCardProximoControl(),
                          const SizedBox(height: 20),
                        ],
                        _buildPautaSemanal(vm),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: vm.modoSinxelo ? null : _buildBottomBar(context),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue, size: 42),
          const SizedBox(height: 12),
          const Text(
            'Escanee o documento para comezar',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Para poder comezar a empregar a app debe escanear unha folla de tratamento.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, height: 1.35, color: Colors.black54),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final cambiou = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => const CapturaInformeScreen(),
                ),
              );
              if (cambiou == true && context.mounted) {
                await context.read<HomeViewModel>().cargarDatosHome();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF333333),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Escanear', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  // --- CABECEIRA ---
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            context.read<HomeViewModel>().nomeUsuario == null
                ? 'Bo día,'
                : 'Bo día, ${context.read<HomeViewModel>().nomeUsuario}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 31, fontWeight: FontWeight.bold),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Notificacións',
              onPressed: () {},
              icon: const Icon(Icons.mail_outline, size: 34),
            ),
            IconButton(
              tooltip: 'Axustes',
              onPressed: () async {
                final cambiou = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AxustesPacienteScreen(),
                  ),
                );
                if (!mounted) return;
                if (cambiou == true) {
                  await context.read<HomeViewModel>().reactivar();
                }
              },
              icon: const Icon(Icons.settings_outlined, size: 34),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardProximaToma(BuildContext context, HomeViewModel vm) {
    final toma = vm.tomaHoxe;
    final tomada =
        toma?.estado == 'TOMADA' || toma?.estado == 'TOMADA_FORA_HORA';
    final hoxe = DateTime.now().toIso8601String().substring(0, 10);
    final podeConfirmar =
        toma != null &&
        toma.data == hoxe &&
        !toma.eControl &&
        toma.dose != 'NON' &&
        toma.estado == 'PENDENTE';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(
        color: toma?.estado == 'TOMADA_FORA_HORA'
            ? const Color(0xFFFFE0A6)
            : tomada
            ? const Color(0xFFB8E5E1)
            : Colors.white,
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              toma?.estado == 'TOMADA_FORA_HORA'
                  ? 'Toma completada fóra de hora'
                  : tomada
                  ? 'Toma completada'
                  : _tituloToma(toma),
              style: TextStyle(
                color: tomada ? const Color(0xFF268F5A) : Colors.blueGrey,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 82,
                height: 82,
                child: CustomPaint(
                  painter: DoseVisual(
                    _doseNumerica(vm.doseHoxe),
                    color: tomada ? const Color(0xFF29965F) : Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${tomada ? 'TOMADOS' : 'TOMAR'} ${vm.doseHoxe}",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: tomada ? const Color(0xFF268F5A) : Colors.orange,
                      ),
                    ),
                    Text(
                      _etiquetaDataToma(toma),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Ás ${context.read<HomeViewModel>().horaToma}',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!tomada) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: podeConfirmar
                  ? () => _pedirConfirmacionToma(vm)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF333333),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Confirmar toma",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPautaSemanal(HomeViewModel vm) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Pauta",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 18),
          vm.pautaSemanal.isEmpty
              ? const Text(
                  "Non hai pautas rexistradas. Saca unha foto ao teu informe.",
                )
              : SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    runAlignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 14,
                    runSpacing: 18,
                    children: vm.pautaSemanal
                        .map((toma) => _buildDoseCircle(toma))
                        .toList(),
                  ),
                ),
        ],
      ),
    );
  }

  // --- TARXETA PRÓXIMO CONTROL (Axustada) ---
  Widget _buildCardProximoControl() {
    final cabeceira = context.watch<HomeViewModel>().cabeceira;
    return Container(
      width: double.infinity, // Asegura que mida o mesmo que a de arriba
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Próximo control",
            style: TextStyle(
              color: Colors.blueGrey,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          // Usamos Row con Expanded para que o texto flúa ben
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.blue, size: 34),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cabeceira?.proximaVisita ?? 'Data non dispoñible',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      cabeceira?.centro ?? 'Centro non identificado',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (cabeceira?.centro?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => _chamarAoCentro(cabeceira!.centro!),
              icon: const Icon(Icons.phone, size: 22),
              label: const Text(
                'Chamar ao centro',
                style: TextStyle(fontSize: 17),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF333333),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Datos de contacto: Xunta de Galicia (CC BY-SA 4.0)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.black45),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDoseCircle(PautaToma toma) {
    final colorFondo = switch (toma.estado) {
      _ when toma.dose == 'NON' => const Color(0xFFFFD0C8),
      'TOMADA' => const Color(0xFF9BE0CA),
      'TOMADA_FORA_HORA' => const Color(0xFFFFD180),
      'NON_TOMADA' => const Color(0xFFFFA99B),
      'PENDENTE' => const Color(0xFFE1E4E8),
      _ => const Color(0xFFE1E4E8),
    };

    return Column(
      children: [
        CircleAvatar(
          backgroundColor: colorFondo,
          radius: 30,
          child: Text(
            toma.dose,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          toma.dia,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<HomeViewModel>().reactivar();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _buildNoPendingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: _cardDecoration(color: const Color(0xFFEAF4FF)),
      child: const Column(
        children: [
          Icon(Icons.check_circle_outline, size: 54, color: Colors.blue),
          SizedBox(height: 14),
          Text(
            'Non hai tomas pendentes',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Non quedan doses programadas nesta folla de tratamento.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, height: 1.35, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildControlState(HomeViewModel vm) {
    final control = vm.tomaHoxe!;
    final hoxe = DateTime.now().toIso8601String().substring(0, 10);
    final eHoxe = control.data == hoxe;
    final cabeceira = vm.cabeceira;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(color: const Color(0xFFE7F4FF)),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_month,
              color: Colors.white,
              size: 42,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            eHoxe ? 'O control é hoxe' : 'Próximo control',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF075A9C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _dataLexible(control.data),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (cabeceira?.centro?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              cabeceira!.centro!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _chamarAoCentro(cabeceira.centro!),
              icon: const Icon(Icons.phone),
              label: const Text(
                'Chamar ao centro',
                style: TextStyle(fontSize: 17),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF333333),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _doseNumerica(String dose) {
    if (dose.contains('/')) {
      final partes = dose.split('/');
      final numerador = double.tryParse(partes.first);
      final denominador = double.tryParse(partes.last);
      if (numerador != null && denominador != null && denominador != 0) {
        return (numerador / denominador).clamp(0, 1);
      }
    }
    return (double.tryParse(dose) ?? 0).clamp(0, 1);
  }

  String _dataLexible(String data) {
    final partes = data.split('-');
    return partes.length == 3 ? '${partes[2]}/${partes[1]}/${partes[0]}' : data;
  }

  String _etiquetaDataToma(PautaToma? toma) {
    if (toma == null) return 'Non hai unha toma dispoñible';
    final hoxe = DateTime.now().toIso8601String().substring(0, 10);
    final data = _dataLexible(toma.data);
    if (toma.data == hoxe) return 'Hoxe, $data';
    if (toma.data.compareTo(hoxe) > 0) return 'Próxima toma, $data';
    return 'Última toma, $data';
  }

  String _tituloToma(PautaToma? toma) {
    if (toma == null) return 'Non hai tomas dispoñibles';
    final hoxe = DateTime.now().toIso8601String().substring(0, 10);
    if (toma.data == hoxe) return 'Toma de hoxe';
    if (toma.data.compareTo(hoxe) > 0) return 'Próxima toma pendente';
    return 'Última toma rexistrada';
  }

  Future<void> _pedirConfirmacionToma(HomeViewModel vm) async {
    final toma = vm.tomaHoxe;
    if (toma == null) return;
    final farmaco = vm.cabeceira?.farmaco?.trim();
    final confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: const BoxDecoration(
            color: Color(0xFFBDE7FF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: const Column(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.blue, size: 40),
              SizedBox(height: 6),
              Text(
                'Confirmar toma',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Estás seguro de rexistrar esta toma?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Rexistrarase a toma de ${toma.dose}${farmaco == null || farmaco.isEmpty ? '' : ' de $farmaco'}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.35),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFF1F1F1),
              child: const Text(
                'Este dato engadirase ao teu historial de cumprimento.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      minimumSize: const Size.fromHeight(50),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF333333),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'Confirmar',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmado == true && mounted) {
      await vm.confirmarTomaHoxe();
    }
  }

  Future<void> _chamarAoCentro(String centro) async {
    try {
      final telefono = await context.read<HomeViewModel>().buscarTelefonoCentro(
        centro,
      );
      final uri = Uri(scheme: 'tel', path: telefono);
      if (!await launchUrl(uri)) {
        throw Exception('Non se puido abrir o marcador do teléfono');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  // --- DECORACIÓN COMÚN ---
  BoxDecoration _cardDecoration({Color color = Colors.white}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return BottomNavigationBar(
      onTap: (index) {
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProgressScreen()),
          );
        }
        if (index == 2) {
          // Botón da cámara
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CapturaInformeScreen(),
            ),
          ).then((_) {
            if (context.mounted) {
              context.read<HomeViewModel>().cargarDatosHome();
            }
          });
        }
        if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TreatmentCalendarScreen(),
            ),
          );
        }
      },
      type: BottomNavigationBarType.fixed,
      iconSize: 37,
      selectedFontSize: 0,
      unselectedFontSize: 0,
      backgroundColor: Colors.white,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.black54,
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: ""),
        const BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: ""),
        const BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: ""),
        const BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month),
          label: "",
        ),
      ],
    );
  }
}
