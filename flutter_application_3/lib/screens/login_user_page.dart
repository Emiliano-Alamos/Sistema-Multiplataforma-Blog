import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart'; // REDISEÑO
import '../widgets/auth_background.dart';
import '../widgets/auth_card.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usuarioController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  final AuthService authService = AuthService();

  bool ocultarPassword = true;
  bool cargando = false;

  @override
  void dispose() {
    usuarioController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  Future<void> iniciarSesion() async {
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
      final usuario = await authService.autenticar(
        correo: usuarioController.text,
        password: passwordController.text,
      );

      if (!mounted) return;

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
    final textTheme = Theme.of(context).textTheme; // REDISEÑO

    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Center(
            // REDISEÑO: Scroll y margen exterior de 16 px para adaptabilidad en pantallas de 390 px y escalado de texto
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AuthCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // REDISEÑO: Candado outlined en primaryDark dentro de círculo primaryTint (sustituye candado amarillo)
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
                    // REDISEÑO: Título en oración con escala de título de pantalla (24 bold textPrimary)
                    Text('Iniciar sesión', style: textTheme.headlineSmall),
                    const SizedBox(height: 24),
                    // REDISEÑO: Ícono outlined consistente con el mockup M1 y la sección 5 de la guía
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        // LÓGICA AUTORIZADA 3
                        onPressed: () {
                          Navigator.pushNamed(context, '/recover');
                        },
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // REDISEÑO: Textos del botón primario en oración según sección 5
                    PrimaryButton(
                      text: cargando ? 'Validando...' : 'Ingresar',
                      onPressed: cargando
                          ? () {}
                          : () {
                              iniciarSesion();
                            },
                    ),
                    const SizedBox(height: 16),
                    // REDISEÑO: Wrap con crossAxisAlignment centrado para evitar overflow con escalado de fuente (Sección 7)
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
