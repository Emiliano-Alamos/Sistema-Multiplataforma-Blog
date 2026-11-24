import 'package:flutter/material.dart';

/// Fondo azul de las pantallas de inicio de sesión y registro.
class AuthBackground extends StatelessWidget {
  final Widget child;

  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Color primario del tema.
    return Container(
      color: Theme.of(context).colorScheme.primary,
      child: child,
    );
  }
}
