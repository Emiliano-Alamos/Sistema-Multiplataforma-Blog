import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../services/post_service.dart';
import '../services/sesion.dart';
import '../theme/app_theme.dart';
import '../widgets/post_card.dart';
import 'post_detail_page.dart';
import '../widgets/admin_drawer.dart';

// Alias cortos para tipos que se repiten.
typedef PostList = List<PostModel>;
typedef JsonMap = Map<String, dynamic>;

/// Lista del blog con buscador y filtro por etiqueta.
/// - Usuario general: lee publicaciones y abre su detalle.
/// - Administrador: además filtra «Todas / Mis publicaciones».
/// - modoEdicion (ruta /edit-blogs): el administrador abre cada publicación
///   para editarla o moderar sus comentarios.
class BlogPage extends StatefulWidget {
  final bool modoEdicion;

  const BlogPage({
    super.key,
    this.modoEdicion = false,
  });

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  final PostService postService = PostService();
  late Future<PostList> futurePosts; // consulta de publicaciones en curso
  late Future<List<String>> futureEtiquetas; // etiquetas para el selector
  String nombreUsuario = 'Usuario';
  // Usuario con sesión (llega como argumento de la ruta).
  JsonMap usuarioActual = {'nom_usr': 'Usuario', 'mail': '', 'tip_usu': 2};
  bool argumentoLeido = false;
  bool soloMias = false; // filtro «Mis publicaciones» del administrador
  // Texto escrito en el buscador y filtros que ya se aplicaron.
  final TextEditingController buscarController = TextEditingController();
  String busquedaAplicada = '';
  String etiquetaFiltro = ''; // '' = todas las etiquetas

