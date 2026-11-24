import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post_model.dart';
import '../services/post_service.dart';
import '../theme/app_theme.dart';
import '../utils/etiquetas.dart';
import '../utils/image_url.dart';
import '../widgets/admin_drawer.dart';

/// Formulario de publicaciones del administrador, en dos modos:
/// - Agregar (sin post): crea una publicación con o sin fotografía.
/// - Editar (con post): carga sus datos, guarda cambios o elimina la publicación.
class AddBlogPage extends StatefulWidget {
  final PostModel? post; // publicación a editar (null = agregar)

  const AddBlogPage({
    super.key,
    this.post,
  });

  @override
  State<AddBlogPage> createState() => _AddBlogPageState();
}

class _AddBlogPageState extends State<AddBlogPage> {
  // Llave del formulario y controladores de sus campos.
  final _formKey = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  final _imagen = TextEditingController();
  final _tags = TextEditingController();
  final _servicio = PostService();

  // Fotografía seleccionada y sus bytes para la vista previa y el envío.
  final ImagePicker _picker = ImagePicker();
  XFile? _foto;
  Uint8List? _imagenBytes;

  bool _guardando = false; // true mientras se guarda o elimina
  Map<String, dynamic> _usuario = {}; // administrador con sesión

  // Etiqueta elegida y contador que fuerza a reiniciar el selector.
  String? _etiquetaSeleccionada;
  int _dropdownResetCounter = 0;

  /// true si se abrió para editar una publicación existente.
  bool get _esEdicion => widget.post != null;

  @override
  // En modo edición, llena el formulario con los datos de la publicación.
  void initState() {
    super.initState();
    final post = widget.post;
    if (post != null) {
      _titulo.text = post.titulo;
      _descripcion.text = post.descripcion;
      _imagen.text = post.imagen.trim().isNotEmpty
          ? urlImagen(post.imagen)
          : post.imagen;
      _tags.text = post.tags;
      // El selector empieza con la etiqueta actual.
      final tagInicial = post.tags.trim();
      _etiquetaSeleccionada = tagInicial.isNotEmpty ? tagInicial : null;
    }
  }

  @override
  // Recibe los datos del administrador como argumento de la ruta.
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _usuario = Map<String, dynamic>.from(args);
    }
  }

  @override
  // Libera los controladores al cerrar la pantalla.
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _imagen.dispose();
    _tags.dispose();
    super.dispose();
  }

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

  /// Texto en negritas que va arriba de cada campo.
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

  /// Abre la cámara o la galería (según origen) con image_picker y guarda
  /// la foto para la vista previa. imageQuality: 75 reduce el peso del archivo.
  Future<void> _seleccionarFoto(ImageSource origen) async {
    try {
      final imagen = await _picker.pickImage(source: origen, imageQuality: 75);

      if (imagen == null) return;

      // Se leen los bytes porque Image.memory funciona igual en Flutter Web y en Android.
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

  /// Valida el formulario y guarda: en modo edición actualiza; si no, crea
  /// la publicación (con foto por multipart o sin foto por JSON).
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    // En modo edición se actualiza la publicación en la API.
    if (_esEdicion) {
      await _guardarEdicion();
      return;
    }

    setState(() => _guardando = true);

    try {
      // Si se eligió una fotografía, se envía el archivo a la API.
      if (_foto != null && _imagenBytes != null) {
        await _servicio.agregarPostConFoto(
          titulo: _titulo.text,
          descripcion: _descripcion.text,
          imagenBytes: _imagenBytes!,
          nombreArchivo: _foto!.name,
          tags: _tags.text,
        );
      } else {
        // Sin fotografía: se envían los datos en JSON,
        // con la dirección de imagen escrita (opcional).
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

      // Limpia el formulario para capturar otra publicación.
      _titulo.clear();
      _descripcion.clear();
      _imagen.clear();
      _tags.clear();

      // Quita la foto y su vista previa.
      setState(() {
        _foto = null;
        _imagenBytes = null;
        // Regresa el selector a «Selecciona una etiqueta».
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

  /// Guarda los cambios de una publicación que ya existe.
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

  /// Diálogo de confirmación para eliminar; devuelve true si se acepta.
  Future<bool?> _mostrarDialogoEliminar() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final tema = Theme.of(dialogContext);
        final colores = tema.colorScheme;

        return AlertDialog(
          // Botón en rojo porque la acción no se puede deshacer.
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

  /// Pide confirmación y elimina la publicación (y sus comentarios) en la API.
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

  /// Formulario del modo edición: datos, fotografía, etiqueta y botones
  /// «Guardar cambios» y «Eliminar publicación».
  Widget _buildFormularioEdicion(
    BuildContext context,
    ThemeData tema,
    ColorScheme colores,
    String nombre,
  ) {
    // Opciones de etiqueta (incluye la actual si ya no está en la lista).
    final opcionesEtiquetas = obtenerOpcionesEtiquetas(widget.post?.tags);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tarjeta 1: encabezado, título, descripción y dirección de imagen.
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
                      // Ícono de edición dentro de un círculo.
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

          // Tarjeta 2: fotografía, botones de cámara y galería, y etiqueta.
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
                  // Vista previa: la foto nueva si se eligió; si no, la imagen actual.
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
                  if (_foto != null) ...[
                    const SizedBox(height: 8),
                    Text(_foto!.name, style: tema.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 12),
                  // Botones para tomar una foto o elegirla de la galería.
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
                  // Selector de etiqueta (obligatorio); al elegir, se copia a _tags.
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

          // Guardar cambios; se deshabilita mientras se guarda.
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar cambios'),
            ),
          ),
          const SizedBox(height: 12),

          // Eliminar publicación (pide confirmación).
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
    // Opciones de etiqueta para el modo agregar.
    final opcionesEtiquetas = obtenerOpcionesEtiquetas(null);

    return Scaffold(
      // En modo edición: título «Editar publicación», flecha de regreso y sin menú lateral.
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar publicación' : 'Agregar blog'),
      ),
      drawer: _esEdicion
          ? null
          : AdminDrawer(usuario: _usuario, rutaActual: '/add-blog'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            // Elige el formulario según el modo.
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

                            // Botones para tomar una foto o elegirla de la galería.
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

                            // Selector de etiqueta (obligatorio); al elegir, se copia a _tags.
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

                            // Botón de guardar; se deshabilita mientras se guarda.
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
