import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart'; // API ÚNICA
import '../models/user_model.dart';
import 'sesion.dart'; // SESIONES S4

typedef UserList = List<UserModel>;
typedef JsonMap = Map<String, dynamic>;

class UserService {
  static String get baseUrl => ApiConfig.baseUrl; // API ÚNICA
  Future<UserList> obtenerUsuarios() async {
    final respuesta = await http
        .get(
          Uri.parse('$baseUrl/usuarios'),
          headers: Sesion.encabezados(), // SESIONES S4
        )
        .timeout(const Duration(seconds: 10));

    Sesion.revisar(respuesta); // SESIONES S4

    if (respuesta.statusCode != 200) {
      throw Exception('Error al consultar usuarios: ${respuesta.statusCode}');
    }

    final List<dynamic> datos = jsonDecode(respuesta.body);

    return datos.map((json) => UserModel.fromJson(json as JsonMap)).toList();
  }

  Future<UserModel> actualizarUsuario(UserModel usuario) async {
    final respuesta = await http
        .put(
          Uri.parse('$baseUrl/usuarios/${usuario.id}'),
          headers: Sesion.encabezados(), // SESIONES S4
          body: jsonEncode({
            'nom_usr': usuario.nombre,
            'mail': usuario.correo,
            'dir_usr': usuario.direccion,
            'tip_usu': usuario.tipoUsuario,
          }),
        )
        .timeout(const Duration(seconds: 10));

    Sesion.revisar(respuesta); // SESIONES S4

    if (respuesta.statusCode == 200) {
      return UserModel.fromJson(jsonDecode(respuesta.body) as JsonMap);
    }

    throw Exception(_mensajeError(respuesta));
  }

  Future<void> eliminarUsuario(int id) async {
    final respuesta = await http
        .delete(
          Uri.parse('$baseUrl/usuarios/$id'),
          headers: Sesion.encabezados(), // SESIONES S4
        )
        .timeout(const Duration(seconds: 10));

    Sesion.revisar(respuesta); // SESIONES S4

    if (respuesta.statusCode != 200 && respuesta.statusCode != 204) {
      throw Exception(_mensajeError(respuesta));
    }
  }

  String _mensajeError(http.Response respuesta) {
    try {
      final datos = jsonDecode(respuesta.body);

      if (datos is Map && datos['detail'] != null) {
        return datos['detail'].toString();
      }
    } catch (_) {
      // La respuesta no contiene JSON.
    }

    return 'Error HTTP ${respuesta.statusCode}: ${respuesta.body}';
  }
}
