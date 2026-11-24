/// Modelo de una publicación del blog tal como la devuelve la API.
class PostModel {
  final int id;
  final String titulo;
  final String descripcion;
  // Ruta de la imagen (/uploads/archivo.jpg) o URL completa; '' si no tiene.
  final String imagen;
  final String tags;
  // Id del autor (null = sin autor) y su nombre ('' = sin autor).
  final int? usuarioId;
  final String autor;

  const PostModel({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.imagen,
    required this.tags,
    this.usuarioId,
    this.autor = '',
  });

  /// Texto del autor listo para mostrar: «Por Nombre» o «Sin autor».
  String get textoAutor => autor.isEmpty ? 'Sin autor' : 'Por $autor';

  /// Convierte el JSON de la API en un PostModel; los campos vacíos quedan como ''.
  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: (json['id_blog'] as num).toInt(),
      titulo: json['titulo']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      imagen: json['img']?.toString() ?? '',
      tags: json['tags']?.toString() ?? '',
      usuarioId: (json['usr_id'] as num?)?.toInt(),
      autor: json['autor']?.toString() ?? '',
    );
  }
}
