/// Lista fija de etiquetas que se ofrecen al crear o editar una publicación.
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

/// Opciones del selector de etiqueta. Si la publicación que se edita tiene
/// una etiqueta que ya no está en la lista, se agrega al inicio para no perderla.
List<String> obtenerOpcionesEtiquetas(String? etiquetaActual) {
  final actual = etiquetaActual?.trim() ?? '';

  if (actual.isNotEmpty && !kEtiquetasFijas.contains(actual)) {
    return [actual, ...kEtiquetasFijas];
  }

  return List<String>.from(kEtiquetasFijas);
}
