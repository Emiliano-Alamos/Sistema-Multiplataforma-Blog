import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_uteq/main.dart';

void main() {
  testWidgets('LoginApp arranca y muestra el título del login', (
    WidgetTester tester,
  ) async {
    // Construye la aplicación y renderiza el primer frame en la ruta inicial (/login)
    await tester.pumpWidget(const LoginApp());
    await tester.pumpAndSettle();

    // REDISEÑO: Verifica que LoginApp cargó correctamente y muestra el título en oración de LoginPage
    expect(find.byType(LoginApp), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
