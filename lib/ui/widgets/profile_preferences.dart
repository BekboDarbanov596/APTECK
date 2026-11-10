import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/lang.dart';
import '../../state/app_state.dart';
import '../theme.dart';

/// Белая карточка-группа для строк настроек (как в iOS-настройках).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const Divider(height: 1, indent: 58, endIndent: 18, color: Color(0xFFEDF1EE)));
      }
      rows.add(children[i]);
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0E2A1C), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Column(children: rows),
      ),
    );
  }
}

/// Строка настроек: иконка, название, справа значение/переключатель/стрелка.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.chevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Текст справа серым (например, текущий язык).
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null || trailing != null;
    final fg = enabled ? AppColors.text : const Color(0xFFA9B4AE);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              Icon(icon, size: 22, color: fg),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: fg),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(fontSize: 12, height: 1.3, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    value!,
                    style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                  ),
                ),
              ?trailing,
              if (trailing == null && chevron)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.chevron_right_rounded, color: Color(0xFFB4BEB8)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Подпись над группой настроек.
class SettingsCaption extends StatelessWidget {
  const SettingsCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      );
}

/// Маленький переключатель «Ближе / Дешевле».
class _SortToggle extends StatelessWidget {
  const _SortToggle({required this.value, required this.onChanged});

  final SortMode value;
  final ValueChanged<SortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget item(SortMode mode, String label) {
      final selected = value == mode;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.text : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textMuted,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(SortMode.nearest, tr(context, 'Ближе')),
          item(SortMode.cheapest, tr(context, 'Дешевле')),
        ],
      ),
    );
  }
}

/// Настройки поиска и данных для профиля.
class ProfilePreferences extends StatelessWidget {
  const ProfilePreferences({super.key, required this.state});
  final AppState state;

  Future<void> _copyFavorites(BuildContext context) async {
    final catalog = state.catalog;
    final lines = <String>[
      'Мой список · Аптека рядом',
      for (final id in state.favoriteDrugIds)
        if (catalog?.drug(id) case final drug?) '• ${drug.title} — ${drug.subtitle}',
      if (state.favoritePharmacyIds.isNotEmpty) '\nАптеки:',
      for (final id in state.favoritePharmacyIds)
        if (catalog?.pharmacy(id) case final pharmacy?) '• ${pharmacy.chain}, ${pharmacy.address}',
    ];
    final messenger = ScaffoldMessenger.of(context);
    final okText = tr(context, 'Список скопирован — его можно отправить близким');
    final failText = tr(context, 'Не удалось скопировать список. Попробуйте ещё раз.');
    try {
      await Clipboard.setData(ClipboardData(text: lines.join('\n')));
      messenger.showSnackBar(SnackBar(content: Text(okText)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failText)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFavorites = state.favoriteDrugIds.any((id) => state.catalog?.drug(id) != null) ||
        state.favoritePharmacyIds.any((id) => state.catalog?.pharmacy(id) != null);
    return SettingsGroup(
      children: [
        SettingsRow(
          icon: Icons.schedule_rounded,
          title: tr(context, 'Только открытые'),
          onTap: () => state.setSearchPreferences(onlyOpen: !state.onlyOpen),
          trailing: Switch.adaptive(
            value: state.onlyOpen,
            activeTrackColor: AppColors.green,
            onChanged: (v) => state.setSearchPreferences(onlyOpen: v),
          ),
        ),
        SettingsRow(
          icon: Icons.swap_vert_rounded,
          title: tr(context, 'Сначала показывать'),
          trailing: _SortToggle(
            value: state.sort,
            onChanged: (v) => state.setSearchPreferences(sort: v),
          ),
        ),
        SettingsRow(
          icon: Icons.history_toggle_off_rounded,
          title: tr(context, 'Сохранять историю'),
          onTap: () => state.setHistoryEnabled(!state.historyEnabled),
          trailing: Switch.adaptive(
            value: state.historyEnabled,
            activeTrackColor: AppColors.green,
            onChanged: state.setHistoryEnabled,
          ),
        ),
        SettingsRow(
          icon: Icons.ios_share_rounded,
          title: tr(context, 'Скопировать избранное'),
          onTap: hasFavorites ? () => _copyFavorites(context) : null,
        ),
      ],
    );
  }
}
