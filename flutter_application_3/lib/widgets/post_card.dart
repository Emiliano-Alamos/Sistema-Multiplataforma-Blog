import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../theme/app_theme.dart';
import '../utils/image_url.dart';

/// Tarjeta de una publicación en la lista del blog: imagen, etiquetas,
/// título, autor, descripción corta y botón para abrirla.
class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback onTap; // acción al tocar la tarjeta o el botón
  final String textoBoton; // «Leer publicación» o «Ver publicación» (modo edición)

  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.textoBoton = 'Leer publicación',
  });

  /// Recuadro con ícono que se muestra si no hay imagen o no se pudo cargar.
  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.primaryTint,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 40,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Separa las etiquetas guardadas como «IA, Robótica» en una lista.
    final etiquetas = post.tags
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // InkWell hace que toda la tarjeta responda al toque.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                // Imagen en proporción 16:9; si falla la carga, se muestra el recuadro.
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: post.imagen.trim().isNotEmpty
                      ? Image.network(
                          urlImagen(post.imagen),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholder();
                          },
                        )
                      : _buildPlaceholder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Etiquetas como chips.
                  if (etiquetas.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: etiquetas
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTint,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(tag, style: textTheme.labelSmall),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(post.titulo, style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  // Autor de la publicación.
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          post.textoAutor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Descripción recortada a 3 líneas.
                  Text(
                    post.descripcion,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  // Botón para abrir la publicación.
                  TextButton.icon(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(
                      Icons.article_outlined,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                    label: Text(textoBoton),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
