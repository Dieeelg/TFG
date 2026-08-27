import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_sintrom/modelos_vista/autenticacion/configuracion_adicional.dart';
import 'package:tfg_sintrom/modelos_vista/autenticacion/configuracion_inicial.dart';
import 'package:tfg_sintrom/modelos_vista/configuracion_paciente_supervisado.dart';

void main() {
  group('ConfiguracionInicialViewModel', () {
    test('autentica e garda o rol de paciente', () async {
      var autenticou = false;
      String? rol;
      final vm = ConfiguracionInicialViewModel.conDependencias(
        iniciarSesion: () async => autenticou = true,
        gardarRol: (valor) async => rol = valor,
      );

      expect(
        await vm.autenticar(esPaciente: true),
        ResultadoAutenticacion.exito,
      );
      expect(autenticou, isTrue);
      expect(rol, 'PACIENTE');
      expect(vm.estaCargando, isFalse);
    });

    test('devolve erro, notifica carga e evita envíos simultáneos', () async {
      final espera = Completer<void>();
      final vm = ConfiguracionInicialViewModel.conDependencias(
        iniciarSesion: () => espera.future,
        gardarRol: (_) async {},
      );
      var notificacions = 0;
      vm.addListener(() => notificacions++);

      final primeira = vm.autenticar(esPaciente: false);
      expect(vm.estaCargando, isTrue);
      expect(
        await vm.autenticar(esPaciente: false),
        ResultadoAutenticacion.erro,
      );
      espera.completeError(Exception('firebase'));
      expect(await primeira, ResultadoAutenticacion.erro);
      expect(vm.estaCargando, isFalse);
      expect(notificacions, 2);
    });
  });

  group('ConfiguracionAdicionalViewModel', () {
    test('garda datos limpos, programa e sincroniza', () async {
      final escritos = <String, String>{};
      final eliminados = <String>[];
      String? aviso;
      String? programacion;
      final vm = ConfiguracionAdicionalViewModel.conDependencias(
        eliminar: (key) async => eliminados.add(key),
        escribir: (key, value) async => escritos[key] = value,
        programarTomas: ({required nome, required hora}) async {
          programacion = '$nome@$hora';
        },
        notificarSupervisores: (tipo) async => aviso = tipo,
      );

      expect(await vm.gardar(nome: '  Diego  ', hora: '21:30'), isTrue);
      expect(escritos, containsPair('nome_usuario', 'Diego'));
      expect(escritos, containsPair('hora_toma', '21:30'));
      expect(escritos, containsPair('configuracion_finalizada', 'true'));
      expect(eliminados, isEmpty);
      expect(programacion, 'Diego@21:30');
      expect(aviso, 'ESTADO_COMPLETO');
      expect(vm.gardando, isFalse);
      expect(vm.erro, isNull);
    });

    test('elimina o nome baleiro e informa de erros', () async {
      final eliminados = <String>[];
      final vm = ConfiguracionAdicionalViewModel.conDependencias(
        eliminar: (key) async => eliminados.add(key),
        escribir: (_, _) async {},
        programarTomas: ({required nome, required hora}) async {
          throw Exception('notificacións');
        },
        notificarSupervisores: (_) async {},
      );

      expect(await vm.gardar(nome: ' ', hora: '20:00'), isFalse);
      expect(eliminados, ['nome_usuario']);
      expect(vm.erro, 'Non se puido gardar a configuración');
      expect(vm.gardando, isFalse);
    });
  });

  group('ConfiguracionPacienteSupervisadoViewModel', () {
    test('recorta o nome antes de enviar a configuración', () async {
      Map<String, String>? enviado;
      final vm = ConfiguracionPacienteSupervisadoViewModel.conDependencias(
        enviarConfiguracion:
            ({required tokenPaciente, required nome, required horaToma}) async {
              enviado = {
                'token': tokenPaciente,
                'nome': nome,
                'hora': horaToma,
              };
            },
      );

      expect(
        await vm.gardar(tokenPaciente: 'token', nome: ' Ana ', hora: '19:15'),
        isTrue,
      );
      expect(enviado, {'token': 'token', 'nome': 'Ana', 'hora': '19:15'});
    });

    test('bloquea duplicados e expón o erro do servizo', () async {
      final espera = Completer<void>();
      final vm = ConfiguracionPacienteSupervisadoViewModel.conDependencias(
        enviarConfiguracion:
            ({required tokenPaciente, required nome, required horaToma}) =>
                espera.future,
      );

      final primeira = vm.gardar(
        tokenPaciente: 'token',
        nome: 'Ana',
        hora: '20:00',
      );
      expect(vm.enviando, isTrue);
      expect(
        await vm.gardar(tokenPaciente: 'token', nome: 'Ana', hora: '20:00'),
        isFalse,
      );
      espera.completeError(Exception('sen conexión'));
      expect(await primeira, isFalse);
      expect(vm.erro, 'sen conexión');
      expect(vm.enviando, isFalse);
    });
  });
}
