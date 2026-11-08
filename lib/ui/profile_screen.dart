import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import 'auth/account_card.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/profile_preferences.dart';

const _ink = Color(0xFF204C43);
const _muted = Color(0xFF72827B);

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
                const Text(
                  'История поиска',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 10),
                if (state.recentDrugIds.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Здесь появятся лекарства, которые вы искали.',
                      style: TextStyle(color: _muted),
                    ),
                  ),
                for (final id in state.recentDrugIds)
                  if (state.catalog?.drug(id) case final Drug drug)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history_rounded, color: _ink),
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
                    label: const Text('Очистить историю поиска'),
                    onPressed: () {
                      state.clearHistory();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('История поиска очищена')),
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

  void _about(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    builder: (context) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LogoMark(size: 42),
            SizedBox(height: 18),
            Text(
              'Аптека рядом',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              'Находите лекарства, сравнивайте цены и выбирайте удобную аптеку в Бишкеке.',
              style: TextStyle(fontSize: 15, height: 1.5, color: _muted),
            ),
            SizedBox(height: 20),
            Text(
              'Версия 1.0.0 · Бишкек',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final saved =
        state.favoriteDrugIds.length + state.favoritePharmacyIds.length;
    final demo = state.catalog?.isDemo;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'АПТЕКА РЯДОМ',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 2.2,
                            color: _muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Профиль',
                          style: TextStyle(
                            fontSize: 30,
                            height: 1.1,
                            letterSpacing: -1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: const Color(0xFFE4EAE6)),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: _ink,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE3EDE4), Color(0xFFF0F0E6)],
                    ),
                  ),
                  child: Stack(
                    children: [
                      const Positioned(
                        right: -21,
                        top: -28,
                        width: 160,
                        height: 200,
                        child: CustomPaint(painter: _PrivacyLines()),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(21),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    size: 11,
                                    color: _ink,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'БЕЗ АККАУНТА',
                                    style: TextStyle(
                                      fontSize: 8,
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w700,
                                      color: _ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Всё важное.\nПод рукой.',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -1.1,
                                height: 1.08,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Ваши сохранения и настройки',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF63796B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const AccountCard(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _CollectionCard(
                        icon: Icons.favorite_border_rounded,
                        count: saved,
                        label: 'В избранном',
                        onTap: onOpenFavorites,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CollectionCard(
                        icon: Icons.history_rounded,
                        count: state.recentDrugIds.length,
                        label: 'Недавние поиски',
                        onTap: () => _history(context, state),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 23),
                const _SectionLabel('ПОИСК РЯДОМ'),
                const SizedBox(height: 10),
                _LocationCard(state: state),
                const SizedBox(height: 23),
                ProfilePreferences(state: state),
                const SizedBox(height: 23),
                const _SectionLabel('О ПРИЛОЖЕНИИ'),
                const SizedBox(height: 10),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(23),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon: Icons.layers_outlined,
                        title: 'Источники данных',
                        subtitle: demo == null
                            ? 'Загружаем каталог'
                            : demo
                            ? 'Демонстрационный каталог'
                            : 'Данные из аптек',
                        badge: demo == true ? 'ДЕМО' : null,
                        onTap: () {
                          if (demo == true) {
                            showDemoInfo(context);
                          } else {
                            showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Источники данных'),
                                content: Text(
                                  demo == null ? 'Каталог ещё загружается.' : 'Информация поступает из подключённых аптек.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Понятно'),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 58, right: 17),
                        child: Divider(height: 1, color: Color(0xFFEDF0ED)),
                      ),
                      _SettingsRow(
                        icon: Icons.local_pharmacy_outlined,
                        title: 'Аптека рядом',
                        subtitle: 'Версия 1.0.0 · Бишкек',
                        onTap: () => _about(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 17,
                        color: Color(0xFF8D9D93),
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Избранное и история хранятся на этом устройстве. Вход в аккаунт не нужен.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.5,
                            color: _muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.icon,
    required this.count,
    required this.label,
    this.onTap,
  });
  final IconData icon;
  final int count;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: _ink),
                const Spacer(),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 27,
                    height: 1,
                    letterSpacing: -1,
                    fontWeight: FontWeight.w500,
                    color: _ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.north_east_rounded, size: 12, color: _muted),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final active = state.hasDeviceLocation;
    final loading = state.locationStatus == LocationStatus.loading;
    final (badge, description) = switch (state.locationStatus) {
      LocationStatus.device => (
        'ВКЛЮЧЕНА',
        'Расстояния до аптек считаются от вас.',
      ),
      LocationStatus.loading => ('ОПРЕДЕЛЯЕМ', 'Получаем ваше местоположение…'),
      LocationStatus.denied => (
        'НЕТ ДОСТУПА',
        'Разрешите геолокацию в настройках браузера или устройства. Пока расстояния — от площади Ала-Тоо.',
      ),
      LocationStatus.disabled => (
        'ВЫКЛЮЧЕНА',
        'Включите геолокацию на устройстве. Пока расстояния — от площади Ала-Тоо.',
      ),
      LocationStatus.failed => (
        'НЕДОСТУПНА',
        'Попробуйте ещё раз. Пока расстояния — от площади Ала-Тоо.',
      ),
      LocationStatus.unknown => (
        'НЕ НАСТРОЕНА',
        'Разрешите доступ, чтобы видеть расстояния от вас.',
      ),
    };
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF214D42), Color(0xFF34665A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.my_location_rounded,
                color: Color(0xFFD1E8DC),
                size: 22,
              ),
              const Spacer(),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 8,
                      letterSpacing: 1,
                      color: Color(0xFFD2E9DC),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            active ? 'Вы — точка отсчёта' : 'Найдём аптеки ближе',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFFC6DACF),
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            height: 35,
            child: TextButton.icon(
              onPressed: loading ? null : state.refreshLocation,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                foregroundColor: _ink,
                disabledForegroundColor: _ink.withValues(alpha: 0.7),
                backgroundColor: const Color(0xFFE1EDE3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              icon: loading
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: _ink,
                      ),
                    )
                  : const Icon(Icons.near_me_outlined, size: 14),
              label: Text(
                loading
                    ? 'Определяем…'
                    : active
                    ? 'Обновить геопозицию'
                    : 'Настроить геолокацию',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });
  final IconData icon;
  final String title, subtitle;
  final String? badge;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _ink),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: _muted),
                ),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF5EDDD),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  fontSize: 7,
                  letterSpacing: 0.6,
                  color: Color(0xFF946D2D),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: 7),
          const Icon(
            Icons.chevron_right_rounded,
            size: 17,
            color: Color(0xFF9DAAA3),
          ),
        ],
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w700,
        color: _muted,
      ),
    ),
  );
}

class _PrivacyLines extends CustomPainter {
  const _PrivacyLines();
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = const Color(0xFF527865).withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(size.width * 0.68, size.height * 0.44),
        32 + i * 16,
        pen,
      );
    }
    pen.color = const Color(0xFF527865).withValues(alpha: 0.30);
    final center = Offset(size.width * 0.68, size.height * 0.44);
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy - 18)
        ..lineTo(center.dx + 14, center.dy - 12)
        ..lineTo(center.dx + 14, center.dy + 2)
        ..quadraticBezierTo(
          center.dx + 12,
          center.dy + 15,
          center.dx,
          center.dy + 21,
        )
        ..quadraticBezierTo(
          center.dx - 12,
          center.dy + 15,
          center.dx - 14,
          center.dy + 2,
        )
        ..lineTo(center.dx - 14, center.dy - 12)
        ..close(),
      pen,
    );
  }

  @override
  bool shouldRepaint(_PrivacyLines oldDelegate) => false;
}
