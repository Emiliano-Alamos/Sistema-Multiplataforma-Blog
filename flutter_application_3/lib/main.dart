// Punto de entrada de la app: aplica el tema y define las rutas (pantallas).
import 'package:flutter/material.dart';

import 'screens/add_blog_page.dart';
import 'screens/blog_page.dart';
import 'screens/login_user_page.dart';
import 'screens/profile_page.dart';
import 'screens/register_user_page.dart';
import 'screens/users_page.dart';
import 'services/sesion.dart';
import 'theme/app_theme.dart';

/// Arranca la aplicación.
void main() {
  runApp(const LoginApp());
}

/// Raíz de la app: configura el tema, la pantalla inicial y la tabla de rutas.
class LoginApp extends StatelessWidget {
  const LoginApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Permite volver al login desde cualquier parte cuando la sesión vence.
      navigatorKey: Sesion.navegadorKey,
      debugShowCheckedModeBanner: false,
      title: 'Aplicación móvil con FastAPI',
      theme: AppTheme.light,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/users': (context) => const UsersPage(),
        '/blog': (context) => const BlogPage(),
        '/add-blog': (context) => const AddBlogPage(),
        // Misma pantalla del blog, en modo edición para el administrador.
        '/edit-blogs': (context) =>
            const BlogPage(modoEdicion: true),
        '/profile': (context) => const ProfilePage(),
      },
    );
  }
}
