import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/post_model.dart';

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
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'titulo': titulo.trim(),
            'descripcion': descripcion.trim(),
            'img': (imagen ?? '').trim().isEmpty ? null : imagen!.trim(),
            'tags': (tags ?? '').trim().isEmpty ? null : tags!.trim(),
          }),
        )
        .timeout(const Duration(seconds: 10));

    final dynamic resultado = respuesta.body.isNotEmpty
        ? jsonDecode(respuesta.body)
        : null;

    if ((respuesta.statusCode == 200 || respuesta.statusCode == 201) &&
        resultado is Map<String, dynamic>) {
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
    required String tags,
    required Uint8List imagenBytes,
    required String nombreArchivo,
  }) async {
    final peticion =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/blog/foto'))
          ..fields['titulo'] = titulo.trim()
          ..fields['descripcion'] = descripcion.trim()
          ..fields['tags'] = tags.trim()
          ..files.add(
            http.MultipartFile.fromBytes(
              'imagen',
              imagenBytes,
              filename: nombreArchivo,
            ),
          );

    final respuesta = await http.Response.fromStream(await peticion.send());

    if (respuesta.statusCode != 200) {
      throw Exception(
        'No se pudo guardar la fotografia (HTTP ${respuesta.statusCode}): ${respuesta.body}',
      );
    }
  }

  // CONSULTAR PUBLICACIONES
  Future<List<PostModel>> obtenerPosts() async {
    final respuesta = await http.get(Uri.parse('$baseUrl/blog'));

    if (respuesta.statusCode != 200) {
      throw Exception('Error al consultar publicaciones');
    }

    final List<dynamic> datos = jsonDecode(respuesta.body);

    return datos
        .map((json) => PostModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
