import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'sesion.dart';

typedef JsonMap = Map<String, dynamic>;

/// Servicio de autenticación: valida formularios, registra usuarios e inicia sesión.
class AuthService {
  /// Dirección de la API, tomada de la configuración central.
  static String get baseUrl => ApiConfig.baseUrl;

  /// Revisa que el login tenga correo y contraseña antes de llamar a la API.
  /// Devuelve el mensaje de error o null si todo está bien.
  String? validarLogin({required String usuario, required String password}) {
    if (usuario.trim().isEmpty || password.isEmpty) {
      return 'Ingresa tu correo y contraseña';
    }
    return null;
  }

  /// Revisa los campos del registro antes de llamar a la API: que no estén
  /// vacíos, el formato del correo, el largo de la contraseña y la confirmación.
  /// Devuelve el mensaje de error o null si todo está bien.
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

  /// Registra un usuario en la API (POST /usuarios).
  /// Si quien registra es un administrador, su token viaja en los encabezados
  /// y la API respeta el tipo de usuario elegido.
  Future<JsonMap> registrarUsuario({
    required String nombre,
    required String correo,
    required String password,
    String? direccion,
    int tipoUsuario = 2, // por omisión, Usuario general
  }) async {
    final respuesta = await http
        .post(
          Uri.parse('$baseUrl/usuarios'),
          headers: Sesion.encabezados(), // incluye el token si hay sesión
          body: jsonEncode({
            'nom_usr': nombre.trim(),
            'mail': correo.trim().toLowerCase(),
            'password': password,
            'dir_usr': direccion,
            'tip_usu': tipoUsuario,
          }),
        )
        .timeout(const Duration(seconds: 10)); // evita esperar indefinidamente

    Sesion.revisar(respuesta); // renueva el token o manda al login si venció

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

  /// Inicia sesión (POST /login). Si es correcto, guarda el token y
  /// devuelve los datos del usuario.
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
      // La API devuelve el token y los datos del usuario.
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
