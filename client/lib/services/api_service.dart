import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/analise_model.dart';

class ApiService{

  //Comprobamos que a API é alcanzable
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
          Uri.parse('${AppConstants.baseUrl}${AppConstants.endpointHealth}') //Formamos a URI  conmpleta co endpoint de health
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
      final response = await http.Response.fromStream(partialResponse);

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
      print("Erro en ApiService (Notificación): $e");
      return false;
    }
  }
}