import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../data/models.dart';
import '../l10n/lang.dart';
import '../state/app_state.dart';
import 'auth/login_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/profile_preferences.dart';

/// Профиль: аватар и карточка со счётчиками, призыв войти,
/// затем чистые группы настроек (язык, геолокация, поиск, данные).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.onOpenFavorites, this.onDrugPicked});
  final VoidCallback? onOpenFavorites;
  final ValueChanged<Drug>? onDrugPicked;

  void _history(BuildContext context, AppState state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => SafeArea(
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) => ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                Text(
                  tr(context, 'История поиска'),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.7),
                ),
                const SizedBox(height: 10),
                if (state.recentDrugIds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      tr(context, 'Здесь появятся лекарства, которые вы искали.'),
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                for (final id in state.recentDrugIds)
                  if (state.catalog?.drug(id) case final Drug drug)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history_rounded, color: AppColors.text),
                      title: Text(drug.title),
                      subtitle: Text(drug.subtitle),
                      trailing: onDrugPicked == null ? null : const Icon(Icons.north_east_rounded, size: 17),
                      onTap: onDrugPicked == null
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              onDrugPicked!(drug);
                            },
                    ),
                if (state.recentDrugIds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(tr(context, 'Очистить историю поиска')),
                    onPressed: () {
                      state.clearHistory();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr(context, 'История поиска очищена'))),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _language(BuildContext context) {
    final controller = LangScope.maybeOf(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 14),
                child: Text(
                  tr(context, 'Язык интерфейса'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              SettingsGroup(
                children: [
                  for (final l in AppLang.values)
                    SettingsRow(
                      icon: Icons.language_rounded,
                      title: l.title,
                      value: l.short,
                      chevron: false,
                      trailing: langOf(context) == l
                          ? const Padding(
                              padding: EdgeInsets.only(left: 10),
                              child: Icon(Icons.check_circle_rounded, color: AppColors.green),
                            )
                          : const SizedBox(width: 34),
                      onTap: controller == null
                          ? null
                          : () {
                              controller.set(l);
                              Navigator.pop(context);
                            },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _about(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: AppColors.background,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LogoMark(size: 42),
                const SizedBox(height: 18),
                Text(
                  tr(context, 'Аптека рядом'),
                  style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(context, 'Находите лекарства, сравнивайте цены и выбирайте удобную аптеку в Бишкеке.'),
                  style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                Text(
                  tr(context, 'Версия 1.0.0 · Бишкек'),
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      );

  void _dataSources(BuildContext context, bool? demo) {
    if (demo == true) {
      showDemoInfo(context);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'Источники данных')),
        content: Text(tr(
          context,
          demo == null ? 'Каталог ещё загружается.' : 'Информация поступает из подключённых аптек.',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr(context, 'Понятно'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final auth = AuthScope.maybeOf(context);
    final user = auth?.user;
    final saved = state.favoriteDrugIds.length + state.favoritePharmacyIds.length;
    final demo = state.catalog?.isDemo;
    final pharmacies = state.catalog?.pharmacies.length ?? 0;

    final location = switch (state.locationStatus) {
      LocationStatus.device => 'Включена',
      LocationStatus.loading => 'Определяем…',
      LocationStatus.denied => 'Нет доступа',
      LocationStatus.disabled => 'Выключена',
      LocationStatus.failed => 'Недоступна',
      LocationStatus.unknown => 'Не настроена',
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
              children: [
                // Заголовок и кнопка языка.
                Row(
                  children: [
                    if (Navigator.of(context).canPop()) ...[
                      _RoundIcon(
                        icon: Icons.arrow_back_rounded,
                        tooltip: tr(context, 'Назад'),
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        tr(context, 'Профиль'),
                        style: const TextStyle(
                          fontFamily: 'Unbounded',
                          fontVariations: [FontVariation('wght', 700)],
                          fontSize: 28,
                          letterSpacing: -0.8,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    _RoundIcon(
                      icon: Icons.translate_rounded,
                      tooltip: tr(context, 'Язык'),
                      onTap: () => _language(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Аватар над карточкой.
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 50),
                      padding: const EdgeInsets.fromLTRB(16, 58, 16, 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0F0E2A1C), blurRadius: 30, offset: Offset(0, 10)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user == null
                                          ? tr(context, 'Гость')
                                          : (user.name?.isNotEmpty == true ? user.name! : tr(context, 'Без имени')),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user?.email ?? tr(context, 'Без аккаунта'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: AppColors.text,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.place_rounded, size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      tr(context, 'Бишкек'),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _Stat(
                                  value: saved,
                                  label: tr(context, 'В избранном'),
                                  onTap: onOpenFavorites,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _Stat(
                                  value: state.recentDrugIds.length,
                                  label: tr(context, 'Поиски'),
                                  onTap: () => _history(context, state),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _Stat(value: pharmacies, label: tr(context, 'Аптек')),
                              ),
                            ],
                          ),
                          if (auth != null) ...[
                            const SizedBox(height: 12),
                            _AccountBar(auth: auth, user: user),
                          ],
                        ],
                      ),
                    ),
                    _Avatar(user: user),
                  ],
                ),
                const SizedBox(height: 24),

                // Общие настройки.
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.favorite_border_rounded,
                      title: tr(context, 'Избранное'),
                      value: '$saved',
                      onTap: onOpenFavorites,
                    ),
                    SettingsRow(
                      icon: Icons.translate_rounded,
                      title: tr(context, 'Язык'),
                      value: langOf(context).title,
                      onTap: () => _language(context),
                    ),
                    SettingsRow(
                      icon: Icons.near_me_outlined,
                      title: tr(context, 'Геолокация'),
                      value: tr(context, location),
                      onTap: state.locationStatus == LocationStatus.loading
                          ? null
                          : () {
                              state.refreshLocation();
                              if (state.locationStatus == LocationStatus.denied) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(tr(context, 'Разрешите геолокацию в настройках браузера или устройства.')),
                                ));
                              }
                            },
                    ),
                    SettingsRow(
                      icon: Icons.history_rounded,
                      title: tr(context, 'Недавние поиски'),
                      value: '${state.recentDrugIds.length}',
                      onTap: () => _history(context, state),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ProfilePreferences(state: state),
                const SizedBox(height: 14),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.layers_outlined,
                      title: tr(context, 'Источники данных'),
                      value: demo == true ? 'Demo' : null,
                      onTap: () => _dataSources(context, demo),
                    ),
                    SettingsRow(
                      icon: Icons.info_outline_rounded,
                      title: tr(context, 'О приложении'),
                      value: '1.0.0',
                      onTap: () => _about(context),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  tr(context, 'Избранное и история хранятся на этом устройстве.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icon, color: AppColors.text, size: 22),
          style: IconButton.styleFrom(minimumSize: const Size.square(46)),
        ),
      );
}

/// Круглый аватар с белой обводкой: фото, инициалы или силуэт.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final photo = user?.photoUrl;
    return Container(
      width: 100,
      height: 100,
      padding: const EdgeInsets.all(5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(color: Color(0x1A0E2A1C), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6BC57E), AppColors.greenDark],
          ),
          image: photo == null ? null : DecorationImage(image: NetworkImage(photo), fit: BoxFit.cover),
        ),
        alignment: Alignment.center,
        child: photo != null
            ? null
            : user == null
                ? const Icon(Icons.person_rounded, color: Colors.white, size: 46)
                : Text(
                    user!.initials,
                    style: const TextStyle(
                      fontFamily: 'Unbounded',
                      fontVariations: [FontVariation('wght', 700)],
                      fontSize: 28,
                      color: Colors.white,
                    ),
                  ),
      ),
    );
  }
}

/// Плитка-счётчик в карточке профиля.
class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.onTap});

  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontFamily: 'Unbounded',
                  fontVariations: [FontVariation('wght', 600)],
                  fontSize: 22,
                  height: 1,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Тёмная плашка внизу карточки: «Войдите» или аккаунт с кнопкой «Выйти».
class _AccountBar extends StatelessWidget {
  const _AccountBar({required this.auth, required this.user});

  final AuthService auth;
  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final signedIn = user != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B3A33), Color(0xFF17201B)],
        ),
      ),
      child: Row(
        children: [
          Icon(
            signedIn ? Icons.verified_user_rounded : Icons.star_rounded,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, signedIn ? 'Аккаунт' : 'Войдите в аккаунт'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  tr(context, 'Избранное будет с вами на любом устройстве'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, height: 1.25, color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () async {
              if (!signedIn) {
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
                return;
              }
              final messenger = ScaffoldMessenger.of(context);
              final text = tr(context, 'Вы вышли из аккаунта');
              await auth.signOut();
              messenger.showSnackBar(SnackBar(content: Text(text)));
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.text,
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            child: Text(tr(context, signedIn ? 'Выйти' : 'Войти')),
          ),
        ],
      ),
    );
  }
}
