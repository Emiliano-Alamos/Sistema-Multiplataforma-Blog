import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_background.dart';
import '../widgets/auth_card.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

/// Pantalla de inicio de sesión. Valida el formulario, llama a la API y
/// manda al administrador al panel y al usuario general al blog.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Guardan lo que el usuario escribe en cada campo.
  final TextEditingController usuarioController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  final AuthService authService = AuthService();

  bool ocultarPassword = true; // la contraseña se muestra como puntos
  bool cargando = false; // true mientras se espera la respuesta de la API

  @override
  // Libera los controladores al cerrar la pantalla.
  void dispose() {
    usuarioController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  /// Valida los campos, inicia sesión en la API y abre la pantalla según el rol.
  Future<void> iniciarSesion() async {
    // 1. Validación local: evita ir a la API con campos vacíos.
    final mensaje = authService.validarLogin(
      usuario: usuarioController.text,
      password: passwordController.text,
    );

    if (mensaje != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensaje)));
      return;
    }

    setState(() {
      cargando = true;
    });

    try {
      // 2. Inicio de sesión en la API; si es correcto, el token queda guardado.
      final usuario = await authService.autenticar(
        correo: usuarioController.text,
        password: passwordController.text,
      );

      if (!mounted) return;

      // 3. Según el rol: 1 = Administrador (panel), 2 = Usuario general (blog).
      // pushNamedAndRemoveUntil borra el historial para que «atrás» no regrese al login.
      final int tipoUsuario = (usuario['tip_usu'] as num).toInt();

      if (tipoUsuario == 1) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/users',
          (route) => false,
          arguments: usuario,
        );
      } else if (tipoUsuario == 2) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/blog',
          (route) => false,
          arguments: usuario,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El tipo de usuario no tiene acceso asignado'),
          ),
        );
      }
    // Muestra el mensaje de la API (por ejemplo, «Correo o contraseña incorrectos»).
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          cargando = false;
        });
      }
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
              padding: const EdgeInsets.all(16),
              child: AuthCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ícono de candado dentro de un círculo.
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryTint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        size: 40,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Iniciar sesión', style: textTheme.headlineSmall),
                    const SizedBox(height: 24),
                    CustomTextField(
                      controller: usuarioController,
                      label: 'Correo electrónico',
                      prefixIcon: Icons.person_outline,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: passwordController,
                      label: 'Contraseña',
                      prefixIcon: Icons.lock_outline,
                      obscureText: ocultarPassword,
                      // Botón del ojo: muestra u oculta la contraseña.
                      suffixIcon: IconButton(
                        tooltip: ocultarPassword
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        icon: Icon(
                          ocultarPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            ocultarPassword = !ocultarPassword;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Mientras se valida, el botón cambia de texto e ignora los toques.
                    PrimaryButton(
                      text: cargando ? 'Validando...' : 'Ingresar',
                      onPressed: cargando
                          ? () {}
                          : () {
                              iniciarSesion();
                            },
                    ),
                    const SizedBox(height: 16),
                    // Enlace al registro; Wrap evita que el texto se desborde con letra grande.
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('¿No tienes cuenta?', style: textTheme.bodyMedium),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          child: const Text('Registrarse'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
