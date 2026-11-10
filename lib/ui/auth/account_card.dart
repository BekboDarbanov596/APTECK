import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import '../../l10n/lang.dart';

/// Карточка аккаунта для профиля: «Войти / Регистрация» или
/// имя, почта и «Выйти».
class AccountCard extends StatelessWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.maybeOf(context);
    if (auth == null) return const SizedBox.shrink();
    final user = auth.user;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: user == null ? const _SignedOut() : _SignedIn(user: user, auth: auth),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    void open(Widget page) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(context, 'Аккаунт'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            tr(context, 'Войдите или создайте аккаунт — можно через Google.'),
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => open(const LoginScreen()),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: Text(tr(context, 'Войти')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => open(const RegisterScreen()),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: Text(tr(context, 'Регистрация')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn({required this.user, required this.auth});

  final AppUser user;
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    final photo = user.photoUrl;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.greenSoft,
            foregroundImage: photo == null ? null : NetworkImage(photo),
            child: Text(
              user.initials,
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.greenDark),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name?.isNotEmpty == true ? user.name! : 'Без имени',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                if (user.email != null)
                  Text(
                    user.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr(context, 'Вы вышли из аккаунта'))),
                );
              }
            },
            child: Text(tr(context, 'Выйти')),
          ),
        ],
      ),
    );
  }
}
