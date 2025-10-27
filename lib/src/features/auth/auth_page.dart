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
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final email = _emailController.text.trim();

    if (username.isEmpty || password.isEmpty || (_mode == AuthMode.register && email.isEmpty)) {
      setState(() => _feedback = 'Completa los campos requeridos.');
      return;
    }

    setState(() {
      _loading = true;
      _feedback = null;
    });

    final session = context.read<SessionController>();
    String? error;
    if (_mode == AuthMode.login) {
      error = await session.login(LoginPayload(username: username, password: password));
    } else {
      error = await session.register(
        RegisterPayload(username: username, email: email, password: password),
      );
    }

    if (mounted) {
      setState(() => _loading = false);
      if (error != null) {
        setState(() => _feedback = error);
      } else {
        Navigator.of(context).maybePop();
      }
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_mode == AuthMode.login ? 'Iniciar sesión' : 'Crear cuenta'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              _mode == AuthMode.login
                  ? 'Ingresa con tu usuario para continuar.'
                  : 'Completa los datos y te registraremos automáticamente.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Usuario',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_mode == AuthMode.register)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _handleSubmit,
                child: Text(_loading
                    ? 'Procesando...'
                    : _mode == AuthMode.login
                        ? 'Iniciar sesión'
                        : 'Registrarme'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loading ? null : _toggleMode,
              child: Text(
                _mode == AuthMode.login
                    ? '¿No tienes cuenta? Crear una ahora'
                    : '¿Ya tienes cuenta? Inicia sesión',
              ),
            ),
            if (_feedback != null) ...[
              const SizedBox(height: 12),
              Text(
                _feedback!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum AuthMode { login, register }
