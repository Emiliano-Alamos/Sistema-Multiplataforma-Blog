import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const PrimaryButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    // REDISEÑO: Alto 48, ancho completo y estilo heredado de elevatedButtonTheme (relleno primary, radio 8, sin forma de píldora)
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(onPressed: onPressed, child: Text(text)),
    );
  }
}
