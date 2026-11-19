import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart'; // API ÚNICA
import '../models/comentario_model.dart';
import 'sesion.dart';

class ComentarioService {
  static String get baseUrl => ApiConfig.baseUrl; // API ÚNICA

  // COMENTARIOS C2: comentarios visibles de UNA publicación,
  // del más reciente al más antiguo.
  Future<List<ComentarioModel>> obtenerComentarios(int blogId) async {
    final respuesta = await http
        .get(
          Uri.parse('$baseUrl/blog/$blogId/comentarios'),
          headers: Sesion.encabezados(),
        )
        .timeout(const Duration(seconds: 10));

    Sesion.revisar(respuesta);

    if (respuesta.statusCode != 200) {
      throw Exception('No fue posible cargar los comentarios.');
    }

    final List<dynamic> datos = jsonDecode(respuesta.body);

    return datos
        .map((json) => ComentarioModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // COMENTARIOS C2: crea un comentario. No se envía el usuario: la API
  // lo toma del token de la sesión.
  Future<ComentarioModel> agregarComentario({
    required int blogId,
    required String texto,
  }) async {
    final respuesta = await http
        .post(
          Uri.parse('$baseUrl/comentarios'),
          headers: Sesion.encabezados(),
          body: jsonEncode({'comentario': texto.trim(), 'blog_id': blogId}),
        )
        .timeout(const Duration(seconds: 10));

    Sesion.revisar(respuesta);

    if (respuesta.statusCode == 201) {
      return ComentarioModel.fromJson(
        jsonDecode(respuesta.body) as Map<String, dynamic>,
      );
    }

    throw Exception(_mensajeError(respuesta));
  }

  // Toma el mensaje que manda la API ("detail") cuando es un texto.
  String _mensajeError(http.Response respuesta) {
    try {
      final dynamic datos = jsonDecode(respuesta.body);

      if (datos is Map && datos['detail'] is String) {
        return datos['detail'] as String;
      }
    } catch (_) {
      // La respuesta no era JSON: se usa el mensaje general de abajo.
    }

    return 'No se pudo publicar el comentario (HTTP ${respuesta.statusCode}).';
  }

  // MODERAR D2: TODOS los comentarios de una publicación (solo administrador).
  Future<List<ComentarioModel>> obtenerParaModerar(int blogId) async {
    final respuesta = await http
        .get(
          Uri.parse('$baseUrl/blog/$blogId/comentarios/moderacion'),
          headers: Sesion.encabezados(),
        )
        .timeout(const Duration(seconds: 10));

    Sesion.revisar(respuesta);

    if (respuesta.statusCode != 200) {
      throw Exception('No fue posible cargar los comentarios.');
    }

    final List<dynamic> datos = jsonDecode(respuesta.body);

    return datos
        .map((json) => ComentarioModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // MODERAR D2: elimina un comentario de forma definitiva.
  Future<void> eliminarComentario(int id) async {
    final respuesta = await http
        .delete(
          Uri.parse('$baseUrl/comentarios/$id'),
          headers: Sesion.encabezados(),
        )
        .timeout(const Duration(seconds: 10));

    Sesion.revisar(respuesta);

    if (respuesta.statusCode != 200) {
      throw Exception(
        'No se pudo eliminar el comentario (HTTP ${respuesta.statusCode}).',
      );
    }
  }
}
