import 'package:flutter/material.dart';

/// Botón principal de ancho completo y 48 px de alto (login y registro).
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const PrimaryButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    // El color y la forma vienen del tema (elevatedButtonTheme).
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(onPressed: onPressed, child: Text(text)),
    );
  }
}
