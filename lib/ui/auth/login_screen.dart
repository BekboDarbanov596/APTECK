import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../auth/validators.dart';
import '../theme.dart';
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
          onPressed: busy
              ? null
              : () => _run(auth.signInWithGoogle, google: true),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              tr(context, 'Нет аккаунта?'),
              style: TextStyle(color: AppColors.textMuted),
            ),
            TextButton(
              onPressed: busy ? null : () => _openRegistration(context),
              child: Text(tr(context, 'Зарегистрироваться')),
            ),
          ],
        ),
      ],
    );
  }
}

/// Лёгкая карточка авторизации, используемая обоими экранами.
class AuthPageFrame extends StatelessWidget {
  const AuthPageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.greenFill,
          foregroundColor: Colors.white,
        ),
      ),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: AppColors.background),
            Positioned(
              top: -150,
              right: -120,
              child: _AuthOrb(
                size: 300,
                color: AppColors.dark
                    ? const Color(0xFF16261C)
                    : const Color(0xFFDDEFE3),
              ),
            ),
            Positioned(
              bottom: -180,
              left: -130,
              child: _AuthOrb(
                size: 260,
                color: AppColors.dark
                    ? const Color(0xFF142019)
                    : const Color(0xFFE7F0EA),
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 30, 16, 24),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
                      decoration: BoxDecoration(
                        color: AppColors.dark
                            ? AppColors.surface
                            : const Color(0xFFF9FBF9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x120F3B29),
                            blurRadius: 34,
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.greenSoft,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.local_pharmacy_outlined,
                                color: AppColors.greenDark,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 28,
                              height: 1.15,
                              letterSpacing: -0.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 22),
                          // Firebase не подключён — честно говорим, что вход недоступен.
                          if (AuthScope.of(context).status ==
                              AuthStatus.notConfigured) ...[
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
                    child: IconButton.filledTonal(
                      tooltip: tr(context, 'Назад'),
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.greenDark,
                        side: BorderSide(color: AppColors.border),
                      ),
                      icon: const Icon(Icons.arrow_back),
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

class _AuthOrb extends StatelessWidget {
  const _AuthOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
