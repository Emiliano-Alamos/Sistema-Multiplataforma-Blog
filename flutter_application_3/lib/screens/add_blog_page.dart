import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/post_service.dart';
import '../widgets/admin_drawer.dart';

class AddBlogPage extends StatefulWidget {
  const AddBlogPage({super.key});

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

    setState(() => _guardando = true);

    try {
      // NUEVO
      // Si seleccionamos una fotografia, la enviamos a FastAPI.
      if (_foto != null && _imagenBytes != null) {
        await _servicio.agregarPostConFoto(
          titulo: _titulo.text,
          descripcion: _descripcion.text,
          tags: _tags.text,
          imagenBytes: _imagenBytes!,
          nombreArchivo: _foto!.name,
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

  @override
  Widget build(BuildContext context) {
    final nombre = _usuario['nom_usr']?.toString() ?? 'Administrador';
    final tema = Theme.of(context);
    final colores = tema.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Agregar blog')),
      drawer: AdminDrawer(usuario: _usuario, rutaActual: '/add-blog'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                        decoration: const InputDecoration(labelText: 'Título'),
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
                            icon: const Icon(Icons.photo_library_outlined),
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
                        Text(_foto!.name, style: tema.textTheme.bodyMedium),
                      ],
                      const SizedBox(height: 24),

                      // Campo de etiquetas existente.
                      TextFormField(
                        controller: _tags,
                        decoration: const InputDecoration(
                          labelText: 'Etiquetas (opcional)',
                          hintText: 'flutter, tecnología, móvil',
                        ),
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
                            _guardando ? 'Guardando...' : 'Guardar publicación',
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
