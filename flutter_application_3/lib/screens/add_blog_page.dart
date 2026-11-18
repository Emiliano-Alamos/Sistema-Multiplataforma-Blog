import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post_model.dart'; // AUTORIZADO MÓDULO EDITAR
import '../services/post_service.dart';
import '../theme/app_theme.dart'; // REDISEÑO
import '../utils/etiquetas.dart'; // AUTORIZADO ETIQUETA
import '../utils/image_url.dart'; // LÓGICA AUTORIZADA 1
import '../widgets/admin_drawer.dart';

class AddBlogPage extends StatefulWidget {
  final PostModel? post; // AUTORIZADO MÓDULO EDITAR

  const AddBlogPage({
    super.key,
    this.post, // AUTORIZADO MÓDULO EDITAR
  });

  @override
  State<AddBlogPage> createState() => _AddBlogPageState();
}

class _AddBlogPageState extends State<AddBlogPage> {
  final _formKey = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  final _imagen = TextEditingController();
  final _tags = TextEditingController();
  final _servicio = PostService();

  // fotografia seleccionada y bytes para la vista previa.
  final ImagePicker _picker = ImagePicker();
  XFile? _foto;
  Uint8List? _imagenBytes;

  bool _guardando = false;
  Map<String, dynamic> _usuario = {};

  // AUTORIZADO ETIQUETA: Estado y llave para controlar y reiniciar el selector de etiqueta
  String? _etiquetaSeleccionada;
  int _dropdownResetCounter = 0;

  // AUTORIZADO MÓDULO EDITAR: Bandera para distinguir modo edición de creación
  bool get _esEdicion => widget.post != null;

  @override
  void initState() {
    super.initState();
    // AUTORIZADO MÓDULO EDITAR: Inicializar controladores con los datos del post
    final post = widget.post;
    if (post != null) {
      _titulo.text = post.titulo;
      _descripcion.text = post.descripcion;
      _imagen.text = post.imagen.trim().isNotEmpty
          ? urlImagen(post.imagen)
          : post.imagen;
      _tags.text = post.tags;
      // AUTORIZADO ETIQUETA: Inicializar el selector con la etiqueta actual en modo edición
      final tagInicial = post.tags.trim();
      _etiquetaSeleccionada = tagInicial.isNotEmpty ? tagInicial : null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _usuario = Map<String, dynamic>.from(args);
    }
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _imagen.dispose();
    _tags.dispose();
    super.dispose();
  }

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

