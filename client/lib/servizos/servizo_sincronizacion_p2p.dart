import 'dart:convert'; // Sincronización entre paciente e supervisor.
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'servizo_api.dart';
import 'servizo_base_datos.dart';
import 'servizo_cifrado_p2p.dart';
import '../modelos/analise.dart';
import 'servizo_notificacions_locais.dart';
import 'planificador_recordatorios.dart';

class ServizoSincronizacionP2P {
  static final ServizoSincronizacionP2P _instance =
      ServizoSincronizacionP2P._internal();
  factory ServizoSincronizacionP2P() => _instance;
  ServizoSincronizacionP2P._internal();

  final _api = ServizoApi();
  final _db = ServizoBaseDatos();
  final _storage = const FlutterSecureStorage();
  final _cifrado = ServizoCifradoP2P();
  final _actualizacions = StreamController<String>.broadcast();
  Stream<String> get actualizacions => _actualizacions.stream;

  Future<void> procesarMensaxe(RemoteMessage message) async {
    final tipo = message.data['tipo_aviso'];
    final envelope = message.data['payload'] ?? '';
    if (tipo == null || tipo.isEmpty || envelope.isEmpty) return;

    late final PayloadP2PDescifrado mensaxe;
    try {
      mensaxe = await _cifrado.descifrarPayload(
        envelope: envelope,
        tipoAviso: tipo,
        permitirClavePendente: tipo == 'VINCULACION_INICIAL',
      );
    } on MensaxeP2PNonValida catch (e) {
      debugPrint('Mensaxe P2P descartada: ${e.motivo}');
      return;
    }
    final payloadRaw = mensaxe.contido;
    final vinculacionId = mensaxe.vinculacionId;
    if (tipo == 'VINCULACION_INICIAL') {
      final datos = _jsonOuNull(payloadRaw);
      final token = datos?['token'] as String?;
      final uidSupervisor = datos?['supervisorUid'] as String?;
      final clavePermanente = datos?['clavePermanente'] as String?;
      if (token == null ||
          token.isEmpty ||
          uidSupervisor == null ||
          uidSupervisor.isEmpty ||
          clavePermanente == null ||
          clavePermanente.isEmpty) {
        debugPrint('Mensaxe de vinculación incompleta');
        return;
      }
      await _cifrado.confirmarVinculacionPendente(
        id: vinculacionId,
        uidSupervisor: uidSupervisor,
        tokenSupervisor: token,
        clavePermanenteBase64: clavePermanente,
      );
      await _storage.write(key: 'token_supervisor', value: token);
      final tokens = await _tokensSupervisores();
      if (token.isNotEmpty && !tokens.contains(token)) tokens.add(token);
      await _storage.write(
        key: 'tokens_supervisores',
        value: jsonEncode(tokens),
      );
      return;
    }
    if (tipo == 'DESVINCULAR_SUPERVISOR') {
      final vinculacion = await _cifrado.obterPorId(vinculacionId);
      if (vinculacion == null || vinculacion.rolRemoto != 'SUPERVISOR') return;
      await _retirarTokenSupervisor(vinculacion.tokenRemoto);
      await _cifrado.eliminarPorId(vinculacionId);
      _actualizacions.add('paciente_local');
      return;
    }
    if (tipo == 'DESVINCULAR_PACIENTE') {
      final vinculacion = await _cifrado.obterPorId(vinculacionId);
      final datos = _jsonOuNull(payloadRaw);
      final uidPaciente = datos?['pacienteUid'] as String?;
      if (vinculacion == null ||
          vinculacion.rolRemoto != 'PACIENTE' ||
          uidPaciente == null ||
          uidPaciente != vinculacion.uidRemoto) {
        return;
      }
      await _db.eliminarPacienteSupervisor(uidPaciente);
      await ServizoNotificacionsLocais().cancelarTomas(
        'supervisor_$uidPaciente',
      );
      await _cifrado.eliminarPorId(vinculacionId);
      _actualizacions.add('supervisor:$uidPaciente');
      return;
    }
    final payload = _jsonOuNull(payloadRaw);
    if (payload == null) return;
    if (tipo == 'SOLICITAR_SINCRONIZACION') {
      final tokenResposta = payload['tokenResposta'] as String?;
      final vinculacion = await _cifrado.obterPorId(vinculacionId);
      if (tokenResposta != null && vinculacion != null) {
        final actualizada = vinculacion.copyWith(tokenRemoto: tokenResposta);
        await _cifrado.gardarVinculacion(actualizada);
        await _enviarEstadoCompleto(actualizada);
      }
    } else if (tipo == 'ESTADO_COMPLETO' ||
        tipo == 'TOMA_CONFIRMADA' ||
        tipo == 'TOMA_ESQUECIDA' ||
        tipo == 'NOVO_INFORME') {
      final uid = payload['pacienteUid'] as String?;
      final token = payload['tokenPaciente'] as String?;
      if (uid != null && token != null) {
        final vinculacion = await _cifrado.obterPorId(vinculacionId);
        if (vinculacion != null) {
          await _cifrado.gardarVinculacion(
            vinculacion.copyWith(uidRemoto: uid, tokenRemoto: token),
          );
        }
        await _db.gardarPacienteSupervisor(
          uid: uid,
          token: token,
          nome: payload['nome'] as String?,
          payload: payload,
        );
        final hora = payload['horaToma'] as String?;
        if (hora != null) {
          final nomePaciente =
              (payload['nome'] as String?) ?? 'Persoa supervisada';
          final hoxe = DateTime.now().toIso8601String().substring(0, 10);
          final datasConToma =
              (payload['datasConToma'] as List?)
                  ?.whereType<String>()
                  .toList() ??
              <String>[];
          if (datasConToma.isEmpty &&
              PlanificadorRecordatorios.eDoseTomable(payload['doseHoxe'])) {
            datasConToma.add(hoxe);
          }
          final estadoHoxe = payload['estadoHoxe'] as String?;
          await ServizoNotificacionsLocais().programarTomas(
            identificador: 'supervisor_$uid',
            nome: nomePaciente,
            hora: hora,
            datasConToma: datasConToma,
            estados: estadoHoxe == null ? const {} : {hoxe: estadoHoxe},
          );
        }
        _actualizacions.add('supervisor:$uid');
      }
    } else if (tipo == 'INFORME_FRAGMENTO') {
      await _procesarFragmentoInforme(payload);
    } else if (tipo == 'CONFIGURACION_ACTUALIZADA') {
      final nome = payload['nome'] as String?;
      final hora = payload['horaToma'] as String?;
      if (nome != null && nome.trim().isNotEmpty) {
        await _storage.write(key: 'nome_usuario', value: nome.trim());
      }
      if (hora != null) await _storage.write(key: 'hora_toma', value: hora);
      if (hora != null) {
        await ServizoNotificacionsLocais().programarTomasPaciente(
          nome: nome ?? '',
          hora: hora,
        );
      }
      await notificarSupervisores('ESTADO_COMPLETO');
      _actualizacions.add('paciente_local');
    }
  }

