import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tfg_sintrom/modelos/analise.dart';
import 'package:tfg_sintrom/modelos/cabeceira.dart';
import 'package:tfg_sintrom/modelos/dose_dia.dart';
import 'package:tfg_sintrom/modelos/historico.dart';
import 'package:tfg_sintrom/modelos_vista/autenticacion/configuracion_adicional.dart';
import 'package:tfg_sintrom/modelos_vista/autenticacion/configuracion_inicial.dart';
import 'package:tfg_sintrom/modelos_vista/autenticacion/vinculacion_paciente.dart';
import 'package:tfg_sintrom/modelos_vista/axustes_supervisor.dart';
import 'package:tfg_sintrom/modelos_vista/calendario.dart';
import 'package:tfg_sintrom/modelos_vista/captura_informe.dart';
import 'package:tfg_sintrom/modelos_vista/progreso.dart';
import 'package:tfg_sintrom/views/autenticacion/configuracion_adicional.dart';
import 'package:tfg_sintrom/views/autenticacion/configuracion_inicial.dart';
import 'package:tfg_sintrom/views/axustes_supervisor.dart';
import 'package:tfg_sintrom/views/calendario.dart';
import 'package:tfg_sintrom/views/camara/captura_informe.dart';
import 'package:tfg_sintrom/views/progreso.dart';

import '../axuda/datos_proba.dart';

