import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tfg_sintrom/modelos_vista/autenticacion/vinculacion_paciente.dart';
import 'package:tfg_sintrom/views/autenticacion/vinculacion_paciente.dart';

class _VinculacionPacienteFalsa extends VinculacionPacienteViewModel {
  @override
  bool get cargando => false;

  @override
  String? get datosQR => 'vinculacion-de-proba';

  @override
  bool get tenCoidador => false;

  @override
  Future<void> xerarDatosVinculacion() async {}

  @override
  Future<void> comprobarEstadoVinculacion() async {}

  @override
  Future<void> configurarEscaneoAutomaticoPaciente() async {}
}

void main() {
  testWidgets('a vinculación adáptase a unha pantalla baixa sen desbordar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final viewModel = _VinculacionPacienteFalsa();
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<VinculacionPacienteViewModel>.value(
        value: viewModel,
        child: const MaterialApp(home: VinculacionScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Saltar vinculación'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
