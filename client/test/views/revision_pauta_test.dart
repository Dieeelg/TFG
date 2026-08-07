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
    expect(find.text('Revisar correccións'), findsOneWidget);
    expect(find.text('Está todo correcto?'), findsNothing);
  });
}