  Future<Map<String, dynamic>> crearResumoPaciente() async {
    await _db.pecharTomasVencidas();
    final pauta = await _db.obterPauta();
    final estados = await _db.obterEstados();
    final cabeceira = await _db.obterCabeceira();
    final historico = await _db.obterHistorico();
    final nome = await _storage.read(key: 'nome_usuario');
    final hora = await _storage.read(key: 'hora_toma');
    final token = await FirebaseMessaging.instance.getToken();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final hoxe = DateTime.now().toIso8601String().substring(0, 10);
    final tomables = pauta
        .where(
          (d) => !d.eControl && PlanificadorRecordatorios.eDoseTomable(d.dose),
        )
        .toList();
    bool eTomada(String? estado) =>
        estado == 'TOMADA' || estado == 'TOMADA_FORA_HORA';
    final tomadas = tomables.where((d) => eTomada(estados[d.data])).length;
    final esquecidas = tomables
        .where((d) => !eTomada(estados[d.data]) && d.data.compareTo(hoxe) < 0)
        .length;
    final decididas = tomadas + esquecidas;
    final hoxeDose = pauta.where((d) => d.data == hoxe).firstOrNull;
    return {
      'pacienteUid': uid,
      'tokenPaciente': token,
      'nome': nome,
      'horaToma': hora,
      'tenInforme': pauta.isNotEmpty,
      'doseHoxe': hoxeDose?.eControl == true ? 'CTRL' : hoxeDose?.dose,
      'estadoHoxe': hoxeDose == null ? null : (estados[hoxe] ?? 'PENDENTE'),
      'datasConToma': tomables
          .where((dia) => dia.data.compareTo(hoxe) >= 0)
          .map((dia) => dia.data)
          .toList(),
      'proximaVisita': cabeceira?.proximaVisita,
      'centro': cabeceira?.centro,
      'inrActual': cabeceira?.inr,
      'doseSemanalActual': cabeceira?.doseSemanal,
      'historico': historico
          .map((h) => {'data': h.data, 'inr': h.inr, 'dose': h.dose})
          .toList(),
      'diasTomados': tomadas,
      'diasNonTomados': esquecidas,
      'cumprimento': decididas == 0 ? 0 : (tomadas * 100 / decididas).round(),
      'actualizadoEn': DateTime.now().toIso8601String(),
    };
  }

