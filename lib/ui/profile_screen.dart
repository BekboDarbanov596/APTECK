import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../data/models.dart';
import '../l10n/lang.dart';
import '../state/app_state.dart';
import '../state/theme_state.dart';
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
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                Text(
                  tr(context, 'История поиска'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 10),
                if (state.recentDrugIds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      tr(
                        context,
                        'Здесь появятся лекарства, которые вы искали.',
                      ),
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                for (final id in state.recentDrugIds)
                  if (state.catalog?.drug(id) case final Drug drug)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.history_rounded,
                        color: AppColors.text,
                      ),
                      title: Text(drug.title),
                      subtitle: Text(drug.subtitle),
                      trailing: onDrugPicked == null
                          ? null
                          : const Icon(Icons.north_east_rounded, size: 17),
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
                        SnackBar(
                          content: Text(tr(context, 'История поиска очищена')),
                        ),
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

  static String _themeLabel(AppThemeMode m) => switch (m) {
    AppThemeMode.light => 'Светлая',
    AppThemeMode.dark => 'Тёмная',
    AppThemeMode.system => 'Как в системе',
  };

  /// Выбор темы: светлая, тёмная (ночная, как в 2ГИС) или как в системе.
  void _theme(BuildContext context, ThemeController controller) {
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
                  tr(context, 'Тема'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SettingsGroup(
                children: [
                  for (final (mode, icon) in const [
                    (AppThemeMode.light, Icons.light_mode_rounded),
                    (AppThemeMode.dark, Icons.dark_mode_rounded),
                    (AppThemeMode.system, Icons.brightness_auto_rounded),
                  ])
                    SettingsRow(
                      icon: icon,
                      title: tr(context, _themeLabel(mode)),
                      chevron: false,
                      trailing: controller.mode == mode
                          ? Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.green,
                              ),
                            )
                          : const SizedBox(width: 34),
                      onTap: () {
                        controller.set(mode);
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
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
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
                          ? Padding(
                              padding: EdgeInsets.only(left: 10),
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.green,
                              ),
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
              tr(
                context,
                'Находите лекарства, сравнивайте цены и выбирайте удобную аптеку в Бишкеке.',
              ),
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              tr(context, 'Версия 1.0.0 · Бишкек'),
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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
        content: Text(
          tr(
            context,
            demo == null
                ? 'Каталог ещё загружается.'
                : 'Информация поступает из подключённых аптек.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'Понятно')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final auth = AuthScope.maybeOf(context);
    final user = auth?.user;
    final saved =
        state.favoriteDrugIds.length + state.favoritePharmacyIds.length;
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

    // Низ страницы: бежевый днём, тёмный ночью.
    final paper = AppColors.dark ? AppColors.background : const Color(0xFFECE7DA);
    return Scaffold(
      backgroundColor: paper,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/auth/forest-matte.jpg'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            colorFilter: ColorFilter.mode(Color(0x55303224), BlendMode.srcOver),
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [const Color(0x66202117), paper.withValues(alpha: 0), paper],
              stops: [0, 0.14, 0.36],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
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
                              fontFamily: 'Georgia',
                              fontFamilyFallback: ['serif'],
                              fontSize: 32,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFF3EFE3),
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
                    const SizedBox(height: 26),

                    // Карточка пользователя.
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF363D2F),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: const Color(0xFF737862)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              _Avatar(user: user),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user == null
                                          ? tr(context, 'Гость')
                                          : (user.name?.isNotEmpty == true
                                                ? user.name!
                                                : tr(context, 'Без имени')),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Georgia',
                                        fontFamilyFallback: ['serif'],
                                        fontSize: 25,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFFF3EFE3),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user?.email ??
                                          tr(context, 'Без аккаунта'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFFCED3C2),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE9E4D4),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.place_rounded,
                                            size: 14,
                                            color: AppColors.greenDark,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            tr(context, 'Бишкек'),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.greenDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: Color(0xFF65705B)),
                          Row(
                            children: [
                              Expanded(
                                child: _Stat(
                                  value: saved,
                                  label: tr(context, 'В избранном'),
                                  onTap: onOpenFavorites,
                                ),
                              ),
                              Expanded(
                                child: _Stat(
                                  value: state.recentDrugIds.length,
                                  label: tr(context, 'Поиски'),
                                  onTap: () => _history(context, state),
                                ),
                              ),
                              Expanded(
                                child: _Stat(
                                  value: pharmacies,
                                  label: tr(context, 'Аптек'),
                                ),
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
                    const SizedBox(height: 22),

                    SettingsCaption(
                      tr(context, 'Основное'),
                      color: AppColors.dark ? null : const Color(0xFF343C2D),
                    ),
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
                        if (ThemeScope.maybeOf(context) case final theme?)
                          SettingsRow(
                            icon: AppColors.dark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            title: tr(context, 'Тема'),
                            value: tr(context, _themeLabel(theme.mode)),
                            onTap: () => _theme(context, theme),
                          ),
                        SettingsRow(
                          icon: Icons.near_me_outlined,
                          title: tr(context, 'Геолокация'),
                          value: tr(context, location),
                          onTap: state.locationStatus == LocationStatus.loading
                              ? null
                              : () {
                                  state.refreshLocation();
                                  if (state.locationStatus ==
                                      LocationStatus.denied) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          tr(
                                            context,
                                            'Разрешите геолокацию в настройках браузера или устройства.',
                                          ),
                                        ),
                                      ),
                                    );
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
                    const SizedBox(height: 22),
                    SettingsCaption(
                      tr(context, 'Поиск'),
                      color: AppColors.dark ? null : const Color(0xFF343C2D),
                    ),
                    ProfilePreferences(state: state),
                    const SizedBox(height: 22),
                    SettingsCaption(
                      tr(context, 'О приложении'),
                      color: AppColors.dark ? null : const Color(0xFF343C2D),
                    ),
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
                      tr(
                        context,
                        'Избранное и история хранятся на этом устройстве.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.dark
                            ? AppColors.textMuted
                            : const Color(0xFF515A4C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(icon, size: 22),
    style: IconButton.styleFrom(
      backgroundColor: AppColors.dark ? AppColors.surface : const Color(0xFFFCFDFB),
      foregroundColor: AppColors.text,
      minimumSize: const Size.square(46),
      side: BorderSide(
        color: AppColors.dark ? AppColors.border : const Color(0xFFDDE5DC),
      ),
    ),
  );
}

/// Фото, инициалы или силуэт гостя.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final photo = user?.photoUrl;
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE1EDE2),
        image: photo == null
            ? null
            : DecorationImage(image: NetworkImage(photo), fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: photo != null
          ? null
          : user == null
          ? Icon(
              Icons.person_outline_rounded,
              color: AppColors.greenDark,
              size: 30,
            )
          : Text(
              user!.initials,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.greenDark,
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
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: Color(0xFFF3EFE3),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFFCED3C2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Действие с аккаунтом в карточке профиля.
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
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF454E3B),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, signedIn ? 'Аккаунт' : 'Войдите в аккаунт'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF3EFE3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () async {
              if (!signedIn) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                );
                return;
              }
              final messenger = ScaffoldMessenger.of(context);
              final text = tr(context, 'Вы вышли из аккаунта');
              await auth.signOut();
              messenger.showSnackBar(SnackBar(content: Text(text)));
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE9E4D4),
              foregroundColor: const Color(0xFF293326),
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: Text(tr(context, signedIn ? 'Выйти' : 'Войти')),
          ),
        ],
      ),
    );
  }
}
