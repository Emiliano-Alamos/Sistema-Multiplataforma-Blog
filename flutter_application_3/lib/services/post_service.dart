import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/post_model.dart';
import 'sesion.dart';

typedef PostList = List<PostModel>;
typedef JsonMap = Map<String, dynamic>;

/// Servicio de publicaciones: crear, consultar, editar y eliminar,
/// con o sin fotografía.
class PostService {
  /// Dirección de la API, tomada de la configuración central.
  static String get baseUrl => ApiConfig.baseUrl;

  /// Crea una publicación sin fotografía (POST /blog, datos en JSON).
  Future<PostModel> agregarPost({
    required String titulo,
    required String descripcion,
    String? imagen,
    String? tags,
  }) async {
    final respuesta = await http
        .post(
          Uri.parse('$baseUrl/blog'),
          headers: Sesion.encabezados(), // incluye el token de la sesión
          body: jsonEncode({
            'titulo': titulo.trim(),
            'descripcion': descripcion.trim(),
            'img': (imagen ?? '').trim().isEmpty ? null : imagen!.trim(),
            'tags': (tags ?? '').trim().isEmpty ? null : tags!.trim(),
          }),
        )
        .timeout(const Duration(seconds: 10)); // evita esperar indefinidamente

    Sesion.revisar(respuesta); // renueva el token o manda al login si venció

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

  /// Crea una publicación con fotografía (POST /blog/foto).
  /// Usa multipart porque un archivo no puede enviarse dentro de JSON.
  Future<void> agregarPostConFoto({
    required String titulo,
    required String descripcion,
    required Uint8List imagenBytes,
    required String nombreArchivo,
    String? tags,
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

    // La etiqueta solo se envía si tiene texto.
    if ((tags ?? '').trim().isNotEmpty) {
      peticion.fields['tags'] = tags!.trim();
    }

    // En multipart no se envía Content-Type manual: lo arma el paquete http.
    peticion.headers.addAll(Sesion.encabezados(json: false));

    // Envía la petición y convierte la respuesta en un http.Response normal.
    final respuesta = await http.Response.fromStream(await peticion.send());

    Sesion.revisar(respuesta);

    if (respuesta.statusCode != 200) {
      throw Exception(
        'No se pudo guardar la fotografia (HTTP ${respuesta.statusCode}): ${respuesta.body}',
      );
    }
  }

  /// Consulta las publicaciones (GET /blog). q (texto) y etiqueta son
  /// opcionales: solo se agregan a la URL si tienen valor.
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
      ),
      headers: Sesion.encabezados(),
    );

    Sesion.revisar(respuesta);

    if (respuesta.statusCode != 200) {
      throw Exception('Error al consultar publicaciones');
    }

    final List<dynamic> datos = jsonDecode(respuesta.body);

    return datos.map((json) => PostModel.fromJson(json as JsonMap)).toList();
  }

  /// Actualiza una publicación con JSON, sin fotografía nueva (PUT /blog/{id}).
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

  /// Actualiza una publicación y le pone una fotografía nueva (PUT /blog/{id}/foto).
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

  /// Toma el mensaje que manda la API ("detail") cuando es un texto.
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

  /// Elimina una publicación y sus comentarios (solo administrador).
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
