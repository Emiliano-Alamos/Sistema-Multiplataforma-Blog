import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart'; // API ÚNICA
import 'sesion.dart'; // SESIONES S3

typedef JsonMap = Map<String, dynamic>;

class AuthService {
  static String get baseUrl => ApiConfig.baseUrl; // API ÚNICA

  String? validarLogin({required String usuario, required String password}) {
    if (usuario.trim().isEmpty || password.isEmpty) {
      return 'Ingresa tu correo y contraseña';
    }
    return null;
  }

  String? validarRegistro({
    required String nombre,
    required String correo,
    required String password,
    required String confirmarpassword,
  }) {
    if (nombre.isEmpty ||
        correo.isEmpty ||
        password.isEmpty ||
        confirmarpassword.isEmpty) {
      return 'Completa todos los campos';
    }

    if (!correo.contains('@')) {
      return 'Ingresa un correo válido';
    }

    if (password.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }

    if (password != confirmarpassword) {
      return 'Las contraseñas no coinciden';
    }

    return null;
  }

  Future<JsonMap> registrarUsuario({
    required String nombre,
    required String correo,
    required String password,
    String? direccion,
    int tipoUsuario = 2, // SESIONES S3
  }) async {
    final respuesta = await http
        .post(
          Uri.parse('$baseUrl/usuarios'),
          headers: Sesion.encabezados(), // SESIONES S3
          body: jsonEncode({
            'nom_usr': nombre.trim(),
            'mail': correo.trim().toLowerCase(),
            'password': password,
            'dir_usr': direccion,
            'tip_usu': tipoUsuario,
          }),
        )
        .timeout(const Duration(seconds: 10));

    Sesion.revisar(respuesta); // SESIONES S3

    final dynamic resultado = respuesta.body.isNotEmpty
        ? jsonDecode(respuesta.body)
        : null;

    if ((respuesta.statusCode == 200 || respuesta.statusCode == 201) &&
        resultado is JsonMap) {
      return resultado;
    }

    if (resultado is Map && resultado['detail'] != null) {
      throw Exception(resultado['detail'].toString());
    }

    throw Exception(
      'No se pudo registrar el usuario (HTTP ${respuesta.statusCode})',
    );
  }

  Future<JsonMap> autenticar({
    required String correo,
    required String password,
  }) async {
    final respuesta = await http
        .post(
          Uri.parse('$baseUrl/login'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'mail': correo.trim().toLowerCase(),
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 10));

    final dynamic resultado = jsonDecode(respuesta.body);

    if (respuesta.statusCode == 200 && resultado is JsonMap) {
      // SESIONES S3: la API devuelve el token y los datos del usuario.
      Sesion.iniciar(resultado['access_token'] as String);
      return JsonMap.from(resultado['usuario'] as Map);
    }

    if (respuesta.statusCode == 401) {
      throw Exception('Correo o contraseña incorrectos');
    }

    if (resultado is Map && resultado['detail'] != null) {
      throw Exception(resultado['detail'].toString());
    }

    throw Exception('Error al iniciar sesión: HTTP ${respuesta.statusCode}');
  }
}
