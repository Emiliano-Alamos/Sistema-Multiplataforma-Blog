import 'package:flutter/material.dart';

import '../models/comentario_model.dart';
import '../models/post_model.dart';
import '../services/comentario_service.dart';
import '../theme/app_theme.dart';
import '../utils/image_url.dart';
import 'add_blog_page.dart';
import 'moderar_comentarios_page.dart';

/// Detalle de una publicación.
/// - Modo normal: muestra la publicación y sus comentarios, y permite comentar.
/// - Modo administrador (modoAdmin): muestra los botones «Editar publicación»
///   y «Moderar comentarios» en lugar de los comentarios.
class PostDetailPage extends StatefulWidget {
  final PostModel post;
  final bool modoAdmin;
  final Map<String, dynamic>? usuario; // usuario con sesión, para pasarlo a Editar

  const PostDetailPage({
    super.key,
    required this.post,
    this.modoAdmin = false,
    this.usuario,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final ComentarioService comentarioService = ComentarioService();
  final TextEditingController _textoComentario = TextEditingController();
  Future<List<ComentarioModel>>? futureComentarios; // consulta de comentarios
  bool _enviando = false; // true mientras se publica un comentario

  @override
  // Al abrir la pantalla se piden los comentarios (solo en modo normal).
  void initState() {
    super.initState();

    // En modo administrador esta pantalla no muestra comentarios.
    if (!widget.modoAdmin) {
      futureComentarios = comentarioService.obtenerComentarios(widget.post.id);
    }
  }

  @override
  // Libera el controlador del campo de comentario.
  void dispose() {
    _textoComentario.dispose();
    super.dispose();
  }

  /// Vuelve a consultar los comentarios; setState redibuja la pantalla.
  void _recargarComentarios() {
    setState(() {
      futureComentarios = comentarioService.obtenerComentarios(widget.post.id);
    });
  }

  /// Valida el texto, envía el comentario a la API, cierra el diálogo y
  /// recarga la lista. El autor lo pone la API a partir del token.
  Future<void> _publicarComentario(BuildContext dialogContext) async {
    // Evita que un doble toque publique el comentario dos veces.
    if (_enviando) return;

    final mensajes = ScaffoldMessenger.of(context);
    final texto = _textoComentario.text.trim();

    if (texto.isEmpty) {
      mensajes.showSnackBar(
        const SnackBar(
          content: Text('Escribe tu comentario antes de publicarlo.'),
        ),
      );
      return;
    }

    _enviando = true;

    try {
      await comentarioService.agregarComentario(
        blogId: widget.post.id,
        texto: texto,
      );

      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }

      if (!mounted) return;

      mensajes.showSnackBar(
        const SnackBar(content: Text('Comentario publicado.')),
      );

      _recargarComentarios();
    } catch (e) {
      mensajes.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      _enviando = false;
    }
  }

  /// Recuadro con ícono que se muestra si no hay imagen o no se pudo cargar.
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

  /// Abre el diálogo para escribir un comentario.
  void _mostrarFormularioComentario(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Limpia el campo al abrir el diálogo.
    _textoComentario.clear();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryTint,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_comment_outlined,
                          size: 20,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Agregar comentario',
                          style: textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        icon: const Icon(Icons.close_outlined),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Campo del comentario; máximo 1000 caracteres, igual que en la API.
                  TextField(
                    controller: _textoComentario,
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Escribe tu comentario',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 64),
                        child: Icon(Icons.chat_bubble_outline),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _publicarComentario(dialogContext),
                      child: const Text('Publicar comentario'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Botones del administrador: «Editar publicación» y «Moderar comentarios».
  Widget _buildAccionesAdmin(BuildContext context) {
    final botonEditar = SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () async {
          final navegador = Navigator.of(context);

          // Abre el formulario en modo edición con esta publicación.
          final cambio = await navegador.push<bool>(
            MaterialPageRoute<bool>(
              settings: RouteSettings(arguments: widget.usuario ?? {}),
              builder: (_) => AddBlogPage(post: widget.post),
            ),
          );

          // Si se guardaron cambios (true), se regresa a la lista
          // para que vuelva a cargar las publicaciones.
          if (cambio == true) {
            navegador.pop(true);
          }
        },
        icon: const Icon(Icons.edit_outlined, size: 20),
        label: const Text('Editar publicación'),
      ),
    );

    final botonModerar = SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () {
          // Abre la pantalla de moderación de esta publicación.
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ModerarComentariosPage(post: widget.post),
            ),
          );
        },
        // Botón secundario (solo borde).
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          backgroundColor: AppColors.surface,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(
          Icons.forum_outlined,
          size: 20,
          color: AppColors.primaryDark,
        ),
        label: const Text('Moderar comentarios'),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Lado a lado en pantallas de 600 px o más; uno sobre otro en el celular.
        final usarFila = MediaQuery.sizeOf(context).width >= 600;
        if (usarFila) {
          return Row(
            children: [
              Expanded(child: botonEditar),
              const SizedBox(width: 12),
              Expanded(child: botonModerar),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [botonEditar, const SizedBox(height: 12), botonModerar],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final etiquetas = widget.post.tags
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de publicación')),
      // Contenido centrado con ancho máximo, para que se lea bien en Chrome.
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
                  // Imagen de la publicación o recuadro si no tiene.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: widget.post.imagen.trim().isNotEmpty
                          ? Image.network(
                              urlImagen(
                                widget.post.imagen,
                              ),
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
                    const SizedBox(height: 16),
                  ],

                  // Título.
                  Text(widget.post.titulo, style: textTheme.headlineMedium),
                  const SizedBox(height: 8),
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
                          widget.post.textoAutor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Contenido completo.
                  Text(
                    widget.post.descripcion.isNotEmpty
                        ? widget.post.descripcion
                        : 'Esta publicación no tiene descripción.',
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),

                  // Administrador: botones de edición. Usuario: sección de comentarios.
                  if (widget.modoAdmin)
                    _buildAccionesAdmin(context)
                  else
                    // FutureBuilder redibuja la sección según la consulta: cargando, error,
                    // vacía o con comentarios. La sección se puede desplegar y plegar.
                    FutureBuilder<List<ComentarioModel>>(
                      future: futureComentarios,
                      builder: (context, snapshot) {
                        final cargando =
                            snapshot.connectionState == ConnectionState.waiting;
                        final tieneError = snapshot.hasError;
                        final comentarios =
                            (!cargando && !tieneError && snapshot.hasData)
                            ? snapshot.data!
                            : <ComentarioModel>[];

                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: colorScheme.surface.withValues(
                                alpha: 0,
                              ),
                            ),
                            child: ExpansionTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryTint,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.forum_outlined,
                                  size: 20,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Comentarios',
                                      style: textTheme.titleMedium,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryTint,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${comentarios.length}',
                                      style: textTheme.labelSmall,
                                    ),
                                  ),
                                ],
                              ),
                              iconColor: AppColors.primaryDark,
                              collapsedIconColor: AppColors.textSecondary,
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16,
                              ),
                              children: [
                                const Divider(),
                                const SizedBox(height: 16),
                                if (cargando)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const CircularProgressIndicator(),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Cargando comentarios...',
                                            style: textTheme.bodyMedium,
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else if (tieneError)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'No fue posible cargar los comentarios.',
                                            style: textTheme.bodyMedium,
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
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Esta publicación aún no tiene comentarios',
                                        style: textTheme.bodyMedium,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  )
                                else
                                  ...comentarios.map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .scaffoldBackgroundColor,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor:
                                                      AppColors.primaryTint,
                                                  child: Text(
                                                    item.iniciales,
                                                    style: textTheme.labelSmall,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    item.autor,
                                                    style: textTheme.bodyMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: AppColors
                                                              .textPrimary,
                                                        ),
                                                  ),
                                                ),
                                                Text(
                                                  item.fechaCorta,
                                                  style: textTheme.bodyMedium,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              item.comentario,
                                              style: textTheme.bodyLarge,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                // Botón para abrir el diálogo de nuevo comentario.
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _mostrarFormularioComentario(context),
                                    icon: const Icon(
                                      Icons.add_comment_outlined,
                                      size: 20,
                                    ),
                                    label: const Text('Agregar comentario'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