  @override
  // Lee una sola vez los datos del usuario que llegan con la ruta.
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!argumentoLeido) {
      final argumento = ModalRoute.of(context)?.settings.arguments;

      if (argumento is JsonMap) {
        usuarioActual = JsonMap.from(argumento);
        nombreUsuario = usuarioActual['nom_usr']?.toString() ?? 'Usuario';
      } else if (argumento is String && argumento.isNotEmpty) {
        nombreUsuario = argumento;
        usuarioActual = {'nom_usr': nombreUsuario, 'mail': '', 'tip_usu': 2};
      }

      argumentoLeido = true;
    }
  }

  @override
  // Al abrir la pantalla se piden las publicaciones y las etiquetas.
  void initState() {
    super.initState();
    futurePosts = consultarPosts();
    futureEtiquetas = obtenerEtiquetas();
  }

  /// Consulta las publicaciones con los filtros aplicados. Así, el
  /// botón Actualizar y el regreso desde Editar conservan la búsqueda.
  Future<PostList> consultarPosts() {
    return postService.obtenerPosts(
      q: busquedaAplicada,
      etiqueta: etiquetaFiltro,
    );
  }

  /// Arma la lista de etiquetas a partir de las publicaciones guardadas,
  /// sin repetir (sin distinguir mayúsculas) y en orden alfabético.
  Future<List<String>> obtenerEtiquetas() async {
    final posts = await postService.obtenerPosts();
    final etiquetas = <String, String>{};

    for (final post in posts) {
      for (final etiqueta in post.tags.split(',')) {
        final nombre = etiqueta.trim();
        if (nombre.isNotEmpty) {
          etiquetas.putIfAbsent(nombre.toLowerCase(), () => nombre);
        }
      }
    }

    return etiquetas.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// Vuelve a consultar publicaciones y etiquetas (botón Actualizar).
  void recargarPosts() {
    setState(() {
      futurePosts = consultarPosts();
      futureEtiquetas = obtenerEtiquetas();
    });
  }

  /// Aplica el texto escrito (Enter o botón Buscar).
  void buscar() {
    setState(() {
      busquedaAplicada = buscarController.text.trim();
      futurePosts = consultarPosts();
    });
  }

  /// La etiqueta se aplica en cuanto se elige.
  void cambiarEtiqueta(String? valor) {
    setState(() {
      etiquetaFiltro = valor ?? '';
      futurePosts = consultarPosts();
    });
  }

  /// Quita texto y etiqueta y vuelve a la lista completa.
  void limpiarFiltros() {
    buscarController.clear();
    setState(() {
      busquedaAplicada = '';
      etiquetaFiltro = '';
      futurePosts = consultarPosts();
    });
  }

  bool get hayFiltros =>
      busquedaAplicada.isNotEmpty || etiquetaFiltro.isNotEmpty;

  // Libera el controlador del campo de búsqueda.
  @override
  void dispose() {
    buscarController.dispose();
    super.dispose();
  }

  /// Abre el detalle en modo administrador y, si al volver hubo
  /// cambios (true), recarga la lista.
  Future<void> _abrirDetalleEdicion(PostModel post) async {
    final cambio = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        settings: RouteSettings(arguments: usuarioActual),
        builder: (context) =>
            PostDetailPage(post: post, modoAdmin: true, usuario: usuarioActual),
      ),
    );

    if (cambio == true && mounted) {
      recargarPosts();
    }
  }

  /// Iniciales del usuario para el menú: «Ana López» → «AL».
  String _obtenerIniciales(String nombre) {
    final partes = nombre
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final esAdmin = (usuarioActual['tip_usu'] as num? ?? 2).toInt() == 1;
    final idUsuario = (usuarioActual['id_usr'] as num?)?.toInt();
    final correoUsuario = usuarioActual['mail']?.toString() ?? '';
    final iniciales = _obtenerIniciales(nombreUsuario);
    final enEdicion = widget.modoEdicion;

    // Campo de búsqueda: busca al presionar Enter o la lupa.
    final campoBusqueda = TextField(
      controller: buscarController,
      maxLength: 100,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => buscar(),
      decoration: InputDecoration(
        labelText: 'Buscar',
        hintText: 'Título, descripción o etiqueta',
        counterText: '',
        suffixIcon: IconButton(
          tooltip: 'Buscar',
          icon: const Icon(Icons.search_outlined),
          onPressed: buscar,
        ),
      ),
    );

    // Selector de etiqueta con las etiquetas existentes en MySQL.
    final selectorEtiqueta = FutureBuilder<List<String>>(
      future: futureEtiquetas,
      builder: (context, snapshot) {
        final opciones = List<String>.from(snapshot.data ?? []);

        // Conservamos la selección si una etiqueta deja de estar disponible.
        if (etiquetaFiltro.isNotEmpty && !opciones.contains(etiquetaFiltro)) {
          opciones.insert(0, etiquetaFiltro);
        }

        return DropdownButtonFormField<String>(
          key: ValueKey('etiqueta-$etiquetaFiltro'),
          initialValue: etiquetaFiltro,
          isExpanded: true,
          style: textTheme.bodyLarge,
          decoration: const InputDecoration(labelText: 'Etiqueta'),
          items: [
            const DropdownMenuItem<String>(
              value: '',
              child: Text('Todas las etiquetas'),
            ),
            ...opciones.map(
              (etiqueta) => DropdownMenuItem<String>(
                value: etiqueta,
                child: Text(etiqueta, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: cambiarEtiqueta,
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        // El título cambia en modo edición.
        title: enEdicion
            ? const Text('Editar publicaciones')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Mi Blog'),
                  Text(
                    'Bienvenido, $nombreUsuario',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_outlined),
            onPressed: recargarPosts,
          ),
          // Menú del usuario general (cerrar sesión). El administrador usa el menú lateral.
          if (!esAdmin && !enEdicion)
            PopupMenuButton<String>(
              tooltip: 'Menú de usuario',
              offset: const Offset(0, 48),
              color: colorScheme.surface,
              surfaceTintColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              onSelected: (valor) {
                if (valor == 'logout') {
                  Sesion.cerrar();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryTint,
                        child: Text(
                          iniciales,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              nombreUsuario,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (correoUsuario.isNotEmpty)
                              Text(
                                correoUsuario,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.logout_outlined,
                        size: 20,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Cerrar sesión',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: colorScheme.surface,
                      child: Text(
                        iniciales,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      // Menú lateral solo para el administrador.
      drawer: enEdicion
          ? AdminDrawer(usuario: usuarioActual, rutaActual: '/edit-blogs')
          : (esAdmin
                ? AdminDrawer(usuario: usuarioActual, rutaActual: '/blog')
                : null),
      // Contenido centrado con ancho máximo: encabezado, filtros y, al final, la lista.
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Encabezado y subtítulo según el modo.
              Text(
                enEdicion ? 'Editar publicaciones' : 'Bienvenido',
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                enEdicion
                    ? 'Selecciona una publicación para editarla o moderar sus comentarios'
                    : 'Descubre nuevas ideas',
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              // Filtros: en fila en pantallas anchas, uno sobre otro en el celular.
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 600) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: campoBusqueda),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: selectorEtiqueta),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      campoBusqueda,
                      const SizedBox(height: 16),
                      selectorEtiqueta,
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              // Filtro «Todas / Mis publicaciones», solo para el administrador.
              if (esAdmin) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Todas'),
                      selected: !soloMias,
                      onSelected: (_) {
                        setState(() {
                          soloMias = false;
                        });
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Mis publicaciones'),
                      selected: soloMias,
                      onSelected: (_) {
                        setState(() {
                          soloMias = true;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              // FutureBuilder redibuja la lista según la consulta: cargando, error o datos.
              FutureBuilder<PostList>(
                future: futurePosts,
                builder: (context, snapshot) {
                  // Cargando.
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 48,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Cargando publicaciones...',
                              style: textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Error: muestra el mensaje y un botón para reintentar.
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
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
                                child: Icon(
                                  Icons.cloud_off_outlined,
                                  size: 32,
                                  color: colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No fue posible cargar el blog.',
                                style: textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${snapshot.error}',
                                style: textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: recargarPosts,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final posts = snapshot.data ?? <PostModel>[];
                  // Publicaciones propias = las que tienen mi id como autor.
                  final visibles = soloMias
                      ? posts.where((p) => p.usuarioId == idUsuario).toList()
                      : posts;
                  // Texto del contador de resultados.
                  final textoContador = visibles.length == 1
                      ? '1 publicación encontrada'
                      : '${visibles.length} publicaciones encontradas';

                  // Caso 1: no hay publicaciones y no hay filtros activos.
                  if (posts.isEmpty && !hayFiltros) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
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
                                Icons.article_outlined,
                                size: 32,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay publicaciones registradas.',
                              style: textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Caso 2: los filtros no encontraron resultados.
                  if (visibles.isEmpty && hayFiltros) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
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
                              Icons.search_off_outlined,
                              size: 32,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No se encontraron publicaciones con esos filtros.',
                            style: textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: limpiarFiltros,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryDark,
                              backgroundColor: AppColors.surface,
                              minimumSize: const Size(0, 48),
                              side: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Limpiar filtros'),
                          ),
                        ],
                      ),
                    );
                  }

                  // Caso 3: el administrador no tiene publicaciones propias.
                  if (visibles.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
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
                              Icons.article_outlined,
                              size: 32,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aún no tienes publicaciones propias.',
                            style: textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  // Caso 4: hay resultados; con filtros se muestra el contador.
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hayFiltros) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                textoContador,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: limpiarFiltros,
                              child: const Text('Limpiar filtros'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      ...visibles.map(
                        (post) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          // En modo edición abre el detalle de administrador; si no, el detalle normal.
                          child: PostCard(
                            post: post,
                            textoBoton: enEdicion
                                ? 'Ver publicación'
                                : 'Leer publicación',
                            onTap: () {
                              if (enEdicion) {
                                _abrirDetalleEdicion(post);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (context) =>
                                        PostDetailPage(post: post),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
