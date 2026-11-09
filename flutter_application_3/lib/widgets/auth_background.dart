import 'package:flutter/material.dart';

class AuthBackground extends StatelessWidget {
  final Widget child;

  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // REDISEÑO: Fondo sólido primary del tema en lugar del degradado (Guía secciones 2 y 6)
    return Container(
      color: Theme.of(context).colorScheme.primary,
      child: child,
    );
  }
}
