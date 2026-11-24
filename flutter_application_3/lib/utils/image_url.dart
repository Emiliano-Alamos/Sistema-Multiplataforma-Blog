import '../services/post_service.dart';

/// Convierte la ruta de imagen guardada en la base (/uploads/foto.jpg)
/// en una dirección completa que la app puede cargar
/// (http://127.0.0.1:8000/uploads/foto.jpg). Corrige también las barras
/// invertidas de Windows.
String urlImagen(String ruta) {
  final limpia = ruta.trim().replaceAll('\\', '/');

  // Si no existe una imagen, regresamos un texto vacío
  if (limpia.isEmpty) {
    return '';
  }

  // Conservamos las imágenes que ya tienen una URL completa
  if (limpia.startsWith('http://') || limpia.startsWith('https://')) {
    return limpia;
  }

  // Obtenemos la dirección de FastAPI
  final base = PostService.baseUrl.endsWith('/')
      ? PostService.baseUrl.substring(0, PostService.baseUrl.length - 1)
      : PostService.baseUrl;

  String rutaFinal = limpia;

  // Buscamos la carpeta uploads dentro de la ruta
  final posicion = limpia.indexOf('uploads/');

  if (posicion >= 0) {
    rutaFinal = '/${limpia.substring(posicion)}';
  } else if (!limpia.startsWith('/') && !limpia.contains('/')) {
    // Si solo tenemos el nombre, agregamos uploads
    rutaFinal = '/uploads/$limpia';
  } else if (!limpia.startsWith('/')) {
    rutaFinal = '/$limpia';
  }

  // Devolvemos la dirección completa de la fotografía
  return '$base$rutaFinal';
}
