// AUTORIZADO ETIQUETA: Lista fija de etiquetas en el orden requerido
const List<String> kEtiquetasFijas = [
  'Tarjeta de crédito',
  'Técnicas de ahorro',
  'Inversiones sencillas',
  'Presupuesto personal',
  'Educación financiera',
];

// AUTORIZADO ETIQUETA: Devuelve la lista incluyendo la etiqueta actual al inicio si es un dato antiguo no vacío
List<String> obtenerOpcionesEtiquetas(String? etiquetaActual) {
  final actual = etiquetaActual?.trim() ?? '';
  if (actual.isNotEmpty && !kEtiquetasFijas.contains(actual)) {
    return [actual, ...kEtiquetasFijas];
  }
  return List<String>.from(kEtiquetasFijas);
}