  // REDISEÑO: Etiqueta superior en semibold según disposición del mockup N3
  Widget _buildEtiquetaCampo(ThemeData tema, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: tema.textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // NUEVO (PRACTICA 1): abrir camara o elegir una imagen del dispositivo.
  Future<void> _seleccionarFoto(ImageSource origen) async {
    try {
      final imagen = await _picker.pickImage(source: origen, imageQuality: 75);

      if (imagen == null) return;

      // Image.memory funciona tanto en Flutter Web como en Android.
      final bytes = await imagen.readAsBytes();

      if (!mounted) return;

      setState(() {
        _foto = imagen;
        _imagenBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo obtener la fotografia: $e')),
      );
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    // EDITAR D3: en modo edición se actualiza la publicación en la API.
    if (_esEdicion) {
      await _guardarEdicion();
      return;
    }

    setState(() => _guardando = true);

    try {
      // NUEVO
      // Si seleccionamos una fotografia, la enviamos a FastAPI.
      if (_foto != null && _imagenBytes != null) {
        await _servicio.agregarPostConFoto(
          titulo: _titulo.text,
          descripcion: _descripcion.text,
          imagenBytes: _imagenBytes!,
          nombreArchivo: _foto!.name,
          tags: _tags.text, // CORRECCIÓN TAGS
        );
      } else {
        // ORIGINAL:
        // Se conserva la funcion que ya utilizabamos
        // para guardar publicaciones mediante JSON.
        await _servicio.agregarPost(
          titulo: _titulo.text,
          descripcion: _descripcion.text,
          imagen: _imagen.text,
          tags: _tags.text,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación agregada correctamente')),
      );

      // Limpiar los campos originales.
      _titulo.clear();
      _descripcion.clear();
      _imagen.clear();
      _tags.clear();

      // NUEVO: limpiar la fotografia y su vista previa.
      setState(() {
        _foto = null;
        _imagenBytes = null;
        // AUTORIZADO ETIQUETA: Reiniciar el selector a «Selecciona una etiqueta» tras guardar
        _etiquetaSeleccionada = null;
        _dropdownResetCounter++;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  // EDITAR D3: guarda los cambios de una publicación que ya existe.
  Future<void> _guardarEdicion() async {
    final post = widget.post!;
    final mensajes = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);

    setState(() => _guardando = true);

    try {
      if (_foto != null && _imagenBytes != null) {
        // Se eligió una fotografía nueva: se envía el archivo.
        await _servicio.actualizarPostConFoto(
          id: post.id,
          titulo: _titulo.text,
          descripcion: _descripcion.text,
          imagenBytes: _imagenBytes!,
          nombreArchivo: _foto!.name,
          tags: _tags.text,
        );
      } else {
        // El campo muestra la dirección completa de la imagen. Si no se
        // cambió, se guarda la ruta original (/uploads/archivo.jpg) para
        // que la imagen se siga viendo igual en la web.
        String imagen = _imagen.text.trim();

        if (post.imagen.trim().isNotEmpty && imagen == urlImagen(post.imagen)) {
          imagen = post.imagen;
        }

        await _servicio.actualizarPost(
          id: post.id,
          titulo: _titulo.text,
          descripcion: _descripcion.text,
          imagen: imagen,
          tags: _tags.text,
        );
      }

      if (!mounted) return;

      mensajes.showSnackBar(
        const SnackBar(content: Text('Publicación actualizada correctamente')),
      );

      // Regresa a la pantalla anterior avisando que hubo cambios (true).
      navegador.pop(true);
    } catch (e) {
      mensajes.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  // ELIMINAR D9: diálogo de confirmación con el mismo diseño de moderar_comentarios_page.dart
  Future<bool?> _mostrarDialogoEliminar() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final tema = Theme.of(dialogContext);
        final colores = tema.colorScheme;

        return AlertDialog(
          // REDISEÑO: Diálogo de radio 12 heredado del tema con botón de peligro en colores error y onError
          title: const Text('Eliminar publicación'),
          content: const Text(
            '¿Estás seguro de eliminar esta publicación? También se eliminarán sus comentarios. Esta acción no se puede deshacer.',
          ),
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
  }

  // ELIMINAR D8: pide confirmación y elimina la publicación en la API.
  Future<void> _eliminarPublicacion() async {
    final mensajes = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);

    final confirmar = await _mostrarDialogoEliminar();

    if (confirmar != true || !mounted) return;

    setState(() => _guardando = true);

    try {
      await _servicio.eliminarPost(widget.post!.id);

      if (!mounted) return;

      mensajes.showSnackBar(
        const SnackBar(content: Text('Publicación eliminada correctamente')),
      );

      // Regresa a la pantalla anterior avisando que hubo cambios (true):
      // el detalle se cierra y la lista se vuelve a cargar.
      navegador.pop(true);
    } catch (e) {
      mensajes.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  // AUTORIZADO MÓDULO EDITAR: Disposición visual fiel al mockup N3 para Editar publicación
  Widget _buildFormularioEdicion(
    BuildContext context,
    ThemeData tema,
    ColorScheme colores,
    String nombre,
  ) {
    // AUTORIZADO ETIQUETA: Lista de opciones para modo edición (incluye etiqueta antigua al inicio si aplica)
    final opcionesEtiquetas = obtenerOpcionesEtiquetas(widget.post?.tags);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // REDISEÑO: Tarjeta 1 (Encabezado primaryTint + Título, Descripción y URL de imagen) según mockup N3
          Card(
            color: colores.surface,
            surfaceTintColor: colores.surface,
            elevation: 1,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colores.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // REDISEÑO: Ícono de edición dentro de círculo blanco a la izquierda (mockup N3)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colores.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_note_outlined,
                          size: 28,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Editar publicación',
                              style: tema.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Administrador: $nombre',
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
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildEtiquetaCampo(tema, 'Título'),
                      TextFormField(
                        controller: _titulo,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Ingresa el título'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildEtiquetaCampo(tema, 'Descripción'),
                      TextFormField(
                        controller: _descripcion,
                        maxLines: 3,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Ingresa la descripción'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildEtiquetaCampo(tema, 'URL de imagen (opcional)'),
                      TextFormField(controller: _imagen),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // REDISEÑO: Tarjeta 2 (Fotografía 16:9, botones gemelos y Etiquetas) según mockup N3
          Card(
            color: colores.surface,
            surfaceTintColor: colores.surface,
            elevation: 1,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colores.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Fotografía de la publicación',
                    style: tema.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // REDISEÑO: Vista previa 16:9 de radio 12 sobre los botones de foto (Sección 2.4 y mockup N3)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _imagenBytes != null
                          ? Image.memory(
                              _imagenBytes!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : widget.post!.imagen.trim().isNotEmpty
                          ? Image.network(
                              urlImagen(
                                widget.post!.imagen,
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
                  if (_foto != null) ...[
                    const SizedBox(height: 8),
                    Text(_foto!.name, style: tema.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 12),
                  // REDISEÑO: Botones Tomar foto y Elegir foto en fila 50/50 (mockup N3)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _seleccionarFoto(ImageSource.camera),
                          icon: const Icon(
                            Icons.camera_alt_outlined,
                            size: 20,
                            color: AppColors.primaryDark,
                          ),
                          label: const Text('Tomar foto'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryDark,
                            minimumSize: const Size(0, 48),
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _seleccionarFoto(ImageSource.gallery),
                          icon: const Icon(
                            Icons.photo_outlined,
                            size: 20,
                            color: AppColors.primaryDark,
                          ),
                          label: const Text('Elegir foto'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryDark,
                            minimumSize: const Size(0, 48),
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // AUTORIZADO ETIQUETA: Selector obligatorio de una sola opción en modo edición
                  _buildEtiquetaCampo(tema, 'Etiqueta'),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_dropdownResetCounter),
                    initialValue: _etiquetaSeleccionada,
                    isExpanded: true,
                    hint: const Text('Selecciona una etiqueta'),
                    items: opcionesEtiquetas
                        .map(
                          (etiqueta) => DropdownMenuItem<String>(
                            value: etiqueta,
                            child: Text(etiqueta),
                          ),
                        )
                        .toList(),
                    onChanged: (valor) {
                      setState(() {
                        _etiquetaSeleccionada = valor;
                        _tags.text = valor ?? '';
                      });
                    },
                    validator: (valor) => valor == null || valor.trim().isEmpty
                        ? 'Selecciona una etiqueta.'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // REDISEÑO: Botón primario «Guardar cambios» de ancho completo fuera de la tarjeta (mockup N3)
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar cambios'),
            ),
          ),
          const SizedBox(height: 12),

          // ELIMINAR D9: Botón «Eliminar publicación» debajo de «Guardar cambios» solo en modo edición
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _guardando ? null : _eliminarPublicacion,
              icon: Icon(Icons.delete_outline, color: colores.error),
              label: const Text('Eliminar publicación'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colores.error,
                backgroundColor: colores.surface,
                minimumSize: const Size(0, 48),
                side: BorderSide(color: colores.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _usuario['nom_usr']?.toString() ?? 'Administrador';
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    // AUTORIZADO ETIQUETA: Lista de opciones para modo agregar
    final opcionesEtiquetas = obtenerOpcionesEtiquetas(null);

    return Scaffold(
      // AUTORIZADO MÓDULO EDITAR: Flecha de regreso y título «Editar publicación» sin menú lateral en modo edición
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar publicación' : 'Agregar blog'),
      ),
      drawer: _esEdicion
          ? null
          : AdminDrawer(usuario: _usuario, rutaActual: '/add-blog'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720), // REDISEÑO
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _esEdicion
                ? _buildFormularioEdicion(context, tema, colores, nombre)
                : Card(
                    color: colores.surface,
                    surfaceTintColor: colores.surface,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: colores.outline),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Encabezado con la información del administrador.
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colores.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Nueva publicación',
                                          style: tema.textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Administrador: $nombre',
                                          style: tema.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.edit_note,
                                    size: 40,
                                    color: colores.onPrimaryContainer,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Título de la publicación.
                            TextFormField(
                              controller: _titulo,
                              decoration: const InputDecoration(
                                labelText: 'Título',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Ingresa el título'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            // Descripción de la publicación.
                            TextFormField(
                              controller: _descripcion,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                labelText: 'Descripción',
                                alignLabelWithHint: true,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Ingresa la descripción'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            // Dirección de imagen opcional.
                            TextFormField(
                              controller: _imagen,
                              decoration: const InputDecoration(
                                labelText: 'URL de imagen (opcional)',
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Se conserva la selección de cámara y galería.
                            Text(
                              'Fotografía de la publicación',
                              style: tema.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _seleccionarFoto(ImageSource.camera),
                                  icon: const Icon(Icons.camera_alt_outlined),
                                  label: const Text('Tomar foto'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: colores.secondary,
                                    minimumSize: const Size(0, 48),
                                    side: BorderSide(color: colores.secondary),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _seleccionarFoto(ImageSource.gallery),
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                  ),
                                  label: const Text('Elegir foto'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: colores.secondary,
                                    minimumSize: const Size(0, 48),
                                    side: BorderSide(color: colores.secondary),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Vista previa: aparece solo al seleccionar una foto.
                            if (_imagenBytes != null) ...[
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Image.memory(
                                    _imagenBytes!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _foto!.name,
                                style: tema.textTheme.bodyMedium,
                              ),
                            ],
                            const SizedBox(height: 24),

                            // AUTORIZADO ETIQUETA: Selector obligatorio de una sola opción en modo agregar
                            DropdownButtonFormField<String>(
                              key: ValueKey(_dropdownResetCounter),
                              initialValue: _etiquetaSeleccionada,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Etiqueta',
                              ),
                              hint: const Text('Selecciona una etiqueta'),
                              items: opcionesEtiquetas
                                  .map(
                                    (etiqueta) => DropdownMenuItem<String>(
                                      value: etiqueta,
                                      child: Text(etiqueta),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (valor) {
                                setState(() {
                                  _etiquetaSeleccionada = valor;
                                  _tags.text = valor ?? '';
                                });
                              },
                              validator: (valor) =>
                                  valor == null || valor.trim().isEmpty
                                  ? 'Selecciona una etiqueta.'
                                  : null,
                            ),
                            const SizedBox(height: 24),

                            // Mismo método de guardado y estado de carga.
                            SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _guardando ? null : _guardar,
                                icon: _guardando
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colores.onPrimary,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(
                                  _guardando
                                      ? 'Guardando...'
                                      : 'Guardar publicación',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
