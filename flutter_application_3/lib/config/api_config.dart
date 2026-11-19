import 'package:flutter/foundation.dart';

// API ÚNICA: dirección de FastAPI en un solo lugar.
//
// Se elige sola según dónde corre la app:
//   - Chrome o Windows (misma computadora que la API): http://127.0.0.1:8000
//   - Emulador de Android: http://10.0.2.2:8000
//     (dentro del emulador, 127.0.0.1 es el propio teléfono; 10.0.2.2 es la
//     computadora donde corre uvicorn).
//
// Para usar otra dirección (por ejemplo, un celular físico en la misma red),
// se indica al ejecutar, sin cambiar el código:
//   flutter run --dart-define=API_URL=http://192.168.1.50:8000
class ApiConfig {
  static const String _urlIndicada = String.fromEnvironment('API_URL');

  static const String _urlLocal = 'http://127.0.0.1:8000';
  static const String _urlEmuladorAndroid = 'http://10.0.2.2:8000';

  static String get baseUrl {
    if (_urlIndicada.isNotEmpty) {
      return _urlIndicada.endsWith('/')
          ? _urlIndicada.substring(0, _urlIndicada.length - 1)
          : _urlIndicada;
    }

    // kIsWeb va primero: en el navegador, defaultTargetPlatform indica el
    // sistema del equipo, no que la app sea nativa de Android.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _urlEmuladorAndroid;
    }

    return _urlLocal;
  }
}
