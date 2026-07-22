import 'dart:convert'; // Servizo de comunicación coa API.
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../nucleo/constantes.dart';
import '../modelos/analise.dart';

class ApiService{

  //Obter a información do centro de sañude.
  Future<Map<String, dynamic>> buscarCentro(String nome) async {
    //Formamos a URI
    final uri = Uri.parse('${AppConstants.baseUrl}${AppConstants.endpointCentro}').replace(queryParameters: {'nome': nome});
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      final data = json.decode(response.body);
      throw Exception(data['detail'] ?? 'Non se puido atopar o centro');
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  //Comprobamos que a API é alcanzable
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
          Uri.parse('${AppConstants.baseUrl}${AppConstants.endpointHealth}')
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  //Enviar o informa a nosa API
  Future<AnaliseModel> enviarInforme(File imageFile) async{
    final url = Uri.parse('${AppConstants.baseUrl}${AppConstants.endpointExtraccion}');

    var request = http.MultipartRequest('POST',url);
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path) //Indicamos a ruta da imaxe apra non ter que cargala enteira na RAM
    );

    try{
      final partialResponse = await request.send();
      final response = await http.Response.fromStream(partialResponse); //Agrupamos todas as respostas aprciais

      if(response.statusCode == 200){
        final Map<String, dynamic> data = json.decode(response.body);
        return AnaliseModel.fromJson(data);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail']);
      }
    } catch (e) {
      throw Exception('Erro de conexión: $e');
    }

  }

  Future<bool> enviarNotificacion({
    required String tokenDestino,
    required String payload,
    required String tipoAviso,
  }) async {
    final url = Uri.parse('${AppConstants.baseUrl}${AppConstants.endpointEnviarNotif}');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "token_destino": tokenDestino,
          "payload": payload,
          "tipo_aviso": tipoAviso
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Erro en ApiService (Notificación): $e");
      return false;
    }
  }
}
