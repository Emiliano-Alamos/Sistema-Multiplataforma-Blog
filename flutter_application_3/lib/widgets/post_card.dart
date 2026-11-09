import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../theme/app_theme.dart'; // REDISEÑO
import '../utils/image_url.dart'; // LÓGICA AUTORIZADA 1

class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback onTap;

  const PostCard({super.key, required this.post, required this.onTap});

  // REDISEÑO: Placeholder discreto en proporción 16:9 con fondo primaryTint para imagen ausente o fallida
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
    final textTheme = Theme.of(context).textTheme; // REDISEÑO
    final etiquetas = post.tags
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // REDISEÑO: Tarjeta blanca heredada de cardTheme (radio 12, borde border, elevación 1)
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
                // REDISEÑO: Imagen en proporción 16:9 según Sección 6 y mockup M4
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: post.imagen.trim().isNotEmpty
                      ? Image.network(
                          urlImagen(post.imagen), // LÓGICA AUTORIZADA 1
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
                  // REDISEÑO: Tags como chips con fondo primaryTint, radio 6 y texto 12 semibold primaryDark
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
                  // REDISEÑO: Título de tarjeta 18 semibold en textPrimary (Sección 3)
                  Text(post.titulo, style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  // REDISEÑO: Descripción de hasta 3 líneas en textSecondary (Sección 6)
                  Text(
                    post.descripcion,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  // REDISEÑO: Acción "Leer publicación" como botón de texto en primaryDark con área táctil de 48 px
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
                    label: const Text('Leer publicación'),
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
