import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../services/post_service.dart';
import '../theme/app_theme.dart'; // REDISEÑO
import '../widgets/post_card.dart';
import 'post_detail_page.dart';
import '../widgets/admin_drawer.dart';

class BlogPage extends StatefulWidget {
  const BlogPage({super.key});

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  final PostService postService = PostService();
  late Future<List<PostModel>> futurePosts;
  String nombreUsuario = 'Usuario';
  Map<String, dynamic> usuarioActual = {
    'nom_usr': 'Usuario',
    'mail': '',
    'tip_usu': 2,
  };
  bool argumentoLeido = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!argumentoLeido) {
      final argumento = ModalRoute.of(context)?.settings.arguments;

      if (argumento is Map<String, dynamic>) {
        usuarioActual = Map<String, dynamic>.from(argumento);
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
    futurePosts = postService.obtenerPosts();
  }

  void recargarPosts() {
    setState(() {
      futurePosts = postService.obtenerPosts();
    });
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
    final correoUsuario = usuarioActual['mail']?.toString() ?? '';
    final iniciales = _obtenerIniciales(nombreUsuario);

    return Scaffold(
      appBar: AppBar(
        title: Column(
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
          if (!esAdmin)
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
      drawer: esAdmin
          ? AdminDrawer(usuario: usuarioActual, rutaActual: '/blog')
          : null,
      body: FutureBuilder<List<PostModel>>(
        future: futurePosts,
        builder: (context, snapshot) {
          // REDISEÑO: Estado de carga con indicador tintado y mensaje claro (Sección 5)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando publicaciones...',
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          // REDISEÑO: Estado de error con ícono en círculo tintado y botón de acción (Sección 5)
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
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

          // REDISEÑO: Estado vacío con ícono tintado y mensaje claro (Sección 5)
          if (posts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
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

          // REDISEÑO: Contenido centrado con ancho máximo de 720 px y espaciado en múltiplos de 8 (Secciones 4 y 6)
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Bienvenido', style: textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Descubre nuevas ideas',
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...posts.map(
                    (post) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: PostCard(
                        post: post,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) => PostDetailPage(post: post),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
