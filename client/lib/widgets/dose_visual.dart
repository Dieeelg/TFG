import 'dart:math';
import 'package:flutter/material.dart';

class DoseVisual extends CustomPainter {
  final double dose; // Ex: 0.75 para 3/4

  DoseVisual(this.dose);

  @override
  void paint(Canvas canvas, Size size) {
    final paintBase = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final paintDose = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Debuxamos o fondo (o círculo completo pálido)
    canvas.drawCircle(center, radius, paintBase);

    // Debuxamos a dose (o arco azul forte)
    double sweepAngle = 2 * pi * dose;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Empezamos arriba ás 12
      sweepAngle,
      true,
      paintDose,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}