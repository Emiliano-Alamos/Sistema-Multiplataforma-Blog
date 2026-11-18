class PostModel {
  final int id;
  final String titulo;
  final String descripcion;
  final String imagen;
  final String tags;
  // AUTOR E1: id del autor (null = sin autor) y su nombre ('' = sin autor).
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

  // AUTOR E1: texto listo para mostrar en pantalla.
  String get textoAutor => autor.isEmpty ? 'Sin autor' : 'Por $autor';

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
