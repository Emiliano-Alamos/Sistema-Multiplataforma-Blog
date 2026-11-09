import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../theme/app_theme.dart'; // REDISEÑO
import '../utils/image_url.dart'; // LÓGICA AUTORIZADA 1

class PostDetailPage extends StatelessWidget {
  final PostModel post;
  const PostDetailPage({
    super.key,
    required this.post,
  });

  // REDISEÑO: Placeholder discreto con fondo primaryTint para imagen ausente o fallida (Sección 6)
  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.primaryTint,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de publicación'),
      ),
      // REDISEÑO: Contenido centrado con ancho máximo de 720 px y padding de 24 px (Secciones 4 y 6)
      body: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // REDISEÑO: Imagen con esquinas redondeadas de radio 12 o placeholder discreto
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
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
                  const SizedBox(height: 16),

                  // REDISEÑO: Etiquetas como chips con fondo primaryTint y texto 12 semibold primaryDark
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
                              child: Text(
                                tag,
                                style: textTheme.labelSmall,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // REDISEÑO: Título de detalle en 28 bold textPrimary (Sección 6)
                  Text(
                    post.titulo,
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),

                  // REDISEÑO: Cuerpo en 16 regular con interlineado 1.5 en textPrimary (Secciones 3 y 6)
                  Text(
                    post.descripcion.isNotEmpty
                        ? post.descripcion
                        : 'Esta publicación no tiene descripción.',
                    style: textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}