import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../state/session_controller.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.initialMode = AuthMode.login});

  final AuthMode initialMode;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late AuthMode _mode;
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final email = _emailController.text.trim();

    setState(() {
      _loading = true;
      _feedback = null;
    });

    final session = context.read<SessionController>();
    String? error;
    if (_mode == AuthMode.login) {
      error = await session.login(
        LoginPayload(username: username, password: password),
      );
    } else {
      error = await session.register(
        RegisterPayload(username: username, email: email, password: password),
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      setState(() => _feedback = error);
    } else {
      // Pequeño snackbar de bienvenida y close
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _mode == AuthMode.login
                ? '¡Bienvenido de vuelta, $username!'
                : '¡Cuenta creada con éxito!',
          ),
        ),
      );
      Navigator.of(context).maybePop();
    }
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == AuthMode.login ? AuthMode.register : AuthMode.login;
      _feedback = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLogin = _mode == AuthMode.login;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // “electro” vibes ⚡
            colors: [
              cs.primaryContainer.withOpacity(0.35),
              cs.primary.withOpacity(0.35),
              cs.secondaryContainer.withOpacity(0.30),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth;
              final cardWidth = maxW < 600 ? maxW - 32 : 520.0;

              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cardWidth),
                    child: Card(
                      elevation: 10,
                      margin: const EdgeInsets.symmetric(vertical: 24),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Theme.of(context).cardColor,
                              Theme.of(context).cardColor.withOpacity(0.92),
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 6),
                            _Header(isLogin: isLogin),
                            const SizedBox(height: 16),
                            _IconRow(),
                            const SizedBox(height: 8),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: Text(
                                isLogin
                                    ? 'Ingresa con tu usuario para continuar.'
                                    : 'Crea tu cuenta para aprovechar ofertas y envíos.',
                                key: ValueKey(isLogin),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_feedback != null) ...[
                              _BannerMessage(
                                message: _feedback!,
                                color: cs.errorContainer,
                                textColor: cs.onErrorContainer,
                                icon: Icons.error_outline,
                              ),
                              const SizedBox(height: 12),
                            ],
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _usernameController,
                                    autofillHints: const [
                                      AutofillHints.username,
                                    ],
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Usuario',
                                      prefixIcon: Icon(Icons.person_outline),
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (v) {
                                      final s = v?.trim() ?? '';
                                      if (s.isEmpty)
                                        return 'Ingresa un usuario';
                                      if (s.length < 3) {
                                        return 'Mínimo 3 caracteres';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    child: isLogin
                                        ? const SizedBox.shrink()
                                        : Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: TextFormField(
                                              key: const ValueKey('emailField'),
                                              controller: _emailController,
                                              keyboardType:
                                                  TextInputType.emailAddress,
                                              autofillHints: const [
                                                AutofillHints.email,
                                              ],
                                              textInputAction:
                                                  TextInputAction.next,
                                              decoration: const InputDecoration(
                                                labelText: 'Correo electrónico',
                                                prefixIcon: Icon(
                                                  Icons.alternate_email,
                                                ),
                                                border: OutlineInputBorder(),
                                              ),
                                              validator: (v) {
                                                if (isLogin) return null;
                                                final s = v?.trim() ?? '';
                                                if (s.isEmpty) {
                                                  return 'Ingresa tu correo';
                                                }
                                                final emailRx = RegExp(
                                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                                );
                                                if (!emailRx.hasMatch(s)) {
                                                  return 'Correo inválido';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                  ),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscure,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Contraseña',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline_rounded,
                                      ),
                                      border: const OutlineInputBorder(),
                                      suffixIcon: IconButton(
                                        onPressed: () => setState(
                                          () => _obscure = !_obscure,
                                        ),
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                        ),
                                      ),
                                    ),
                                    validator: (v) {
                                      final s = v?.trim() ?? '';
                                      if (s.isEmpty) {
                                        return 'Ingresa tu contraseña';
                                      }
                                      if (s.length < 6) {
                                        return 'Mínimo 6 caracteres';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: FilledButton.icon(
                                      onPressed: _loading
                                          ? null
                                          : _handleSubmit,
                                      icon: _loading
                                          ? SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(cs.onPrimary),
                                              ),
                                            )
                                          : Icon(
                                              isLogin
                                                  ? Icons.login_rounded
                                                  : Icons
                                                        .person_add_alt_1_rounded,
                                            ),
                                      label: Text(
                                        _loading
                                            ? 'Procesando...'
                                            : isLogin
                                            ? 'Iniciar sesión'
                                            : 'Crear cuenta',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextButton(
                                    onPressed: _loading ? null : _toggleMode,
                                    child: Text(
                                      isLogin
                                          ? '¿No tienes cuenta? Crear una ahora'
                                          : '¿Ya tienes cuenta? Inicia sesión',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isLogin});
  final bool isLogin;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Logo circular con rayo ⚡
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [cs.primary, cs.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.electric_bolt_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            isLogin ? 'ElectroStore' : 'Crea tu cuenta',
            key: ValueKey(isLogin),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _IconRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    // Íconos sutiles de electrodomésticos para la estética
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.tv_rounded, color: muted),
        const SizedBox(width: 12),
        Icon(Icons.kitchen_rounded, color: muted),
        const SizedBox(width: 12),
        Icon(Icons.microwave_rounded, color: muted),
        const SizedBox(width: 12),
        Icon(Icons.blender_rounded, color: muted),
      ],
    );
  }
}

class _BannerMessage extends StatelessWidget {
  const _BannerMessage({
    required this.message,
    required this.color,
    required this.textColor,
    required this.icon,
  });

  final String message;
  final Color color;
  final Color textColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}

enum AuthMode { login, register }
