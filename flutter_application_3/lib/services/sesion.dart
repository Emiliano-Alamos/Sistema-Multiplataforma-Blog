import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

typedef NavKey = GlobalKey<NavigatorState>;
typedef HeaderMap = Map<String, String>;

/// Maneja la sesión del usuario en la app: guarda el token EN MEMORIA,
/// arma los encabezados de cada petición y revisa cada respuesta de la API.
/// Si se cierra o se recarga la app, el token se pierde y hay que volver a
/// iniciar sesión.
class Sesion {
  // El token que entregó la API al iniciar sesión (null = sin sesión).
  static String? _token;

  // Llave para poder regresar al login desde un servicio, sin BuildContext.
  static final NavKey navegadorKey = NavKey();

  /// Guarda el token. Se llama después de un inicio de sesión correcto.
  static void iniciar(String token) {
    _token = token;
  }

  /// Olvida el token. Se llama al cerrar sesión o cuando la sesión vence.
  static void cerrar() {
    _token = null;
  }

  /// Encabezados para las peticiones. Si hay sesión, agrega
  /// `Authorization: Bearer <token>`.
  /// json: false se usa en las peticiones con fotografía (multipart).
  static HeaderMap encabezados({bool json = true}) {
    final mapa = HeaderMap.from({'Accept': 'application/json'});

    if (json) {
      mapa['Content-Type'] = 'application/json';
    }

    if (_token != null) {
      mapa['Authorization'] = 'Bearer $_token';
    }

    return mapa;
  }

  /// Se llama con CADA respuesta de la API: guarda el token renovado
  /// y, si la sesión venció (401), regresa al login.
  static void revisar(http.Response respuesta) {
    // 1. Renovación por actividad: la API manda un token nuevo con otros
    //    30 minutos. Se reemplaza el que estaba guardado. (Si ya se cerró
    //    la sesión, una respuesta tardía no debe volver a abrirla.)
    final renovado = respuesta.headers['x-token-renovado'];

    if (_token != null && renovado != null && renovado.isNotEmpty) {
      _token = renovado;
    }

    // 2. Sin sesión, sesión vencida o no válida (401): se olvida el token
    //    y se regresa al login. También cubre la recarga de la página (F5),
    //    donde el token en memoria ya no existe.
    if (respuesta.statusCode == 401) {
      cerrar();

      navegadorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );

      throw Exception('Tu sesión expiró. Inicia sesión nuevamente.');
    }
  }
}
