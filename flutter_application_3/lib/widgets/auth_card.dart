import 'package:flutter/material.dart';

/// Tarjeta blanca que contiene los formularios de inicio de sesión y registro.
class AuthCard extends StatelessWidget {
  final Widget child;

  const AuthCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Máximo 400 px de ancho, para que se vea bien en pantallas grandes y angostas.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Card(
        child: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    );
  }
}
