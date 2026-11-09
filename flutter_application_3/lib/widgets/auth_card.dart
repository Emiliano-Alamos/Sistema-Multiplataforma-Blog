import 'package:flutter/material.dart';

class AuthCard extends StatelessWidget {
  final Widget child;

  const AuthCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // REDISEÑO: Ancho máximo 400 adaptable a pantallas angostas y tarjeta heredada del tema (radio 12, borde y elevación 1)
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Card(
        child: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    );
  }
}
