import 'package:flutter/material.dart';

import '../models/comentario_model.dart'; // COMENTARIOS C3
import '../models/post_model.dart';
import '../services/comentario_service.dart'; // COMENTARIOS C3
import '../theme/app_theme.dart'; // REDISEÑO
import '../utils/image_url.dart'; // LÓGICA AUTORIZADA 1
import 'add_blog_page.dart'; // AUTORIZADO MÓDULO EDITAR
import 'moderar_comentarios_page.dart'; // AUTORIZADO MÓDULO EDITAR

// COMENTARIOS C3: De StatelessWidget a StatefulWidget conservando el mismo constructor
class PostDetailPage extends StatefulWidget {
  final PostModel post;
  final bool modoAdmin; // AUTORIZADO MÓDULO EDITAR
  final Map<String, dynamic>? usuario; // AUTORIZADO MÓDULO EDITAR

  const PostDetailPage({
    super.key,
    required this.post,
    this.modoAdmin = false, // AUTORIZADO MÓDULO EDITAR
    this.usuario, // AUTORIZADO MÓDULO EDITAR
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  // COMENTARIOS C3
  final ComentarioService comentarioService = ComentarioService();
  final TextEditingController _textoComentario = TextEditingController();
  Future<List<ComentarioModel>>? futureComentarios;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();

    // En modo administrador esta pantalla no muestra comentarios.
    if (!widget.modoAdmin) {
      futureComentarios = comentarioService.obtenerComentarios(widget.post.id);
    }
  }

  @override
  void dispose() {
    _textoComentario.dispose();
    super.dispose();
  }

  void _recargarComentarios() {
    setState(() {
      futureComentarios = comentarioService.obtenerComentarios(widget.post.id);
    });
  }

  // COMENTARIOS C3: envía el comentario a la API.
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

  // REDISEÑO: Diálogo para agregar comentario con estilo del tema y ancho máx. 400 px
  void _mostrarFormularioComentario(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // COMENTARIOS C3: limpia el campo al abrir el diálogo
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
                  // COMENTARIOS C3: TextField conectado a _textoComentario y con maxLength 1000
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
                      // COMENTARIOS C3: llama a _publicarComentario(dialogContext)
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

  // AUTORIZADO MÓDULO EDITAR: Acciones de administrador (Sección 2.3 y Mockup N2)
  Widget _buildAccionesAdmin(BuildContext context) {
    final botonEditar = SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () async {
          final navegador = Navigator.of(context);

          // AUTORIZADO MÓDULO EDITAR: Navegación a AddBlogPage con post y argumentos de usuario
          final cambio = await navegador.push<bool>(
            MaterialPageRoute<bool>(
              settings: RouteSettings(arguments: widget.usuario ?? {}),
              builder: (_) => AddBlogPage(post: widget.post),
            ),
          );

          // EDITAR D4: si se guardaron cambios, se regresa a la lista
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
          // AUTORIZADO MÓDULO EDITAR: Navegación a ModerarComentariosPage
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: RouteSettings(arguments: widget.usuario ?? {}),
              builder: (_) => ModerarComentariosPage(
                post: widget.post,
                usuario: widget.usuario,
              ),
            ),
          );
        },
        // REDISEÑO: Botón secundario con borde primary y texto primaryDark (Sección 2.3)
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
        // AUTORIZADO MÓDULO EDITAR: Lado a lado en pantallas de 600 px o más, apilados en móvil
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
    final textTheme = Theme.of(context).textTheme; // REDISEÑO
    final colorScheme = Theme.of(context).colorScheme; // REDISEÑO
    final etiquetas = widget.post.tags
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de publicación')),
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
                      child: widget.post.imagen.trim().isNotEmpty
                          ? Image.network(
                              urlImagen(
                                widget.post.imagen,
                              ), // LÓGICA AUTORIZADA 1
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
                              child: Text(tag, style: textTheme.labelSmall),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // REDISEÑO: Título de detalle en 28 bold textPrimary (Sección 6)
                  Text(widget.post.titulo, style: textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  // AUTOR E3: Autor debajo del título con ícono person_outline de 16 px y bodySmall en textSecondary
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

                  // REDISEÑO: Cuerpo en 16 regular con interlineado 1.5 en textPrimary (Secciones 3 y 6)
                  Text(
                    widget.post.descripcion.isNotEmpty
                        ? widget.post.descripcion
                        : 'Esta publicación no tiene descripción.',
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),

                  // AUTORIZADO MÓDULO EDITAR: Muestra botones de administración o sección desplegable de comentarios según modoAdmin
                  if (widget.modoAdmin)
                    _buildAccionesAdmin(context)
                  else
                    // COMENTARIOS C3: Tarjeta de comentarios conectada a futureComentarios con FutureBuilder
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
                                // REDISEÑO: Botón "Agregar comentario" alineado abajo a la derecha (alto 48, radio 8)
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
