import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../theme.dart';
import '../three/mesh.dart';
import '../three/object3d.dart';
import '../widgets/motion.dart';
import '../../l10n/lang.dart';

/// Общий каркас экранов входа и регистрации: 3D-объект, заголовок, форма.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.shape,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final Shape3D shape;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              children: [
                Center(child: Object3D(shape: shape, size: 120)),
                const SizedBox(height: 4),
                FlipIn(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.1),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),
                if (auth.status == AuthStatus.notConfigured) ...[
                  const AuthNotConfiguredBanner(),
                  const SizedBox(height: 16),
                ],
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthNotConfiguredBanner extends StatelessWidget {
  const AuthNotConfiguredBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      tr(context, 'Вход пока недоступен. Firebase-проект ещё не настроен.'),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.4,
      ),
    );
  }
}

/// Поле ввода в стиле приложения.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.obscure = false,
    this.onSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscure;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(dark ? 10 : 16),
          borderSide: BorderSide(color: c, width: w),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: widget.controller,
        validator: widget.validator,
        enabled: widget.enabled,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        obscureText: _hidden,
        onFieldSubmitted: widget.onSubmitted,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: Icon(widget.icon),
          filled: true,
          fillColor: dark ? const Color(0xFF2C3121) : AppColors.surface,
          border: border(Colors.transparent),
          enabledBorder: border(dark ? theme.colorScheme.outline : Colors.transparent),
          focusedBorder: border(dark ? theme.colorScheme.primary : AppColors.green, 1.5),
          errorBorder: border(Colors.red.shade300),
          focusedErrorBorder: border(Colors.red.shade400, 1.5),
          suffixIcon: widget.obscure
              ? IconButton(
                  tooltip: tr(context, _hidden ? 'Показать пароль' : 'Скрыть пароль'),
                  onPressed: () => setState(() => _hidden = !_hidden),
                  icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                )
              : null,
        ),
      ),
    );
  }
}

/// Основная зелёная кнопка с индикатором загрузки.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: loading
            ? const SizedBox.square(
                key: ValueKey('loading'),
                dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Text(label, key: const ValueKey('label')),
      ),
    );
  }
}

/// Кнопка «Продолжить с Google».
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.onPressed, this.loading = false});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: dark ? Colors.transparent : AppColors.surface,
        foregroundColor: dark ? theme.colorScheme.onSurface : AppColors.text,
        side: BorderSide(color: dark ? theme.colorScheme.outline : AppColors.border),
      ),
      child: loading
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _GoogleMark(),
                SizedBox(width: 12),
                Flexible(
                  child: Text(
                    tr(context, 'Продолжить с Google'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Буква G в цветах Google. Перед публикацией в магазине заменить
/// на официальный значок из Google Sign-In Branding Guidelines.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const SweepGradient(
        colors: [
          Color(0xFFEA4335),
          Color(0xFFFBBC05),
          Color(0xFF34A853),
          Color(0xFF4285F4),
          Color(0xFFEA4335),
        ],
        stops: [0, 0.25, 0.5, 0.75, 1],
      ).createShader(rect),
      child: const Text(
        'G',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
      ),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                tr(context, 'или'),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            Expanded(child: Divider()),
          ],
        ),
      );
}

/// Показать ошибку входа. Отмену человеком не показываем.
void showAuthError(BuildContext context, Object error) {
  if (error is AuthCancelled) return;
  final text = error is AuthFailure ? tr(context, error.message) : tr(context, 'Что-то пошло не так. Попробуйте ещё раз.');
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
