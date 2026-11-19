// Etiquetas relacionadas con las tecnologías emergentes
const List<String> kEtiquetasFijas = [
  'IA',
  'Inteligencia Artificial',
  'ChatBots',
  'Tecnología',
  'Robótica',
  'Realidad Virtual',
  'Ciberseguridad',
  'Automatización',
  'Programación',
  'Innovación',
  'Herramientas',
  'Nuevo',
];

// Mantiene disponible la etiqueta actual al editar una publicación
List<String> obtenerOpcionesEtiquetas(String? etiquetaActual) {
  final actual = etiquetaActual?.trim() ?? '';

  if (actual.isNotEmpty && !kEtiquetasFijas.contains(actual)) {
    return [actual, ...kEtiquetasFijas];
  }

  return List<String>.from(kEtiquetasFijas);
}
