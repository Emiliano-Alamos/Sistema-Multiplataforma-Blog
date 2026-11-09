import '../services/post_service.dart';

// LÓGICA AUTORIZADA 1
String urlImagen(String ruta) {
  final limpia = ruta.trim();
  if (limpia.isEmpty) return '';
  if (limpia.startsWith('http://') || limpia.startsWith('https://')) {
    return limpia;
  }
  final base = PostService.baseUrl.endsWith('/')
      ? PostService.baseUrl.substring(0, PostService.baseUrl.length - 1)
      : PostService.baseUrl;
  final path = limpia.startsWith('/') ? limpia : '/$limpia';
  return '$base$path';
}
