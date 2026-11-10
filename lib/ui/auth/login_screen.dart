import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../auth/validators.dart';
import '../theme.dart';
import '../three/mesh.dart';
import 'auth_widgets.dart';
import 'register_screen.dart';
import '../../l10n/lang.dart';

/// Экран входа: почта и пароль или Google.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {bool google = false}) async {
    setState(() => google ? _googleLoading = true : _loading = true);
    try {
      await action();
      if (!mounted) return;
      final user = AuthScope.read(context).user;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Вы вошли${user?.name != null ? ' как ${user!.name}' : ''}'),
      ));
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
    _run(() => auth.signInWithEmail(_email.text, _password.text));
  }

  Future<void> _forgotPassword() async {
    final error = validateEmail(_email.text);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'Введите почту — пришлём ссылку для сброса пароля'))),
      );
      return;
    }
    try {
      await AuthScope.read(context).sendPasswordReset(_email.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Если аккаунт с ${_email.text.trim()} есть, мы отправили письмо для сброса пароля'),
      ));
    } catch (e) {
      if (mounted) showAuthError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final busy = _loading || _googleLoading;
    return AuthScaffold(
      shape: Shape3D.capsule,
      title: tr(context, 'С возвращением'),
      subtitle: tr(context, 'Войдите, чтобы пользоваться аккаунтом'),
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
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: validateLoginPassword,
                  onSubmitted: (_) => _submit(),
                  enabled: !busy,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: busy ? null : _forgotPassword,
            child: Text(tr(context, 'Забыли пароль?')),
          ),
        ),
        const SizedBox(height: 8),
        AuthPrimaryButton(
          label: tr(context, 'Войти'),
          loading: _loading,
          onPressed: busy ? null : _submit,
        ),
        const OrDivider(),
        GoogleButton(
          loading: _googleLoading,
          onPressed: busy ? null : () => _run(auth.signInWithGoogle, google: true),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(tr(context, 'Нет аккаунта?'), style: TextStyle(color: AppColors.textMuted)),
            TextButton(
              onPressed: busy
                  ? null
                  : () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
                      ),
              child: Text(tr(context, 'Зарегистрироваться')),
            ),
          ],
        ),
      ],
    );
  }
}
