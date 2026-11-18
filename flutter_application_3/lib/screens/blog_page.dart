import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../services/post_service.dart';
import '../services/sesion.dart'; // SESIONES S8
import '../theme/app_theme.dart'; // REDISEÑO
import '../utils/etiquetas.dart'; // AUTORIZADO BUSCADOR
import '../widgets/post_card.dart';
import 'post_detail_page.dart';
import '../widgets/admin_drawer.dart';

typedef PostList = List<PostModel>;
typedef JsonMap = Map<String, dynamic>;

class BlogPage extends StatefulWidget {
  final bool modoEdicion; // AUTORIZADO MÓDULO EDITAR

  const BlogPage({
    super.key,
    this.modoEdicion = false, // AUTORIZADO MÓDULO EDITAR
  });

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  final PostService postService = PostService();
  late Future<PostList> futurePosts;
  String nombreUsuario = 'Usuario';
  JsonMap usuarioActual = {'nom_usr': 'Usuario', 'mail': '', 'tip_usu': 2};
  bool argumentoLeido = false;
  bool soloMias = false; // AUTOR E4
  // AUTORIZADO BUSCADOR: texto escrito y filtros aplicados
  final TextEditingController buscarController = TextEditingController();
  String busquedaAplicada = '';
  String etiquetaFiltro = ''; // '' = todas las etiquetas

  @override
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
  void initState() {
    super.initState();
    futurePosts = consultarPosts(); // AUTORIZADO BUSCADOR
  }

  // AUTORIZADO BUSCADOR: consulta siempre con los filtros aplicados. Así, el
  // botón Actualizar y el regreso desde Editar conservan la búsqueda.
  Future<PostList> consultarPosts() {
    return postService.obtenerPosts(
      q: busquedaAplicada,
      etiqueta: etiquetaFiltro,
    );
  }

  void recargarPosts() {
    setState(() {
      futurePosts = consultarPosts(); // AUTORIZADO BUSCADOR
    });
  }

  // AUTORIZADO BUSCADOR: aplica el texto escrito (Enter o botón Buscar).
  void buscar() {
    setState(() {
      busquedaAplicada = buscarController.text.trim();
      futurePosts = consultarPosts();
    });
  }

  // AUTORIZADO BUSCADOR: la etiqueta se aplica en cuanto se elige.
  void cambiarEtiqueta(String? valor) {
    setState(() {
      etiquetaFiltro = valor ?? '';
      futurePosts = consultarPosts();
    });
  }

  // AUTORIZADO BUSCADOR: quita texto y etiqueta y vuelve a la lista completa.
  void limpiarFiltros() {
    buscarController.clear();
    setState(() {
      busquedaAplicada = '';
      etiquetaFiltro = '';
      futurePosts = consultarPosts();
    });
  }

  // AUTORIZADO BUSCADOR
  bool get hayFiltros =>
      busquedaAplicada.isNotEmpty || etiquetaFiltro.isNotEmpty;

  // AUTORIZADO BUSCADOR: libera el controlador del campo de búsqueda.
  @override
  void dispose() {
    buscarController.dispose();
    super.dispose();
  }

  // EDITAR D5: abre el detalle en modo administrador y, si al volver hubo
  // cambios (true), recarga la lista.
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

  // LÓGICA AUTORIZADA 2
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
    final textTheme = Theme.of(context).textTheme; // REDISEÑO
    final colorScheme = Theme.of(context).colorScheme; // REDISEÑO
    final esAdmin = (usuarioActual['tip_usu'] as num? ?? 2).toInt() == 1;
    final idUsuario = (usuarioActual['id_usr'] as num?)?.toInt(); // AUTOR E4
    final correoUsuario = usuarioActual['mail']?.toString() ?? '';
    final iniciales = _obtenerIniciales(nombreUsuario);
    final enEdicion = widget.modoEdicion; // AUTORIZADO MÓDULO EDITAR

