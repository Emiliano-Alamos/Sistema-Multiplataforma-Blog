import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_uteq/main.dart';

void main() {
  testWidgets('LoginApp arranca y muestra el título del login', (
    WidgetTester tester,
  ) async {
    // Construye la aplicación y renderiza el primer frame en la ruta inicial (/login)
    await tester.pumpWidget(const LoginApp());
    await tester.pumpAndSettle();

    // Verifica que LoginApp cargó y que se ve el título de la pantalla de login.
    expect(find.byType(LoginApp), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
