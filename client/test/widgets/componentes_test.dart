import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_sintrom/compoñentes/barra_navegacion_inferior.dart';
import 'package:tfg_sintrom/compoñentes/representacion_dose.dart';

void main() {
  testWidgets('barra marca a sección actual e abre a ruta de captura', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(
          body: Text('Inicio'),
          bottomNavigationBar: BarraNavegacionInferior(currentIndex: 0),
        ),
        routes: {
          '/captura': (_) => const Scaffold(body: Text('Captura aberta')),
        },
      ),
    );

    final barra = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(barra.currentIndex, 0);
    expect(barra.items, hasLength(4));

    await tester.tap(find.byIcon(Icons.home));
    await tester.pump();
    expect(find.text('Inicio'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pumpAndSettle();
    expect(find.text('Captura aberta'), findsOneWidget);
  });

  testWidgets(
    'RepresentacionDose pinta doses completas e fraccionarias sen erros',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              CustomPaint(
                size: const Size(40, 40),
                painter: RepresentacionDose(0.5),
              ),
              CustomPaint(
                size: const Size(40, 40),
                painter: RepresentacionDose(1),
              ),
            ],
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is RepresentacionDose,
        ),
        findsNWidgets(2),
      );
      expect(
        RepresentacionDose(0.5).shouldRepaint(RepresentacionDose(0.5)),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
