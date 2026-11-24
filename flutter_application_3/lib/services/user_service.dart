import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/user_model.dart';
import 'sesion.dart';

typedef UserList = List<UserModel>;
typedef JsonMap = Map<String, dynamic>;

/// Servicio de usuarios para el administrador: listar, editar y eliminar.
class UserService {
  /// Dirección de la API, tomada de la configuración central.
  static String get baseUrl => ApiConfig.baseUrl;

  /// Consulta todos los usuarios (solo administrador).
  /// Devuelve la lista como UserModel o lanza un error con el código HTTP.
  Future<UserList> obtenerUsuarios() async {
    final respuesta = await http
        .get(
          Uri.parse('$baseUrl/usuarios'),
          headers: Sesion.encabezados(), // incluye el token de la sesión
        )
        .timeout(const Duration(seconds: 10)); // evita esperar indefinidamente

    Sesion.revisar(respuesta); // renueva el token o manda al login si venció

    if (respuesta.statusCode != 200) {
      throw Exception('Error al consultar usuarios: ${respuesta.statusCode}');
    }

    final List<dynamic> datos = jsonDecode(respuesta.body);

    return datos.map((json) => UserModel.fromJson(json as JsonMap)).toList();
  }

  /// Actualiza nombre, correo, dirección y rol de un usuario (PUT /usuarios/{id}).
  Future<UserModel> actualizarUsuario(UserModel usuario) async {
    final respuesta = await http
        .put(
          Uri.parse('$baseUrl/usuarios/${usuario.id}'),
          headers: Sesion.encabezados(),
          body: jsonEncode({
            'nom_usr': usuario.nombre,
            'mail': usuario.correo,
            'dir_usr': usuario.direccion,
            'tip_usu': usuario.tipoUsuario,
          }),
        )
        .timeout(const Duration(seconds: 10));

    Sesion.revisar(respuesta);

    if (respuesta.statusCode == 200) {
      return UserModel.fromJson(jsonDecode(respuesta.body) as JsonMap);
    }

    throw Exception(_mensajeError(respuesta));
  }

  /// Elimina un usuario y sus comentarios (solo administrador).
  Future<void> eliminarUsuario(int id) async {
    final respuesta = await http
        .delete(
          Uri.parse('$baseUrl/usuarios/$id'),
          headers: Sesion.encabezados(),
        )
        .timeout(const Duration(seconds: 10));

    Sesion.revisar(respuesta);

    if (respuesta.statusCode != 200 && respuesta.statusCode != 204) {
      throw Exception(_mensajeError(respuesta));
    }
  }

  /// Toma el mensaje que manda la API ("detail") o arma uno con el código HTTP.
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