void main() {
  testWidgets('setup autentica o paciente e navega ata o QR', (tester) async {
    String? rol;
    final setup = ConfiguracionInicialViewModel.conDependencias(
      iniciarSesion: () async {},
      gardarRol: (valor) async => rol = valor,
    );
    final vinculacion = VinculacionPacienteViewModel.conDependencias(
      obterUid: () async => 'uid',
      obterToken: () async => 'token',
      xerarCodigo: ({required uidPaciente, required tokenPaciente}) async =>
          'codigo-qr',
      ler: (_) async => null,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: setup),
          ChangeNotifierProvider.value(value: vinculacion),
        ],
        child: const MaterialApp(home: ConfiguracionInicialScreen()),
      ),
    );
    expect(find.text('Quen vai usar a aplicación?'), findsOneWidget);

    await tester.tap(find.text('Para min'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(rol, 'PACIENTE');
    expect(find.text('Vinculación'), findsOneWidget);
    expect(vinculacion.datosQR, 'codigo-qr');
  });

  testWidgets('setup presenta o erro de autenticación sen navegar', (
    tester,
  ) async {
    final setup = ConfiguracionInicialViewModel.conDependencias(
      iniciarSesion: () async => throw Exception('firebase'),
      gardarRol: (_) async {},
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: setup,
        child: const MaterialApp(home: ConfiguracionInicialScreen()),
      ),
    );

    await tester.tap(find.text('Para min'));
    await tester.pumpAndSettle();

    expect(find.text('Erro ao conectar con Firebase'), findsOneWidget);
    expect(find.text('Quen vai usar a aplicación?'), findsOneWidget);
  });

  testWidgets('configuración adicional garda e substitúe toda a navegación', (
    tester,
  ) async {
    String? gardado;
    final vm = ConfiguracionAdicionalViewModel.conDependencias(
      eliminar: (_) async {},
      escribir: (key, value) async => gardado = '$key:$value',
      programarTomas: ({required nome, required hora}) async {},
      notificarSupervisores: (_) async {},
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: vm,
        child: MaterialApp(
          home: const ConfiguracionAdicionalScreen(),
          routes: {
            '/paciente': (_) => const Scaffold(body: Text('Inicio listo')),
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Diego');
    await tester.ensureVisible(find.text('Continuar ao inicio'));
    await tester.tap(find.text('Continuar ao inicio'));
    await tester.pumpAndSettle();

    expect(gardado, 'configuracion_finalizada:true');
    expect(find.text('Inicio listo'), findsOneWidget);
  });

  testWidgets('configuración adicional mostra o erro e permanece na pantalla', (
    tester,
  ) async {
    final vm = ConfiguracionAdicionalViewModel.conDependencias(
      eliminar: (_) async {},
      escribir: (_, _) async => throw Exception('storage'),
      programarTomas: ({required nome, required hora}) async {},
      notificarSupervisores: (_) async {},
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: vm,
        child: const MaterialApp(home: ConfiguracionAdicionalScreen()),
      ),
    );

    await tester.ensureVisible(find.text('Continuar ao inicio'));
    await tester.tap(find.text('Continuar ao inicio'));
    await tester.pumpAndSettle();

    expect(find.text('Non se puido gardar a configuración'), findsOneWidget);
    expect(find.text('Configuracións adicionais'), findsOneWidget);
  });

  testWidgets('calendario integra datos, estados, cita e cumprimento', (
    tester,
  ) async {
    final vm = CalendarioViewModel.conDependencias(
      pecharTomasVencidas: () async {},
      obterPauta: () async => [
        DoseDiaModel(
          data: '2026-08-20',
          dia: 20,
          dose: '1/2',
          accion: 'TOMAR',
          eControl: false,
          diaSemanaTexto: 'XOVES',
        ),
        DoseDiaModel(
          data: '2026-08-19',
          dia: 19,
          dose: '1',
          accion: 'TOMAR',
          eControl: false,
          diaSemanaTexto: 'VENRES',
        ),
      ],
      obterEstados: () async => {
        '2026-08-20': 'TOMADA',
        '2026-08-19': 'NON_TOMADA',
      },
      obterCabeceira: () async => CabeceiraModel(proximaVisita: '25/08/2026'),
      agora: () => DateTime(2026, 8, 21),
    );
    await vm.cargar();

    await tester.pumpWidget(MaterialApp(home: CalendarioScreen(viewModel: vm)));
    await tester.pumpAndSettle();

    expect(find.text('O meu calendario'), findsOneWidget);
    expect(find.text('Agosto 2026'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('25/08/2026'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('25/08/2026'), findsOneWidget);
    expect(find.text('Quedan 4 días'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Cumprimento'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('50 %'), findsOneWidget);
  });

  testWidgets('progreso integra histórico, métricas e formatos horarios', (
    tester,
  ) async {
    final vm = ProgresoViewModel.conDependencias(
      obterHistorico: () async => [
        ItemHistoricoModel(inr: '2,2', dose: '6 mg'),
      ],
      obterCabeceira: () async =>
          CabeceiraModel(inr: '2,5', doseSemanal: '7 mg'),
      obterCumprimento: () async => [
        {
          'data': '2026-08-20',
          'estado': 'TOMADA_FORA_HORA',
          'desviacionMinutos': 15,
          'horaConfirmacion': '2026-08-20T20:15:00',
        },
      ],
    );
    await vm.cargar();

    await tester.pumpWidget(MaterialApp(home: ProgresoScreen(viewModel: vm)));
    await tester.pumpAndSettle();

    expect(find.text('O meu progreso'), findsOneWidget);
    expect(find.text('2,5'), findsOneWidget);
    expect(find.text('7 mg'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);
    expect(find.text('20:15  ·  +15 min'), findsOneWidget);
  });

  testWidgets('axustes do supervisor confirma e elimina un paciente', (
    tester,
  ) async {
    var pacientes = [crearPacienteProba(nome: 'Ana')];
    final vm = AxustesSupervisorViewModel.conDependencias(
      obterPacientes: () async => pacientes,
      desvincularPaciente: ({required uid, required tokenPaciente}) async {
        pacientes = [];
      },
    );
    await vm.cargar();

    await tester.pumpWidget(
      MaterialApp(home: AxustesSupervisorScreen(viewModel: vm)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);

    await tester.tap(find.byTooltip('Quitar paciente'));
    await tester.pumpAndSettle();
    expect(find.text('Quitar paciente?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Quitar'));
    await tester.pumpAndSettle();

    expect(find.text('Non hai pacientes vinculados.'), findsOneWidget);
  });

  testWidgets('captura alterna entre opcións e estado de procesamento', (
    tester,
  ) async {
    final espera = Completer<AnaliseModel>();
    final vm = CapturaInformeViewModel.conDependencias(
      enviarInforme: (_) async => await espera.future,
      gardarAnalise: (_) async {},
      ler: (_) async => null,
      programarTomas: ({required nome, required hora}) async {},
      notificarSupervisores: (_) async {},
      enviarInformeRemoto: (_, _) async {},
    );

    await tester.pumpWidget(
      MaterialApp(home: CapturaInformeScreen(viewModel: vm)),
    );
    expect(find.text('Sacar unha foto'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Seleccionar un PDF'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Seleccionar un PDF'), findsOneWidget);

    final futuro = vm.extraer(File('informe.jpg'), 'informe.jpg');
    await tester.pump();
    expect(find.text('informe.jpg'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    espera.complete(crearAnaliseProba());
    await futuro;
    await tester.pump();
  });
}
