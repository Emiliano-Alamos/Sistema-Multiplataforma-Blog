import 'package:flutter/material.dart';

import '../models/comentario_model.dart';
import '../models/post_model.dart';
import '../services/comentario_service.dart';
import '../theme/app_theme.dart';

/// Pantalla del administrador para moderar los comentarios de una publicación:
/// muestra todos y permite eliminarlos de forma definitiva.
class ModerarComentariosPage extends StatefulWidget {
  final PostModel post;

  const ModerarComentariosPage({super.key, required this.post});

  @override
  State<ModerarComentariosPage> createState() => _ModerarComentariosPageState();
}

class _ModerarComentariosPageState extends State<ModerarComentariosPage> {
  final ComentarioService comentarioService = ComentarioService();
  late Future<List<ComentarioModel>> futureComentarios; // consulta en curso

  @override
  // Al abrir la pantalla se piden los comentarios a la API.
  void initState() {
    super.initState();
    futureComentarios = comentarioService.obtenerParaModerar(widget.post.id);
  }

  /// Vuelve a consultar los comentarios; setState redibuja la pantalla.
  void _recargarComentarios() {
    setState(() {
      futureComentarios = comentarioService.obtenerParaModerar(widget.post.id);
    });
  }

  /// Elimina el comentario en la API y recarga la lista.
  Future<void> _eliminarComentario(int id) async {
    final mensajes = ScaffoldMessenger.of(context);

    try {
      await comentarioService.eliminarComentario(id);

      if (!mounted) return;

      mensajes.showSnackBar(
        const SnackBar(content: Text('Comentario eliminado.')),
      );

      _recargarComentarios();
    } catch (e) {
      mensajes.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  /// Pide confirmación antes de eliminar; solo elimina si se acepta.
  Future<void> _confirmarEliminar(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final tema = Theme.of(dialogContext);
        final colores = tema.colorScheme;

        return AlertDialog(
          title: const Text('Eliminar comentario'),
          content: const Text('¿Estás seguro de eliminar este comentario?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                minimumSize: const Size(0, 48),
              ),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              // Botón en rojo porque la acción no se puede deshacer.
              style: ElevatedButton.styleFrom(
                backgroundColor: colores.error,
                foregroundColor: colores.onError,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar == true && mounted) {
      await _eliminarComentario(id);
    }
  }

  /// Mensaje que se muestra cuando la publicación no tiene comentarios.
  Widget _buildEstadoVacio(ThemeData tema) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.forum_outlined,
                size: 32,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Esta publicación aún no tiene comentarios',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Moderar comentarios')),
      // FutureBuilder redibuja la pantalla según avanza la consulta a la API.
      body: FutureBuilder<List<ComentarioModel>>(
        future: futureComentarios,
        builder: (context, snapshot) {
          final cargando = snapshot.connectionState == ConnectionState.waiting;
          final tieneError = snapshot.hasError;
          final comentarios = (!cargando && !tieneError && snapshot.hasData)
              ? snapshot.data!
              : <ComentarioModel>[];
          // Texto del contador: «1 comentario» o «N comentarios».
          final cantidad = comentarios.length;
          final textoCantidad = cantidad == 1
              ? '1 comentario'
              : '$cantidad comentarios';

          return Center(
            // Contenido centrado con ancho máximo, para que se vea bien en Chrome.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Encabezado con el título de la publicación y el total de comentarios.
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            color: AppColors.primaryDark,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Comentarios de ${widget.post.titulo}',
                                style: tema.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                textoCantidad,
                                style: tema.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Según el estado de la consulta: cargando, error, vacío o la lista.
                  if (cargando)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              'Cargando comentarios...',
                              style: tema.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (tieneError)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No fue posible cargar los comentarios.',
                              style: tema.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _recargarComentarios,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (comentarios.isEmpty)
                    _buildEstadoVacio(tema)
                  else
                    ...comentarios.map((item) {
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 12),
                        color: colores.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: colores.outline),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Círculo con las iniciales del autor.
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.primaryTint,
                                child: Text(
                                  item.iniciales,
                                  style: tema.textTheme.titleSmall?.copyWith(
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Nombre del autor y fecha del comentario.
                                              Text(
                                                item.autor,
                                                style: tema
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                item.fechaCorta,
                                                style: tema.textTheme.bodySmall
                                                    ?.copyWith(
                                                      fontSize: 14,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Botón para eliminar este comentario (pide confirmación).
                                        IconButton(
                                          onPressed: () =>
                                              _confirmarEliminar(item.id),
                                          tooltip: 'Eliminar comentario',
                                          constraints: const BoxConstraints(
                                            minWidth: 48,
                                            minHeight: 48,
                                          ),
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: colores.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Texto del comentario.
                                    Text(
                                      item.comentario,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: tema.textTheme.bodyLarge?.copyWith(
                                        color: AppColors.textPrimary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
