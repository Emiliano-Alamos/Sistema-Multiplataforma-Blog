class ComentarioModel {
  final int id;
  final String comentario;
  final String fecha;
  final int estatus;
  final int usuarioId;
  final int blogId;
  // COMENTARIOS C1: nombre de quien escribió el comentario.
  final String autor;

  ComentarioModel({
    required this.id,
    required this.comentario,
    required this.fecha,
    required this.estatus,
    required this.usuarioId,
    required this.blogId,
    this.autor = 'Usuario',
  });

  // COMENTARIOS C1: iniciales del autor para el círculo (avatar).
  String get iniciales {
    final partes = autor
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (partes.isEmpty) return 'U';

    if (partes.length == 1) {
      return partes[0].substring(0, 1).toUpperCase();
    }

    return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
  }

  // COMENTARIOS C1: la API manda la fecha como 2026-11-16T18:30:00.
  // Aquí se convierte a 16/11/2026 18:30 para mostrarla.
  String get fechaCorta {
    final f = DateTime.tryParse(fecha);

    if (f == null) return fecha;

    String dos(int n) => n.toString().padLeft(2, '0');

    return '${dos(f.day)}/${dos(f.month)}/${f.year} '
        '${dos(f.hour)}:${dos(f.minute)}';
  }

  factory ComentarioModel.fromJson(Map<String, dynamic> json) {
    return ComentarioModel(
      id: (json['id_com'] as num).toInt(),
      comentario: json['comentario']?.toString() ?? '',
      fecha: json['fecha']?.toString() ?? '',
      estatus: (json['estatus'] as num).toInt(),
      usuarioId: (json['usr_id'] as num).toInt(),
      blogId: (json['blog_id'] as num).toInt(),
      autor: json['autor']?.toString() ?? 'Usuario',
    );
  }
}
