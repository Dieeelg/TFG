import 'package:flutter/material.dart'; // Barra de navegación principal.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../views/calendario.dart';
import '../views/progreso.dart';

class AppBottomNav extends StatefulWidget {
  final int currentIndex;
  const AppBottomNav({super.key, required this.currentIndex});

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  bool? _escaneaPaciente;

  @override
  void initState() {
    super.initState();
    _cargarPreferencia();
  }

  Future<void> _cargarPreferencia() async {
    final valor = await const FlutterSecureStorage().read(key: 'quen_escanea');
    if (mounted) setState(() => _escaneaPaciente = valor == 'PACIENTE');
  }

  @override
  Widget build(BuildContext context) {
    final podeEscanear = _escaneaPaciente == true;
    final indiceVisual = !podeEscanear && widget.currentIndex == 3
        ? 2
        : widget.currentIndex;
    return BottomNavigationBar(
      currentIndex: indiceVisual,
      onTap: (index) async {
        final destino = podeEscanear ? index : (index == 2 ? 3 : index);
        if (destino == widget.currentIndex) return;
        if (destino == 0) {
          Navigator.popUntil(context, ModalRoute.withName('/home'));
        } else if (destino == 1) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProgressScreen()));
        } else if (destino == 2) {
          await Navigator.pushNamed(context, '/captura');
        } else if (destino == 3) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TreatmentCalendarScreen()));
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
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
        const BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: ''),
        if (podeEscanear)
          const BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: ''),
        const BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: ''),
      ],
    );
  }
}
