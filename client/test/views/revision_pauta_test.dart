import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_sintrom/modelos/analise.dart';
import 'package:tfg_sintrom/modelos/cabeceira.dart';
import 'package:tfg_sintrom/modelos/dose_dia.dart';
import 'package:tfg_sintrom/views/camara/revision_pauta.dart';

void main() {
  testWidgets('comeza en revisión e só edita cando o usuario o solicita', (
    tester,
  ) async {
    final analise = AnaliseModel(
      cabeceira: CabeceiraModel(
        dataInforme: '2026-08-07',
        inr: '2.5',
        farmaco: 'Sintrom 4 mg',
        doseSemanal: '3,5 mg',
        proximaVisita: '12/08/2026',
      ),
      calendario: [
        DoseDiaModel(
          data: '2026-08-08',
          dia: 8,
          dose: '1/2',
          accion: 'TOMAR',
          eControl: false,
          diaSemanaTexto: 'SÁBADO',
        ),
      ],
      historico: const [],
    );

    await tester.pumpWidget(
      MaterialApp(home: RevisionPautaScreen(analise: analise)),
    );

    await tester.scrollUntilVisible(
      find.text('Está todo correcto?'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Está todo correcto?'), findsOneWidget);
    expect(find.text('Si, confirmar e gardar'), findsOneWidget);
    expect(find.text('Non, corrixir datos'), findsOneWidget);
    expect(find.text('Revisar correccións'), findsNothing);

    await tester.ensureVisible(find.text('Non, corrixir datos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Non, corrixir datos'));
    await tester.pumpAndSettle();

    expect(find.text('Corrixir a pauta'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Dose: 1/2'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Dose: 1/2'), findsOneWidget);
    expect(find.text('Engadir dose ou control'), findsOneWidget);
    expect(find.text('Revisar correccións'), findsOneWidget);
    expect(find.text('Está todo correcto?'), findsNothing);
  });

  testWidgets('permite eliminar unha fila extraída de máis e desfacelo', (
    tester,
  ) async {
    final analise = AnaliseModel(
      cabeceira: CabeceiraModel(proximaVisita: '13/08/2026'),
      calendario: [
        DoseDiaModel(
          data: '2026-08-13',
          dia: 13,
          dose: null,
          accion: 'CONTROL',
          eControl: true,
          diaSemanaTexto: 'XOVES',
        ),
        DoseDiaModel(
          data: '2026-08-13',
          dia: 13,
          dose: '0',
          accion: 'NON TOMAR',
          eControl: false,
          diaSemanaTexto: 'XOVES',
        ),
      ],
      historico: const [],
    );

    await tester.pumpWidget(
      MaterialApp(home: RevisionPautaScreen(analise: analise)),
    );
    await tester.scrollUntilVisible(
      find.text('Non, corrixir datos'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Non, corrixir datos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Non, corrixir datos'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('eliminar-dia-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('eliminar-dia-1')));
    await tester.pump();

    expect(find.byTooltip('Eliminar este día'), findsOneWidget);
    expect(find.text('Eliminouse a fila da pauta.'), findsOneWidget);

    final accionDesfacer = tester.widget<SnackBarAction>(
      find.byType(SnackBarAction),
    );
    accionDesfacer.onPressed();
    await tester.pump();
    expect(find.byTooltip('Eliminar este día'), findsNWidgets(2));
  });
}
