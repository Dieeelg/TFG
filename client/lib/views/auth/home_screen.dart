import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Corriximos a ruta do import (asegúrate de que o arquivo existe en lib/viewmodels/)
import '../../viewmodels/home_viewmodel.dart';

// Definimos a clase aquí mesmo para que non dea erro de "Undefined class"
class PautaToma {
  final String dia;
  final String dose;
  final String estado;
  PautaToma({required this.dia, required this.dose, required this.estado});
}

class PacienteHomeScreen extends StatelessWidget {
  const PacienteHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildCardProximaToma(context),
              const SizedBox(height: 20),
              _buildCardProximoControl(),
              const SizedBox(height: 20),
              _buildPautaSemanal(context), // Pasamos o context aquí
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Bo día, Diego",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        IconButton(onPressed: () {}, icon: const Icon(Icons.mail_outline, size: 30)),
      ],
    );
  }

  Widget _buildCardProximaToma(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Align(alignment: Alignment.centerLeft, child: Text("Próxima toma pendente", style: TextStyle(color: Colors.blueGrey))),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.pie_chart, size: 80, color: Colors.blue),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Corrixido: Colors.orange en vez de orangeRed
                  const Text("TOMAR 3/4", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
                  Text("Hoxe, 11/10/2025", style: TextStyle(color: Colors.grey[600])),
                  const Text("Ás, 19:00", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF333333),
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            child: const Text("Confirmar toma", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // AQUÍ VAI O MAP DA PAUTA SEMANAL
  Widget _buildPautaSemanal(BuildContext context) {
    // Usamos o ViewModel para obter a lista
    final vm = context.watch<HomeViewModel>();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Pauta semanal", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Wrap(
            spacing: 12,
            runSpacing: 15,
            children: vm.pautaSemanal.map((toma) => _buildDoseCircle(toma)).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildDoseCircle(PautaToma toma) {
    Color colorFondo = const Color(0xFFD1E7DD);
    if (toma.dose == "NON") colorFondo = const Color(0xFFF8D7DA);
    if (toma.estado == "PENDENTE") colorFondo = Colors.grey[200]!;

    return Column(
      children: [
        CircleAvatar(
          backgroundColor: colorFondo,
          radius: 25,
          child: Text(toma.dose, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
        ),
        const SizedBox(height: 4),
        Text(toma.dia, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCardProximoControl() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Próximo control", style: TextStyle(color: Colors.blueGrey)),
          const SizedBox(height: 8),
          const Text("Luns, 11 de Novembro 09:35",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text("C.S Viveiro", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.black54,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: ""),
        BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: ""),
        BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: ""),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: ""),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: ""),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
    );
  }
}