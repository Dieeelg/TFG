import 'dart:convert'; // Sincronización entre paciente e coidador.
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'servizo_api.dart';
import 'servizo_base_datos.dart';
import '../modelos/analise.dart';
import 'servizo_notificacions_locais.dart';
import 'planificador_recordatorios.dart';

class P2PSyncService {
  static final P2PSyncService _instance = P2PSyncService._internal();
  factory P2PSyncService() => _instance;
  P2PSyncService._internal();

  final _api = ApiService();
  final _db = DatabaseService();
  final _storage = const FlutterSecureStorage();
  final _actualizacions = StreamController<String>.broadcast();
  Stream<String> get actualizacions => _actualizacions.stream;

  Future<void> procesarMensaxe(RemoteMessage message) async {
    final tipo = message.data['tipo_aviso'];
    final payloadRaw = message.data['payload'] ?? '';
    if (tipo == 'VINCULACION_INICIAL') {
      final datos = _jsonOuNull(payloadRaw);
      final token = datos?['token'] as String? ?? payloadRaw;
      await _storage.write(key: 'token_coidador', value: token);
      final tokens = await _tokensCoidadores();
      if (token.isNotEmpty && !tokens.contains(token)) tokens.add(token);
      await _storage.write(key: 'tokens_coidadores', value: jsonEncode(tokens));
      return;
    }
    if (tipo == 'DESVINCULAR_COIDADOR') {
      final datos = _jsonOuNull(payloadRaw);
      final token = datos?['tokenCoidador'] as String?;
      final tokens = await _tokensCoidadores();
      if (token == null) {
        tokens.clear();
      } else {
        tokens.remove(token);
      }
      await _storage.write(key: 'tokens_coidadores', value: jsonEncode(tokens));
      if (tokens.isEmpty) {
        await _storage.delete(key: 'token_coidador');
      } else {
        await _storage.write(key: 'token_coidador', value: tokens.first);
      }
      _actualizacions.add('paciente_local');
      return;
    }
    final payload = _jsonOuNull(payloadRaw);
    if (payload == null) return;
    if (tipo == 'SOLICITAR_SINCRONIZACION') {
      final tokenResposta = payload['tokenResposta'] as String?;
      if (tokenResposta != null) await enviarEstadoCompleto(tokenResposta);
    } else if (tipo == 'ESTADO_COMPLETO' ||
        tipo == 'TOMA_CONFIRMADA' ||
        tipo == 'TOMA_ESQUECIDA' ||
        tipo == 'NOVO_INFORME') {
      final uid = payload['pacienteUid'] as String?;
      final token = payload['tokenPaciente'] as String?;
      if (uid != null && token != null) {
        await _db.gardarPacienteCoidador(uid: uid, token: token, nome: payload['nome'] as String?, payload: payload);
        final hora = payload['horaToma'] as String?;
        if (hora != null) {
          final nomePaciente = (payload['nome'] as String?) ?? 'Persoa supervisada';
          final hoxe = DateTime.now().toIso8601String().substring(0, 10);
          final datasConToma = (payload['datasConToma'] as List?)
                  ?.whereType<String>()
                  .toList() ??
              <String>[];
          if (datasConToma.isEmpty &&
              PlanificadorRecordatorios.eDoseTomable(payload['doseHoxe'])) {
            datasConToma.add(hoxe);
          }
          final estadoHoxe = payload['estadoHoxe'] as String?;
          await LocalNotificationService().programarTomas(
            identificador: 'coidador_$uid',
            nome: nomePaciente,
            hora: hora,
            datasConToma: datasConToma,
            estados: estadoHoxe == null ? const {} : {hoxe: estadoHoxe},
          );
        }
        _actualizacions.add('coidador:$uid');
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
        await LocalNotificationService().programarTomasPaciente(
          nome: nome ?? '',
          hora: hora,
        );
      }
      await notificarCoidador('ESTADO_COMPLETO');
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
          (d) =>
              !d.eControl &&
              PlanificadorRecordatorios.eDoseTomable(d.dose),
        )
        .toList();
    bool eTomada(String? estado) => estado == 'TOMADA' || estado == 'TOMADA_FORA_HORA';
    final tomadas = tomables.where((d) => eTomada(estados[d.data])).length;
    final esquecidas = tomables.where((d) => !eTomada(estados[d.data]) && d.data.compareTo(hoxe) < 0).length;
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
      'historico': historico.map((h) => {
        'data': h.data,
        'inr': h.inr,
        'dose': h.dose,
      }).toList(),
      'diasTomados': tomadas,
      'diasNonTomados': esquecidas,
      'cumprimento': decididas == 0 ? 0 : (tomadas * 100 / decididas).round(),
      'actualizadoEn': DateTime.now().toIso8601String(),
    };
  }

  Future<void> enviarEstadoCompleto(String tokenDestino, {String tipo = 'ESTADO_COMPLETO'}) async {
    final resumo = await crearResumoPaciente();
    await _api.enviarNotificacion(tokenDestino: tokenDestino, payload: jsonEncode(resumo), tipoAviso: tipo);
  }

  Future<void> notificarCoidador(String tipo) async {
    for (final token in await _tokensCoidadores()) {
      await enviarEstadoCompleto(token, tipo: tipo);
    }
  }

  Future<List<String>> _tokensCoidadores() async {
    final raw = await _storage.read(key: 'tokens_coidadores');
    final legacy = await _storage.read(key: 'token_coidador');
    final tokens = <String>[];
    if (raw != null) {
      try {
        tokens.addAll((jsonDecode(raw) as List).whereType<String>());
      } catch (_) {}
    }
    if (legacy != null && legacy.isNotEmpty && !tokens.contains(legacy)) tokens.add(legacy);
    return tokens;
  }

  Future<void> solicitarSincronizacion() async {
    final pacientes = await _db.obterPacientesCoidador();
    final meuToken = await FirebaseMessaging.instance.getToken();
    if (meuToken == null) return;
    for (final paciente in pacientes) {
      await _api.enviarNotificacion(
        tokenDestino: paciente['token'] as String,
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
      throw Exception('Non se puido identificar este dispositivo coidador');
    }
    final enviada = await _api.enviarNotificacion(
      tokenDestino: tokenPaciente,
      payload: jsonEncode({'tokenCoidador': meuToken}),
      tipoAviso: 'DESVINCULAR_COIDADOR',
    );
    if (!enviada) throw Exception('Non se puido avisar ao paciente da desvinculación');
    await _db.eliminarPacienteCoidador(uid);
    await LocalNotificationService().cancelarTomas('coidador_$uid');
    _actualizacions.add('coidador:$uid');
  }

  Future<void> enviarConfiguracionPaciente({
    required String tokenPaciente,
    required String nome,
    required String horaToma,
  }) async {
    await _api.enviarNotificacion(
      tokenDestino: tokenPaciente,
      payload: jsonEncode({'nome': nome, 'horaToma': horaToma}),
      tipoAviso: 'CONFIGURACION_ACTUALIZADA',
    );
  }

  Future<void> enviarInformeRemoto(AnaliseModel analise, String tokenPaciente) async {
    final json = jsonEncode({
      'cabeceira': {
        'dataInforme': analise.cabeceira.dataInforme, 'inr': analise.cabeceira.inr,
        'farmaco': analise.cabeceira.farmaco, 'doseSemanal': analise.cabeceira.doseSemanal,
        'proximaVisita': analise.cabeceira.proximaVisita, 'centro': analise.cabeceira.centro,
      },
      'calendario': analise.calendario.map((d) => {
        'data': d.data, 'dia': d.dia, 'dose': d.dose, 'accion': d.accion,
        'eControl': d.eControl, 'diaSemanaTexto': d.diaSemanaTexto,
      }).toList(),
      'historico': analise.historico.map((h) => {
        'data': h.data, 'inr': h.inr, 'farmaco': h.farmaco, 'dose': h.dose,
        'apttInyectable': h.apttInyectable, 'doseInyectable': h.doseInyectable,
        'proximaVisita': h.proximaVisita, 'comentarios': h.comentarios,
      }).toList(),
    });
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    const tamanho = 2200;
    final total = (json.length / tamanho).ceil();
    for (var i = 0; i < total; i++) {
      final fin = (i + 1) * tamanho > json.length ? json.length : (i + 1) * tamanho;
      await _api.enviarNotificacion(
        tokenDestino: tokenPaciente,
        payload: jsonEncode({'id': id, 'indice': i, 'total': total, 'datos': json.substring(i * tamanho, fin)}),
        tipoAviso: 'INFORME_FRAGMENTO',
      );
    }
  }

  Future<void> _procesarFragmentoInforme(Map<String, dynamic> payload) async {
    final id = payload['id'].toString();
    final indice = payload['indice'] as int;
    final total = payload['total'] as int;
    await _storage.write(key: 'informe_${id}_$indice', value: payload['datos'] as String);
    final partes = <String>[];
    for (var i = 0; i < total; i++) {
      final parte = await _storage.read(key: 'informe_${id}_$i');
      if (parte == null) return;
      partes.add(parte);
    }
    final analise = AnaliseModel.fromJson(jsonDecode(partes.join()) as Map<String, dynamic>);
    await _db.gardarAnalise(analise);
    final hora = await _storage.read(key: 'hora_toma');
    if (hora != null) {
      await LocalNotificationService().programarTomasPaciente(
        nome: await _storage.read(key: 'nome_usuario') ?? '',
        hora: hora,
      );
    }
    for (var i = 0; i < total; i++) {
      await _storage.delete(key: 'informe_${id}_$i');
    }
    await notificarCoidador('NOVO_INFORME');
    _actualizacions.add('paciente_local');
  }

  Map<String, dynamic>? _jsonOuNull(String valor) {
    try { return jsonDecode(valor) as Map<String, dynamic>; } catch (_) { return null; }
  }
}
