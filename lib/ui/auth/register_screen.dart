import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../auth/validators.dart';
import 'auth_widgets.dart';
import 'login_screen.dart';
import '../../l10n/lang.dart';

/// Экран регистрации: почта, пароль или Google.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {bool google = false}) async {
    setState(() => google ? _googleLoading = true : _loading = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'Аккаунт создан. Добро пожаловать!'))),
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = _googleLoading = false);
    }
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final auth = AuthScope.read(context);
    _run(() => auth.register(
          name: _email.text.trim().split('@').first,
          email: _email.text,
          password: _password.text,
        ));
  }

  void _openLogin(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final busy = _loading || _googleLoading;
    return AuthPageFrame(
      registering: true,
      onSwitch: busy ? null : () => _openLogin(context),
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              children: [
                AuthField(
                  controller: _email,
                  label: tr(context, 'Почта'),
                  icon: Icons.alternate_email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: validateEmail,
                  enabled: !busy,
                ),
                AuthField(
                  controller: _password,
                  label: tr(context, 'Пароль'),
                  icon: Icons.lock_outline,
                  obscure: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: validateNewPassword,
                  enabled: !busy,
                ),
                AuthField(
                  controller: _repeat,
                  label: tr(context, 'Повторите пароль'),
                  icon: Icons.lock_reset_outlined,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) => validatePasswordRepeat(v, _password.text),
                  onSubmitted: (_) => _submit(),
                  enabled: !busy,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 16, left: 4),
          child: Text(
            tr(context, 'Минимум 8 символов, буквы и цифры.'),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        AuthPrimaryButton(
          label: tr(context, 'Создать аккаунт'),
          loading: _loading,
          onPressed: busy ? null : _submit,
        ),
        const SizedBox(height: 12),
        GoogleButton(
          loading: _googleLoading,
          onPressed: busy ? null : () => _run(auth.signInWithGoogle, google: true),
        ),
      ],
    );
  }
}
