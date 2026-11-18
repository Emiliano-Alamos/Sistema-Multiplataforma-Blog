import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/post_model.dart';
import 'sesion.dart'; // SESIONES S5

typedef PostList = List<PostModel>;
typedef JsonMap = Map<String, dynamic>;

class PostService {
  static const String baseUrl = 'http://127.0.0.1:8000';

  // GUARDAR PUBLICACION CON JSON
  Future<PostModel> agregarPost({
    required String titulo,
    required String descripcion,
    String? imagen,
    String? tags,
  }) async {
    final respuesta = await http
        .post(
          Uri.parse('$baseUrl/blog'),
          headers: Sesion.encabezados(), // SESIONES S5
          body: jsonEncode({
            'titulo': titulo.trim(),
            'descripcion': descripcion.trim(),
            'img': (imagen ?? '').trim().isEmpty ? null : imagen!.trim(),
            'tags': (tags ?? '').trim().isEmpty ? null : tags!.trim(),
          }),
        )
        .timeout(const Duration(seconds: 10));

    Sesion.revisar(respuesta); // SESIONES S5

    final dynamic resultado = respuesta.body.isNotEmpty
        ? jsonDecode(respuesta.body)
        : null;

    if ((respuesta.statusCode == 200 || respuesta.statusCode == 201) &&
        resultado is JsonMap) {
      return PostModel.fromJson(resultado);
    }

    if (resultado is Map && resultado['detail'] != null) {
      throw Exception(resultado['detail'].toString());
    }

    throw Exception(
      'No se pudo guardar la publicación (HTTP ${respuesta.statusCode})',
    );
  }

  // ENVIAR PUBLICACION CON FOTOGRAFIA
  Future<void> agregarPostConFoto({
    required String titulo,
    required String descripcion,
    required Uint8List imagenBytes,
    required String nombreArchivo,
    String? tags, // CORRECCIÓN TAGS
  }) async {
    final peticion =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/blog/foto'))
          ..fields['titulo'] = titulo.trim()
          ..fields['descripcion'] = descripcion.trim()
          ..files.add(
            http.MultipartFile.fromBytes(
              'imagen',
              imagenBytes,
              filename: nombreArchivo,
            ),
          );

    // CORRECCIÓN TAGS
    if ((tags ?? '').trim().isNotEmpty) {
      peticion.fields['tags'] = tags!.trim();
    }

    // SESIONES S5: en multipart no se envía Content-Type manual.
    peticion.headers.addAll(Sesion.encabezados(json: false));

    final respuesta = await http.Response.fromStream(await peticion.send());

    Sesion.revisar(respuesta); // SESIONES S5

    if (respuesta.statusCode != 200) {
      throw Exception(
        'No se pudo guardar la fotografia (HTTP ${respuesta.statusCode}): ${respuesta.body}',
      );
    }
  }

  // CONSULTAR PUBLICACIONES
  // AUTORIZADO BUSCADOR: q y etiqueta son opcionales. Si llegan vacíos, la
  // petición es la misma de antes (GET /blog sin parámetros).
  Future<PostList> obtenerPosts({String q = '', String etiqueta = ''}) async {
    final parametros = <String, String>{};
    if (q.trim().isNotEmpty) {
      parametros['q'] = q.trim();
    }
    if (etiqueta.trim().isNotEmpty) {
      parametros['etiqueta'] = etiqueta.trim();
    }

    final respuesta = await http.get(
      Uri.parse('$baseUrl/blog').replace(
        queryParameters: parametros.isEmpty ? null : parametros,
      ), // AUTORIZADO BUSCADOR
      headers: Sesion.encabezados(), // SESIONES S5
    );

    Sesion.revisar(respuesta); // SESIONES S5

    if (respuesta.statusCode != 200) {
      throw Exception('Error al consultar publicaciones');
    }

    final List<dynamic> datos = jsonDecode(respuesta.body);

    return datos.map((json) => PostModel.fromJson(json as JsonMap)).toList();
  }

  // EDITAR D1: actualiza una publicación con JSON (sin fotografía nueva).
  Future<PostModel> actualizarPost({
    required int id,
    required String titulo,
    required String descripcion,
    String? imagen,
    String? tags,
  }) async {
    final respuesta = await http
        .put(
          Uri.parse('$baseUrl/blog/$id'),
          headers: Sesion.encabezados(),
          body: jsonEncode({
            'titulo': titulo.trim(),
            'descripcion': descripcion.trim(),
            'img': (imagen ?? '').trim().isEmpty ? null : imagen!.trim(),
            'tags': (tags ?? '').trim().isEmpty ? null : tags!.trim(),
          }),
        )
        .timeout(const Duration(seconds: 10));

    Sesion.revisar(respuesta);

    if (respuesta.statusCode == 200) {
      return PostModel.fromJson(
        jsonDecode(respuesta.body) as Map<String, dynamic>,
      );
    }

    throw Exception(_mensajeErrorEdicion(respuesta));
  }

  // EDITAR D1: actualiza una publicación y le pone una fotografía nueva.
  Future<PostModel> actualizarPostConFoto({
    required int id,
    required String titulo,
    required String descripcion,
    required Uint8List imagenBytes,
    required String nombreArchivo,
    String? tags,
  }) async {
    final peticion =
        http.MultipartRequest('PUT', Uri.parse('$baseUrl/blog/$id/foto'))
          ..fields['titulo'] = titulo.trim()
          ..fields['descripcion'] = descripcion.trim()
          ..files.add(
            http.MultipartFile.fromBytes(
              'imagen',
              imagenBytes,
              filename: nombreArchivo,
            ),
          );

    if ((tags ?? '').trim().isNotEmpty) {
      peticion.fields['tags'] = tags!.trim();
    }

    // En multipart no se envía Content-Type manual.
    peticion.headers.addAll(Sesion.encabezados(json: false));

    final respuesta = await http.Response.fromStream(await peticion.send());

    Sesion.revisar(respuesta);

    if (respuesta.statusCode == 200) {
      return PostModel.fromJson(
        jsonDecode(respuesta.body) as Map<String, dynamic>,
      );
    }

    throw Exception(_mensajeErrorEdicion(respuesta));
  }

  // Toma el mensaje que manda la API ("detail") cuando es un texto.
  String _mensajeErrorEdicion(http.Response respuesta) {
    try {
      final dynamic datos = jsonDecode(respuesta.body);

      if (datos is Map && datos['detail'] is String) {
        return datos['detail'] as String;
      }
    } catch (_) {
      // La respuesta no era JSON: se usa el mensaje general de abajo.
    }

    return 'No se pudo guardar la publicación (HTTP ${respuesta.statusCode}).';
  }

  // ELIMINAR D7: elimina una publicación y sus comentarios (solo administrador).
  Future<void> eliminarPost(int id) async {
    final respuesta = await http
        .delete(Uri.parse('$baseUrl/blog/$id'), headers: Sesion.encabezados())
        .timeout(const Duration(seconds: 10));

    Sesion.revisar(respuesta);

    if (respuesta.statusCode != 200) {
      throw Exception(
        'No se pudo eliminar la publicación (HTTP ${respuesta.statusCode}).',
      );
    }
  }
}