  Future<void> enviarEstadoCompleto(
    String tokenDestino, {
    String tipo = 'ESTADO_COMPLETO',
  }) async {
    final vinculacion = await _cifrado.obterPorToken(tokenDestino);
    if (vinculacion == null) {
      debugPrint(
        'Non existe unha clave segura para o dispositivo destinatario',
      );
      return;
    }
    await _enviarEstadoCompleto(vinculacion, tipo: tipo);
  }

  Future<void> notificarSupervisores(String tipo) async {
    for (final vinculacion in await _cifrado.obterPorRolRemoto('SUPERVISOR')) {
      await _enviarEstadoCompleto(vinculacion, tipo: tipo);
    }
  }

  Future<void> _enviarEstadoCompleto(
    VinculacionP2P vinculacion, {
    String tipo = 'ESTADO_COMPLETO',
  }) async {
    final resumo = await crearResumoPaciente();
    await _enviarCifrado(
      vinculacion: vinculacion,
      payload: jsonEncode(resumo),
      tipoAviso: tipo,
    );
  }

  Future<bool> enviarPayloadParaToken({
    required String tokenDestino,
    required String payload,
    required String tipoAviso,
  }) async {
    final vinculacion = await _cifrado.obterPorToken(tokenDestino);
    if (vinculacion == null) return false;
    return _enviarCifrado(
      vinculacion: vinculacion,
      payload: payload,
      tipoAviso: tipoAviso,
    );
  }

  Future<bool> _enviarCifrado({
    required VinculacionP2P vinculacion,
    required String payload,
    required String tipoAviso,
  }) async {
    final envelope = await _cifrado.cifrarPayload(
      vinculacion: vinculacion,
      tipoAviso: tipoAviso,
      payload: payload,
    );
    return _api.enviarNotificacion(
      tokenDestino: vinculacion.tokenRemoto,
      payload: envelope,
      tipoAviso: tipoAviso,
    );
  }

  Future<List<String>> _tokensSupervisores() async {
    final raw = await _storage.read(key: 'tokens_supervisores');
    final legacy = await _storage.read(key: 'token_supervisor');
    final tokens = <String>[];
    if (raw != null) {
      try {
        tokens.addAll((jsonDecode(raw) as List).whereType<String>());
      } catch (_) {}
    }
    if (legacy != null && legacy.isNotEmpty && !tokens.contains(legacy)) {
      tokens.add(legacy);
    }
    return tokens;
  }

  Future<void> _retirarTokenSupervisor(String token) async {
    final tokens = await _tokensSupervisores();
    tokens.remove(token);
    await _storage.write(key: 'tokens_supervisores', value: jsonEncode(tokens));
    if (tokens.isEmpty) {
      await _storage.delete(key: 'token_supervisor');
    } else {
      await _storage.write(key: 'token_supervisor', value: tokens.first);
    }
  }

  Future<void> solicitarSincronizacion() async {
    final pacientes = await _db.obterPacientesSupervisor();
    final meuToken = await FirebaseMessaging.instance.getToken();
    if (meuToken == null) return;
    for (final paciente in pacientes) {
      final vinculacion = await _cifrado.obterPorUid(paciente['uid'] as String);
      if (vinculacion == null) continue;
      await _enviarCifrado(
        vinculacion: vinculacion,
        payload: jsonEncode({'tokenResposta': meuToken}),
        tipoAviso: 'SOLICITAR_SINCRONIZACION',
      );
    }
  }

  Future<void> desvincularPaciente({
    required String uid,
    required String tokenPaciente,
  }) async {
    final meuToken = await FirebaseMessaging.instance.getToken();
    if (meuToken == null || meuToken.isEmpty) {
      throw Exception('Non se puido identificar este dispositivo supervisor');
    }
    final vinculacion =
        await _cifrado.obterPorUid(uid) ??
        await _cifrado.obterPorToken(tokenPaciente);
    if (vinculacion == null) {
      throw Exception(
        'A vinculación non dispón dunha clave segura. Debe repetirse o emparellamento.',
      );
    }
    final enviada = await _enviarCifrado(
      vinculacion: vinculacion,
      payload: jsonEncode({'tokenSupervisor': meuToken}),
      tipoAviso: 'DESVINCULAR_SUPERVISOR',
    );
    if (!enviada) {
      throw Exception('Non se puido avisar ao paciente da desvinculación');
    }
    await _cifrado.eliminarPorUid(uid);
    await _db.eliminarPacienteSupervisor(uid);
    await ServizoNotificacionsLocais().cancelarTomas('supervisor_$uid');
    _actualizacions.add('supervisor:$uid');
  }

