import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_background.dart';
import '../widgets/auth_card.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

/// Pantalla de registro. Desde el login crea un Usuario general; desde el
/// panel, el administrador además puede elegir el tipo de usuario.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController correoController = TextEditingController();
  final TextEditingController direccionController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmarController = TextEditingController();

  final AuthService authService = AuthService();

  // Datos del administrador si se abrió desde el panel (null = desde el login).
  Map<String, dynamic>? administradorActual;
  bool argumentosLeidos = false; // evita leer los argumentos más de una vez
  bool registrando = false; // true mientras se espera la respuesta de la API
  int tipoUsuario = 2; // 1 = Administrador, 2 = Usuario general

  @override
  // Lee los argumentos de la ruta para saber si entró un administrador.
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (argumentosLeidos) return;

    final argumento = ModalRoute.of(context)?.settings.arguments;
    if (argumento is Map<String, dynamic> &&
        (argumento['tip_usu'] as num?)?.toInt() == 1) {
      administradorActual = Map<String, dynamic>.from(argumento);
    }
    argumentosLeidos = true;
  }

  @override
  // Libera los controladores al cerrar la pantalla.
  void dispose() {
    nombreController.dispose();
    correoController.dispose();
    direccionController.dispose();
    passwordController.dispose();
    confirmarController.dispose();
    super.dispose();
  }

  /// Valida el formulario, registra al usuario en la API y limpia los campos.
  Future<void> registrarUsuario() async {
    if (registrando) return; // evita envíos dobles

    // Validación local antes de llamar a la API.
    final mensaje = authService.validarRegistro(
      nombre: nombreController.text.trim(),
      correo: correoController.text.trim(),
      password: passwordController.text,
      confirmarpassword: confirmarController.text,
    );

    if (mensaje != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensaje)));
      return;
    }

    setState(() {
      registrando = true;
    });

    try {
      await authService.registrarUsuario(
        nombre: nombreController.text.trim(),
        correo: correoController.text.trim(),
        password: passwordController.text,
        direccion: direccionController.text.trim().isEmpty
            ? null
            : direccionController.text.trim(),
        // Desde el login siempre se registra un Usuario general.
        tipoUsuario: administradorActual != null ? tipoUsuario : 2,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario registrado correctamente')),
      );

      nombreController.clear();
      correoController.clear();
      direccionController.clear();
      passwordController.clear();
      confirmarController.clear();
      setState(() {
        tipoUsuario = 2;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          registrando = false;
        });
      }
    }
  }

  /// Regresa al panel (conservando los datos del administrador) o al login.
  void volver() {
    if (administradorActual != null) {
      Navigator.pushReplacementNamed(
        context,
        '/users',
        arguments: administradorActual,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Center(
            // El scroll evita que el teclado o pantallas pequeñas corten el formulario.
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: AuthCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ícono dentro de un círculo.
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryTint,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_add_outlined,
                          size: 40,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // El título cambia según quién registra.
                      Text(
                        administradorActual != null
                            ? 'Registrar usuario'
                            : 'Crear cuenta',
                        style: textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      CustomTextField(
                        controller: nombreController,
                        label: 'Nombre completo',
                        prefixIcon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: correoController,
                        label: 'Correo electrónico',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      // La dirección es opcional.
                      CustomTextField(
                        controller: direccionController,
                        label: 'Dirección (opcional)',
                        prefixIcon: Icons.home_outlined,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: passwordController,
                        label: 'Contraseña',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      // Se pide dos veces para evitar errores de escritura.
                      CustomTextField(
                        controller: confirmarController,
                        label: 'Confirmar contraseña',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                      ),
                      if (administradorActual != null) ...[
                        const SizedBox(height: 16),
                        // El selector de tipo de usuario solo aparece para el administrador.
                        DropdownButtonFormField<int>(
                          key: ValueKey(tipoUsuario), // se reconstruye si tipoUsuario cambia (también al limpiar)
                          initialValue: tipoUsuario,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de usuario',
                            prefixIcon: Icon(Icons.people_outline),
                          ),
                          items: const [
                            DropdownMenuItem<int>(
                              value: 1,
                              child: Text('Administrador'),
                            ),
                            DropdownMenuItem<int>(
                              value: 2,
                              child: Text('Usuario general'),
                            ),
                          ],
                          onChanged: registrando
                              ? null
                              : (valor) {
                                  if (valor != null) {
                                    setState(() {
                                      tipoUsuario = valor;
                                    });
                                  }
                                },
                        ),
                      ],
                      const SizedBox(height: 24),
                      // Mientras registra, el botón cambia de texto e ignora los toques.
                      PrimaryButton(
                        text: registrando ? 'Registrando...' : 'Registrarme',
                        onPressed: registrando ? () {} : registrarUsuario,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: volver,
                        child: Text(
                          administradorActual != null
                              ? 'Volver a Gestión de usuarios'
                              : 'Ya tengo una cuenta',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
