import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart'; // REDISEÑO
import '../widgets/auth_background.dart';
import '../widgets/auth_card.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

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

  Map<String, dynamic>? administradorActual;
  bool argumentosLeidos = false;
  bool registrando = false;
  int tipoUsuario = 2; // 1 = Administrador, 2 = Usuario general

  @override
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
  void dispose() {
    nombreController.dispose();
    correoController.dispose();
    direccionController.dispose();
    passwordController.dispose();
    confirmarController.dispose();
    super.dispose();
  }

  Future<void> registrarUsuario() async {
    if (registrando) return;

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
        // NUEVO: Desde inicio de sesion siempre se registra usuario general.
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

  // NUEVO: Regresar al panel conservando los datos del administrador.
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
    final textTheme = Theme.of(context).textTheme; // REDISEÑO

    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Center(
            // REDISEÑO: Scroll adaptable en pantallas pequeñas con márgenes en múltiplos de 8
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: AuthCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // REDISEÑO: Ícono outlined en primaryDark dentro de círculo primaryTint (Secciones 2 y 6)
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
                      // REDISEÑO: Título en oración para ambos modos con escala 24 bold textPrimary
                      Text(
                        administradorActual != null
                            ? 'Registrar usuario'
                            : 'Crear cuenta',
                        style: textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      // REDISEÑO: Íconos outlined en todos los campos según Sección 5 de la guía
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
                      // NUEVO: La direccion se guarda en la misma tabla usuario.
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
                      // NUEVO: Confirmar la contraseña para validarla correctamente.
                      CustomTextField(
                        controller: confirmarController,
                        label: 'Confirmar contraseña',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                      ),
                      if (administradorActual != null) ...[
                        const SizedBox(height: 16),
                        // NUEVO: Solo en el panel se muestra el tipo de usuario.
                        // REDISEÑO: Dropdown hereda borde y relleno de inputDecorationTheme con ícono outlined
                        DropdownButtonFormField<int>(
                          value: tipoUsuario,
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
                      // REDISEÑO: Textos del botón primario en oración según Sección 5
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
