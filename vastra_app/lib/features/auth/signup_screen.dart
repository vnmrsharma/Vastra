import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import '../../theme/vastra_colors.dart';
import '../../widgets/pip.dart';
import '../../widgets/vastra_widgets.dart';
import 'auth_layout.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _consent = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'What should we call you?');
      return;
    }
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Add your email.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Password needs at least 6 characters.');
      return;
    }
    if (!_consent) {
      setState(() => _error = 'Please agree to AI photo processing to continue.');
      return;
    }
    setState(() => _error = null);
    try {
      await context.read<AuthController>().signUp(
        email: _email.text,
        password: _password.text,
        displayName: _name.text.trim(),
      );
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AuthController>().busy;
    return AuthLayout(
      title: 'Create your wardrobe',
      pipPose: PipPose.letsStyle,
      pipSays: 'Ooh, a new friend! Let’s get you set up — it only takes a minute.',
      subtitle: 'Takes a minute. We’ll set up your style and closet right after.',
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person_outline_rounded)),
        ),
        const SizedBox(height: 12),
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
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: 'Password',
            helperText: 'At least 6 characters',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            ),
          ),
        ),
        const SizedBox(height: 14),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _consent = !_consent),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: VastraColors.ivory, borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _consent,
                  onChanged: (v) => setState(() => _consent = v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'I agree that Vastra can process my photos with Gemini and YouCam AI for styling and virtual try-on. Photos stay private to my account.',
                    style: GoogleFonts.outfit(fontSize: 13, height: 1.4, color: VastraColors.chocolate),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[const SizedBox(height: 14), VastraMessage(_error!, isError: true)],
        const SizedBox(height: 22),
        VastraPrimaryButton(label: 'Continue', busy: busy, onPressed: _submit),
        const SizedBox(height: 8),
        TextButton(onPressed: () => context.go('/login'), child: const Text('Already have an account? Sign in')),
      ],
    );
  }
}
