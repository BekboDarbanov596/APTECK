import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../auth/validators.dart';
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

  Future<void> _run(
    Future<void> Function() action, {
    bool google = false,
  }) async {
    setState(() => google ? _googleLoading = true : _loading = true);
    try {
      await action();
      if (!mounted) return;
      final user = AuthScope.read(context).user;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            user?.name != null
                ? tr(context, 'Вы вошли как {n}', {'n': user!.name!})
                : tr(context, 'Вы вошли'),
          ),
        ),
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
    _run(() => auth.signInWithEmail(_email.text, _password.text));
  }

  Future<void> _forgotPassword() async {
    final error = validateEmail(_email.text);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(context, 'Введите почту — пришлём ссылку для сброса пароля'),
          ),
        ),
      );
      return;
    }
    try {
      await AuthScope.read(context).sendPasswordReset(_email.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              'Если аккаунт с {e} есть, мы отправили письмо для сброса пароля',
              {'e': _email.text.trim()},
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) showAuthError(context, e);
    }
  }

  void _openRegistration(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final busy = _loading || _googleLoading;
    return AuthPageFrame(
      registering: false,
      onSwitch: busy ? null : () => _openRegistration(context),
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
        const SizedBox(height: 12),
        GoogleButton(
          loading: _googleLoading,
          onPressed: busy
              ? null
              : () => _run(auth.signInWithGoogle, google: true),
        ),
      ],
    );
  }
}

/// Общий экран входа и регистрации.
class AuthPageFrame extends StatelessWidget {
  const AuthPageFrame({
    super.key,
    required this.registering,
    required this.onSwitch,
    required this.children,
  });

  final bool registering;
  final VoidCallback? onSwitch;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    const panel = Color(0xFF383F30);
    const ink = Color(0xFFF3EFE3);
    const muted = Color(0xFFCED3C2);
    const outline = Color(0xFF87968A);
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF829575),
      brightness: Brightness.dark,
      surface: panel,
      onSurface: ink,
      onSurfaceVariant: muted,
      primary: ink,
      onPrimary: const Color(0xFF283122),
      outline: outline,
    );

    return Theme(
      data: ThemeData(useMaterial3: true, colorScheme: colors),
      child: Scaffold(
        backgroundColor: const Color(0xFF252B20),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/auth/forest-matte.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              excludeFromSemantics: true,
            ),
            const ColoredBox(color: Color(0x4430392B)),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 42, 22, 24),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
                      decoration: BoxDecoration(
                        color: panel,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF65705B)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.eco_outlined,
                                size: 29,
                                color: ink,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  tr(context, 'Аптека рядом'),
                                  style: const TextStyle(
                                    color: ink,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const ExcludeSemantics(
                                child: Icon(
                                  Icons.spa_outlined,
                                  size: 27,
                                  color: Color(0xFF879482),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              for (final (active, label) in [
                                (!registering, 'Вход'),
                                (registering, 'Регистрация'),
                              ])
                                Expanded(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          width: active ? 2.5 : 1,
                                          color: active
                                              ? ink
                                              : const Color(0xFF707B65),
                                        ),
                                      ),
                                    ),
                                    child: TextButton(
                                      onPressed: active ? null : onSwitch,
                                      style: TextButton.styleFrom(
                                        foregroundColor: muted,
                                        disabledForegroundColor: active
                                            ? ink
                                            : muted,
                                        textStyle: TextStyle(
                                          fontSize: 15,
                                          fontWeight: active
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                      child: Text(tr(context, label)),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (auth.status == AuthStatus.notConfigured) ...[
                            const AuthNotConfiguredBanner(),
                            const SizedBox(height: 12),
                          ],
                          ...children,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (Navigator.of(context).canPop())
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      tooltip: tr(context, 'Назад'),
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFE8EBDD),
                        foregroundColor: panel,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
