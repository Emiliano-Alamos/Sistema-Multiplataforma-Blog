import 'package:flutter/material.dart';

class AdminDrawer extends StatelessWidget {
  final Map<String, dynamic> usuario;
  final String rutaActual;

  const AdminDrawer({
    super.key,
    required this.usuario,
    required this.rutaActual,
  });

  String get nombre => usuario['nom_usr']?.toString() ?? 'Administrador';
  String get correo => usuario['mail']?.toString() ?? '';

  void _navegar(BuildContext context, String ruta) {
    Navigator.pop(context);
    if (ruta == rutaActual) return;
    Navigator.pushReplacementNamed(context, ruta, arguments: usuario);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    final nombreLimpio = nombre.trim();
    final inicial = nombreLimpio.isEmpty
        ? 'A'
        : nombreLimpio.substring(0, 1).toUpperCase();

    return Drawer(
      backgroundColor: colores.surface,
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              margin: EdgeInsets.zero,
              decoration: BoxDecoration(color: colores.primary),
              currentAccountPicture: CircleAvatar(
                backgroundColor: colores.primaryContainer,
                child: Text(
                  inicial,
                  style: tema.textTheme.titleLarge?.copyWith(
                    color: colores.onPrimaryContainer,
                  ),
                ),
              ),
              accountName: Text(
                nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.titleMedium?.copyWith(
                  color: colores.onPrimary,
                ),
              ),
              accountEmail: Text(
                correo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: colores.onPrimary,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                children: [
                  _opcion(
                    context,
                    Icons.people_alt_outlined,
                    'Gestión de usuarios',
                    '/users',
                  ),
                  _opcion(
                    context,
                    Icons.person_add_alt_1,
                    'Registrar usuario',
                    '/register',
                  ),
                  _opcion(context, Icons.post_add, 'Agregar blog', '/add-blog'),
                  _opcion(
                    context,
                    Icons.account_circle_outlined,
                    'Mi perfil',
                    '/profile',
                  ),
                ],
              ),
            ),
            Divider(color: colores.outline, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                leading: Icon(Icons.logout, color: colores.error),
                title: Text(
                  'Cerrar sesión',
                  style: tema.textTheme.bodyLarge?.copyWith(
                    color: colores.error,
                  ),
                ),
                onTap: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _opcion(
    BuildContext context,
    IconData icono,
    String titulo,
    String ruta,
  ) {
    final seleccionado = ruta == rutaActual;
    final tema = Theme.of(context);
    final colores = tema.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: seleccionado,
        selectedTileColor: colores.primaryContainer,
        leading: Icon(
          icono,
          color: seleccionado
              ? colores.onPrimaryContainer
              : colores.onSurfaceVariant,
        ),
        title: Text(
          titulo,
          style: tema.textTheme.bodyLarge?.copyWith(
            color: seleccionado
                ? colores.onPrimaryContainer
                : colores.onSurface,
            fontWeight: seleccionado ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () => _navegar(context, ruta),
      ),
    );
  }
}
