import 'dart:math'; // Gráficas de progreso.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../modelos_vista/progreso.dart';
import '../compoñentes/barra_navegacion_inferior.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, this.viewModel});

  final ProgressViewModel? viewModel;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => viewModel ?? (ProgressViewModel()..cargar()),
    child: const _ProgressView(),
  );
}

class _ProgressView extends StatelessWidget {
  const _ProgressView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProgressViewModel>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF8F9FA),
        title: const Text(
          'O meu progreso',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
      ),
      body: vm.cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Monitoriza a túa evolución e pauta',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _datoActual('Dose actual', vm.doseActual),
                        ),
                        const SizedBox(height: 70, child: VerticalDivider()),
                        Expanded(
                          child: _datoActual('INR actual', vm.inrActual),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _estatisticasHora(vm),
                const SizedBox(height: 16),
                _graficaCard('Evolución do INR', vm.valoresInr, barras: false),
                const SizedBox(height: 16),
                _graficaCard(
                  'Evolución da dose semanal',
                  vm.valoresDose,
                  barras: true,
                ),
              ],
            ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _datoActual(String titulo, String valor) => Column(
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

  Widget _estatisticasHora(ProgressViewModel vm) {
    final rexistros = vm.rexistrosConDesviacion;
    final foraHora = vm.tomasForaDeHora;
    final media = vm.desviacionMedia;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Horario das tomas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _datoActual(
                    'Desviación media',
                    media == null ? '--' : '$media min',
                  ),
                ),
                const SizedBox(height: 70, child: VerticalDivider()),
                Expanded(child: _datoActual('Fóra de hora', '$foraHora')),
              ],
            ),
            if (rexistros.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Últimos rexistros',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              ...rexistros.reversed.take(5).map((r) {
                final instante = DateTime.tryParse(
                  r['horaConfirmacion']?.toString() ?? '',
                );
                final desvio = r['desviacionMinutos'] as int;
                final hora = instante == null
                    ? '--:--'
                    : '${instante.hour.toString().padLeft(2, '0')}:${instante.minute.toString().padLeft(2, '0')}';
                final textoDesvio = desvio == 0
                    ? 'á hora'
                    : desvio > 0
                    ? '+$desvio min'
                    : '$desvio min';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text(r['data']?.toString() ?? '')),
                      Text(
                        '$hora  ·  $textoDesvio',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: desvio > 0
                              ? Colors.orange.shade800
                              : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _graficaCard(
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 190,
            width: double.infinity,
            child: valores.isEmpty
                ? const Center(child: Text('Non hai datos suficientes'))
                : CustomPaint(painter: _ChartPainter(valores, barras: barras)),
          ),
        ],
      ),
    ),
  );
}

class _ChartPainter extends CustomPainter {
  final List<double> valores;
  final bool barras;
  _ChartPainter(this.valores, {required this.barras});

  @override
  void paint(Canvas canvas, Size size) {
    const esquerda = 38.0;
    const abaixo = 26.0;
    final ancho = size.width - esquerda - 4;
    final altoGrafica = size.height - abaixo - 6;
    final grid = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = 6 + altoGrafica * i / 4;
      canvas.drawLine(Offset(esquerda, y), Offset(size.width, y), grid);
    }
    // Engadimos marxe superior para que as etiquetas non queden cortadas.
    final maximo = max(valores.reduce(max) * 1.22, 1.0);
    final paso = ancho / max(valores.length, 1);
    for (var i = 0; i <= 4; i++) {
      final valor = maximo * (4 - i) / 4;
      _texto(
        canvas,
        valor.toStringAsFixed(valor < 5 ? 1 : 0),
        Offset(0, 6 + altoGrafica * i / 4 - 8),
        12,
        Colors.black87,
      );
    }
    final azul = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = barras ? PaintingStyle.fill : PaintingStyle.stroke;
    if (barras) {
      for (var i = 0; i < valores.length; i++) {
        final alto = valores[i] / maximo * altoGrafica;
        final x = esquerda + i * paso + 5;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 6 + altoGrafica - alto, max(paso - 10, 4.0), alto),
            const Radius.circular(4),
          ),
          azul,
        );
        _etiquetaValor(
          canvas,
          _formato(valores[i]),
          Offset(x + max(paso - 10, 4.0) / 2, max(2.0, altoGrafica - alto - 7)),
        );
        _texto(
          canvas,
          '${i + 1}',
          Offset(x + max(paso - 10, 4.0) / 2 - 4, size.height - 20),
          13,
          Colors.black87,
        );
      }
    } else {
      final path = Path();
      for (var i = 0; i < valores.length; i++) {
        final punto = Offset(
          esquerda + (i + .5) * paso,
          6 + altoGrafica - valores[i] / maximo * altoGrafica,
        );
        i == 0
            ? path.moveTo(punto.dx, punto.dy)
            : path.lineTo(punto.dx, punto.dy);
        canvas.drawCircle(punto, 5, Paint()..color = Colors.blue);
        _etiquetaValor(
          canvas,
          _formato(valores[i]),
          Offset(punto.dx, max(2.0, punto.dy - 13)),
        );
        _texto(
          canvas,
          '${i + 1}',
          Offset(punto.dx - 4, size.height - 20),
          13,
          Colors.black87,
        );
      }
      canvas.drawPath(path, azul);
    }
  }

  String _formato(double valor) =>
      valor.toStringAsFixed(valor % 1 == 0 ? 0 : 1);

  void _texto(
    Canvas canvas,
    String texto,
    Offset offset,
    double tamanho,
    Color cor,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(
          fontSize: tamanho,
          color: cor,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _etiquetaValor(Canvas canvas, String texto, Offset centro) {
    final painter = TextPainter(
      text: TextSpan(
        text: texto,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF075A9C),
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromCenter(
      center: centro,
      width: painter.width + 10,
      height: painter.height + 5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = Colors.white.withValues(alpha: .94),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()
        ..color = const Color(0xFF90CAF9)
        ..style = PaintingStyle.stroke,
    );
    painter.paint(
      canvas,
      Offset(
        rect.center.dx - painter.width / 2,
        rect.center.dy - painter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) =>
      oldDelegate.valores != valores || oldDelegate.barras != barras;
}