  Future<void> desvincularSupervisor(VinculacionP2P vinculacion) async {
    if (vinculacion.rolRemoto != 'SUPERVISOR') {
      throw Exception(
        'A vinculación seleccionada non pertence a un supervisor',
      );
    }
    final uidPaciente = FirebaseAuth.instance.currentUser?.uid;
    if (uidPaciente == null || uidPaciente.isEmpty) {
      throw Exception('Non se puido identificar este dispositivo paciente');
    }
    final enviada = await _enviarCifrado(
      vinculacion: vinculacion,
      payload: jsonEncode({'pacienteUid': uidPaciente}),
      tipoAviso: 'DESVINCULAR_PACIENTE',
    );
    if (!enviada) {
      throw Exception('Non se puido avisar ao supervisor da desvinculación');
    }
    await _retirarTokenSupervisor(vinculacion.tokenRemoto);
    await _cifrado.eliminarPorId(vinculacion.id);
    _actualizacions.add('paciente_local');
  }

  Future<void> enviarConfiguracionPaciente({
    required String tokenPaciente,
    required String nome,
    required String horaToma,
  }) async {
    final vinculacion = await _cifrado.obterPorToken(tokenPaciente);
    if (vinculacion == null) {
      throw Exception('A vinculación non dispón dunha clave segura');
    }
    await _enviarCifrado(
      vinculacion: vinculacion,
      payload: jsonEncode({'nome': nome, 'horaToma': horaToma}),
      tipoAviso: 'CONFIGURACION_ACTUALIZADA',
    );
  }

  Future<void> enviarInformeRemoto(
    AnaliseModel analise,
    String tokenPaciente,
  ) async {
    final vinculacion = await _cifrado.obterPorToken(tokenPaciente);
    if (vinculacion == null) {
      throw Exception('A vinculación non dispón dunha clave segura');
    }
    final json = jsonEncode({
      'cabeceira': {
        'dataInforme': analise.cabeceira.dataInforme,
        'inr': analise.cabeceira.inr,
        'farmaco': analise.cabeceira.farmaco,
        'doseSemanal': analise.cabeceira.doseSemanal,
        'proximaVisita': analise.cabeceira.proximaVisita,
        'centro': analise.cabeceira.centro,
      },
      'calendario': analise.calendario
          .map(
            (d) => {
              'data': d.data,
              'dia': d.dia,
              'dose': d.dose,
              'accion': d.accion,
              'eControl': d.eControl,
              'diaSemanaTexto': d.diaSemanaTexto,
            },
          )
          .toList(),
      'historico': analise.historico
          .map(
            (h) => {
              'data': h.data,
              'inr': h.inr,
              'farmaco': h.farmaco,
              'dose': h.dose,
              'apttInyectable': h.apttInyectable,
              'doseInyectable': h.doseInyectable,
              'proximaVisita': h.proximaVisita,
              'comentarios': h.comentarios,
            },
          )
          .toList(),
    });
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    const tamanho = 2200;
    final total = (json.length / tamanho).ceil();
    for (var i = 0; i < total; i++) {
      final fin = (i + 1) * tamanho > json.length
          ? json.length
          : (i + 1) * tamanho;
      await _enviarCifrado(
        vinculacion: vinculacion,
        payload: jsonEncode({
          'id': id,
          'indice': i,
          'total': total,
          'datos': json.substring(i * tamanho, fin),
        }),
        tipoAviso: 'INFORME_FRAGMENTO',
      );
    }
  }

  Future<void> _procesarFragmentoInforme(Map<String, dynamic> payload) async {
    final id = payload['id'].toString();
    final indice = payload['indice'] as int;
    final total = payload['total'] as int;
    await _storage.write(
      key: 'informe_${id}_$indice',
      value: payload['datos'] as String,
    );
    final partes = <String>[];
    for (var i = 0; i < total; i++) {
      final parte = await _storage.read(key: 'informe_${id}_$i');
      if (parte == null) return;
      partes.add(parte);
    }
    final analise = AnaliseModel.fromJson(
      jsonDecode(partes.join()) as Map<String, dynamic>,
    );
    await _db.gardarAnalise(analise);
    final hora = await _storage.read(key: 'hora_toma');
    if (hora != null) {
      await ServizoNotificacionsLocais().programarTomasPaciente(
        nome: await _storage.read(key: 'nome_usuario') ?? '',
        hora: hora,
      );
    }
    for (var i = 0; i < total; i++) {
      await _storage.delete(key: 'informe_${id}_$i');
    }
    await notificarSupervisores('NOVO_INFORME');
    _actualizacions.add('paciente_local');
  }

  Map<String, dynamic>? _jsonOuNull(String valor) {
    try {
      return jsonDecode(valor) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