    // AUTORIZADO BUSCADOR: Controles del bloque de filtros (Secciones 4.2 y 4.3)
    final campoBusqueda = TextField(
      controller: buscarController,
      maxLength: 100,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => buscar(),
      decoration: InputDecoration(
        labelText: 'Buscar',
        hintText: 'Título o descripción',
        counterText: '',
        suffixIcon: IconButton(
          tooltip: 'Buscar',
          icon: const Icon(Icons.search_outlined),
          onPressed: buscar,
        ),
      ),
    );

    // AUTORIZADO BUSCADOR: la llave hace que se reinicie al limpiar filtros
    final selectorEtiqueta = DropdownButtonFormField<String>(
      key: ValueKey('etiqueta-$etiquetaFiltro'),
      initialValue: etiquetaFiltro,
      isExpanded: true,
      style: textTheme.bodyLarge, // AUTORIZADO BUSCADOR: mismo tamaño que el campo de búsqueda
      decoration: const InputDecoration(labelText: 'Etiqueta'),
      items: [
        const DropdownMenuItem<String>(
          value: '',
          child: Text('Todas las etiquetas'),
        ),
        ...kEtiquetasFijas.map(
          (etiqueta) => DropdownMenuItem<String>(
            value: etiqueta,
            child: Text(etiqueta, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: cambiarEtiqueta,
    );

    return Scaffold(
      appBar: AppBar(
        // AUTORIZADO MÓDULO EDITAR: Título «Editar publicaciones» en modoEdicion
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
          // LÓGICA AUTORIZADA 2
          // AUTORIZADO MÓDULO EDITAR: Sin menú de usuario cuando modoEdicion es true
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
                  Sesion.cerrar(); // SESIONES S8
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
      // AUTORIZADO MÓDULO EDITAR: AdminDrawer con rutaActual '/edit-blogs' en modoEdicion
      drawer: enEdicion
          ? AdminDrawer(usuario: usuarioActual, rutaActual: '/edit-blogs')
          : (esAdmin
                ? AdminDrawer(usuario: usuarioActual, rutaActual: '/blog')
                : null),
      // AUTORIZADO BUSCADOR: Estructura del body con filtros fijos en el ListView y FutureBuilder al final (Sección 3.3)
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // AUTORIZADO MÓDULO EDITAR: Encabezado y subtítulo según sección 2.2 del Anexo
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
              // AUTORIZADO BUSCADOR: Bloque de filtros responsivo (Sección 4.1)
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
              // AUTOR E4: Filtro «Todas / Mis publicaciones» visible solo para administrador
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
              // AUTORIZADO BUSCADOR: FutureBuilder como último hijo del ListView (Secciones 3.3 y 4.5)
              FutureBuilder<PostList>(
                future: futurePosts,
                builder: (context, snapshot) {
                  // REDISEÑO: Estado de carga con indicador tintado y 48 px de margen vertical
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 48,
                      ), // AUTORIZADO BUSCADOR
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

                  // REDISEÑO: Estado de error con ícono en círculo tintado y 32 px de margen vertical
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
                      ), // AUTORIZADO BUSCADOR
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
                  // AUTOR E4: publicaciones propias = las que tienen mi id como autor.
                  final visibles = soloMias
                      ? posts.where((p) => p.usuarioId == idUsuario).toList()
                      : posts;
                  // AUTORIZADO BUSCADOR: texto del contador
                  final textoContador = visibles.length == 1
                      ? '1 publicación encontrada'
                      : '${visibles.length} publicaciones encontradas';

                  // Condición #1: sin publicaciones registradas y sin filtros activos
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

                  // AUTORIZADO BUSCADOR: Condición #2: sin resultados con filtros activos (Sección 4.5)
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

                  // Condición #3: sin publicaciones propias del administrador
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

                  // AUTORIZADO BUSCADOR: Condición #4: resultados con fila de contador opcional (Sección 4.4)
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
                          // AUTORIZADO MÓDULO EDITAR: PostCard con 'Ver publicación' y navegación con modoAdmin en modoEdicion
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
