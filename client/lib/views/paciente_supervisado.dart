import 'dart:math'; // Detalle do paciente supervisado.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'camara/captura_informe.dart';
import '../modelos_vista/paciente_supervisado.dart';

class PacienteSupervisadoScreen extends StatelessWidget {
  final Map<String, dynamic> paciente;
  final int numero;
  const PacienteSupervisadoScreen({
    super.key,
    required this.paciente,
    required this.numero,
  });

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) =>
        PacienteSupervisadoViewModel(paciente: paciente, numero: numero)
          ..iniciar(),
    child: const _PacienteSupervisadoView(),
  );
}

class _PacienteSupervisadoView extends StatefulWidget {
  const _PacienteSupervisadoView();

  @override
  State<_PacienteSupervisadoView> createState() =>
      _PacienteSupervisadoViewState();
}

class _PacienteSupervisadoViewState extends State<_PacienteSupervisadoView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<PacienteSupervisadoViewModel>().recargar();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PacienteSupervisadoViewModel>();
    final d = vm.datos;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        title: Text(
          'Supervisando a ${vm.nomeVisible}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: _dato(
                      'Dose actual',
                      d['doseSemanalActual']?.toString() ?? '--',
                    ),
                  ),
                  const SizedBox(height: 72, child: VerticalDivider()),
                  Expanded(
                    child: _dato(
                      'INR actual',
                      d['inrActual']?.toString() ?? '--',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    '${d['estadoHoxe'] == 'TOMADA' || d['estadoHoxe'] == 'TOMADA_FORA_HORA' ? 'TOMADOS' : 'TOMAR'} ${d['doseHoxe'] ?? '--'}',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      color:
                          d['estadoHoxe'] == 'TOMADA' ||
                              d['estadoHoxe'] == 'TOMADA_FORA_HORA'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hora habitual: ${d['horaToma'] ?? 'Sen configurar'}',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _grafica('Evolución do INR', vm.valoresInr, barras: false),
          const SizedBox(height: 14),
          _grafica('Evolución da dose semanal', vm.valoresDose, barras: true),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              title: const Text('Próxima cita'),
              subtitle: Text(
                '${d['proximaVisita'] ?? 'Non dispoñible'}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: const Icon(Icons.schedule, size: 36),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CapturaInformeScreen(
                  tokenPacienteDestino: vm.paciente['token'] as String,
                ),
              ),
            ),
            icon: const Icon(Icons.camera_alt),
            label: const Text(
              'Escanear un novo informe',
              style: TextStyle(fontSize: 17),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: const Color(0xFF333333),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dato(String titulo, String valor) => Column(
    children: [
      Text(
        titulo,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text(
        valor,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 23,
          color: Colors.blue,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );

  Widget _grafica(
    String titulo,
    List<double> valores, {
    required bool barras,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            width: double.infinity,
            child: valores.isEmpty
                ? const Center(child: Text('Non hai datos suficientes'))
                : CustomPaint(
                    painter: _GraficaPacienteSupervisadoPainter(
                      valores,
                      barras: barras,
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

class _GraficaPacienteSupervisadoPainter extends CustomPainter {
  final List<double> valores;
  final bool barras;
  const _GraficaPacienteSupervisadoPainter(
    this.valores, {
    required this.barras,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 38.0;
    const bottom = 24.0;
    final width = size.width - left;
    final height = size.height - bottom;
    final maxValue = max(valores.reduce(max) * 1.2, 1.0);
    final grid = Paint()..color = Colors.black12;
    for (var i = 0; i <= 4; i++) {
      final y = height * i / 4;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      _text(
        canvas,
        (maxValue * (4 - i) / 4).toStringAsFixed(maxValue < 5 ? 1 : 0),
        Offset(0, y - 7),
        11,
      );
    }
    final step = width / valores.length;
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = barras ? PaintingStyle.fill : PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < valores.length; i++) {
      final x = left + (i + .5) * step;
      final y = height - valores[i] / maxValue * height;
      if (barras) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(x - step * .3, y, x + step * .3, height),
            const Radius.circular(4),
          ),
          paint,
        );
      } else {
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
        canvas.drawCircle(Offset(x, y), 5, Paint()..color = Colors.blue);
      }
      _text(
        canvas,
        valores[i].toStringAsFixed(valores[i] % 1 == 0 ? 0 : 1),
        Offset(x - 9, max(0.0, y - 19)),
        12,
      );
      _text(canvas, '${i + 1}', Offset(x - 3, height + 5), 11);
    }
    if (!barras) canvas.drawPath(path, paint);
  }

  void _text(Canvas canvas, String value, Offset offset, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: size,
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(
    covariant _GraficaPacienteSupervisadoPainter oldDelegate,
  ) => true;
}
