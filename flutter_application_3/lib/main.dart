import 'package:flutter/material.dart';

import 'screens/add_blog_page.dart';
import 'screens/blog_page.dart';
import 'screens/login_user_page.dart';
import 'screens/profile_page.dart';
import 'screens/register_user_page.dart';
import 'screens/users_page.dart';
import 'services/sesion.dart'; // SESIONES S2
import 'theme/app_theme.dart'; // REDISEÑO

void main() {
  runApp(const LoginApp());
}

class LoginApp extends StatelessWidget {
  const LoginApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: Sesion.navegadorKey, // SESIONES S2
      debugShowCheckedModeBanner: false,
      title: 'Aplicación móvil con FastAPI',
      theme: AppTheme.light, // REDISEÑO
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/users': (context) => const UsersPage(),
        '/blog': (context) => const BlogPage(),
        '/add-blog': (context) => const AddBlogPage(),
        '/edit-blogs': (context) =>
            const BlogPage(modoEdicion: true), // AUTORIZADO MÓDULO EDITAR
        '/profile': (context) => const ProfilePage(),
      },
    );
  }
}
