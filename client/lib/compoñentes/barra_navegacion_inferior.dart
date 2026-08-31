import 'package:flutter/material.dart'; // Barra de navegación principal.
import '../views/calendario.dart';
import '../views/progreso.dart';

class BarraNavegacionInferior extends StatelessWidget {
  final int currentIndex;
  const BarraNavegacionInferior({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) async {
        if (index == currentIndex) return;
        if (index == 0) {
          Navigator.popUntil(context, ModalRoute.withName('/paciente'));
        } else if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProgresoScreen()),
          );
        } else if (index == 2) {
          await Navigator.pushNamed(context, '/captura');
        } else if (index == 3) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CalendarioScreen()),
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
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
        const BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: ''),
        const BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: ''),
        const BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month),
          label: '',
        ),
      ],
    );
  }
}
