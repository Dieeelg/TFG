import 'package:flutter/material.dart'; // Calendario do tratamento.
import '../modelos/dose_dia.dart';
import '../servizos/servizo_base_datos.dart';
import '../compoñentes/barra_navegacion_inferior.dart';

class TreatmentCalendarScreen extends StatefulWidget {
  const TreatmentCalendarScreen({super.key});

  @override
  State<TreatmentCalendarScreen> createState() => _TreatmentCalendarScreenState();
}

class _TreatmentCalendarScreenState extends State<TreatmentCalendarScreen> {
  List<DoseDiaModel> _pauta = [];
  Map<String, String> _estados = {};
  String? _proximaVisita;
  bool _cargando = true;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    final db = DatabaseService();
    await db.pecharTomasVencidas();
    final pauta = await db.obterPauta();
    final estados = await db.obterEstados();
    final cabeceira = await db.obterCabeceira();
    if (!mounted) return;
    setState(() { _pauta = pauta; _estados = estados; _proximaVisita = cabeceira?.proximaVisita; _cargando = false; });
  }

  @override
  Widget build(BuildContext context) {
    final tomables = _pauta.where((d) => !d.eControl && d.dose != '0').toList();
    final hoxe = DateTime.now().toIso8601String().substring(0, 10);
    bool eTomada(String? estado) => estado == 'TOMADA' || estado == 'TOMADA_FORA_HORA';
    final tomadas = tomables.where((d) => eTomada(_estados[d.data])).length;
    final esquecidas = tomables.where((d) => !eTomada(_estados[d.data]) && d.data.compareTo(hoxe) < 0).length;
    final decididas = tomadas + esquecidas;
    final cumprimento = decididas == 0 ? 0 : (tomadas * 100 / decididas).round();
    final diasAtaCita = _diasAtaCita(_proximaVisita);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF8F9FA),
        title: const Text('O meu calendario', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      ),
      body: _cargando ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Monitoriza as tomas e as datas das citas de control', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          Card(child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('Lun', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Mar', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Mér', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Xov', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Ven', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Sáb', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Dom', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10, crossAxisSpacing: 6,
                children: _pauta.map((dia) => _dia(dia, hoxe)).toList(),
              ),
            ]),
          )),
          const SizedBox(height: 14),
          Card(child: ListTile(
            contentPadding: const EdgeInsets.all(18),
            title: const Text('Próxima cita', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_proximaVisita ?? 'Non dispoñible', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (diasAtaCita != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    diasAtaCita == 0 ? 'É hoxe' : diasAtaCita > 0 ? 'Quedan $diasAtaCita días' : 'A cita xa pasou',
                    style: TextStyle(fontSize: 16, color: diasAtaCita >= 0 ? Colors.orange : Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
            trailing: const Icon(Icons.schedule, size: 38),
          )),
          const SizedBox(height: 14),
          Card(child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Resumo da pauta actual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _resumo('$tomadas', 'Días tomados', Colors.green),
                _resumo('$esquecidas', 'Días non tomados', Colors.red),
                _resumo('$cumprimento %', 'Cumprimento', Colors.blue),
              ]),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: cumprimento / 100,
                  minHeight: 12,
                  backgroundColor: const Color(0xFFE1E4E8),
                  color: cumprimento >= 80 ? Colors.green : cumprimento >= 50 ? Colors.orange : Colors.red,
                ),
              ),
            ]),
          )),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  Widget _dia(DoseDiaModel dia, String hoxe) {
    Color cor = const Color(0xFFE1E4E8);
    if (dia.dose == '0') {
      cor = const Color(0xFFFFD0C8);
    } else if (_estados[dia.data] == 'TOMADA') {
      cor = const Color(0xFF9BE0CA);
    } else if (_estados[dia.data] == 'TOMADA_FORA_HORA') {
      cor = const Color(0xFFFFD180);
    } else if (dia.data.compareTo(hoxe) < 0) {
      cor = const Color(0xFFFFA99B);
    }
    return Tooltip(
      message: dia.eControl ? 'Control' : 'Dose: ${dia.dose}',
      child: CircleAvatar(backgroundColor: cor, child: Text('${dia.dia}', style: const TextStyle(fontWeight: FontWeight.bold))),
    );
  }

  Widget _resumo(String valor, String etiqueta, Color cor) => Expanded(
    child: SizedBox(
      height: 78,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(valor, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: cor)),
          const SizedBox(height: 4),
          Expanded(child: Text(etiqueta, maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, height: 1.15))),
        ],
      ),
    ),
  );

  int? _diasAtaCita(String? texto) {
    if (texto == null || texto.trim().isEmpty) return null;
    final partes = texto.split(RegExp(r'[-/]'));
    DateTime? cita;
    if (partes.length == 3) {
      if (partes[0].length == 4) {
        cita = DateTime.tryParse('${partes[0]}-${partes[1].padLeft(2, '0')}-${partes[2].padLeft(2, '0')}');
      } else {
        cita = DateTime.tryParse('${partes[2]}-${partes[1].padLeft(2, '0')}-${partes[0].padLeft(2, '0')}');
      }
    }
    if (cita == null) return null;
    final hoxe = DateTime.now();
    final inicioHoxe = DateTime(hoxe.year, hoxe.month, hoxe.day);
    return cita.difference(inicioHoxe).inDays;
  }
}
