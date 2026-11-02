import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import '../../widgets/pip.dart';
import '../../widgets/vastra_widgets.dart';
import 'auth_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() => _error = null);
    try {
      await context.read<AuthController>().signIn(email: _email.text, password: _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Type your email above, then tap “Forgot password?” again.');
      return;
    }
    try {
      await context.read<AuthController>().sendPasswordReset(email);
      if (!mounted) return;
      setState(() => _error = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reset link sent to $email')));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AuthController>().busy;
    return AuthLayout(
      title: 'Welcome back',
      subtitle: 'Your closet is right where you left it.',
      pipPose: PipPose.cheeky,
      pipSays: 'Look who’s back, gorgeous! I kept everything pinned for you.',
      children: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            ),
          ),
        ),
        if (_error != null) ...[const SizedBox(height: 14), VastraMessage(_error!, isError: true)],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: _resetPassword, child: const Text('Forgot password?')),
        ),
        const SizedBox(height: 8),
        VastraPrimaryButton(label: 'Sign in', busy: busy, onPressed: _submit),
        const SizedBox(height: 8),
        TextButton(onPressed: () => context.go('/signup'), child: const Text('New here? Create an account')),
      ],
    );
  }
}
