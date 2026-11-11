import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../l10n/lang.dart';
import '../theme.dart';

// Зелёный акцент и мягкая заливка: днём — из макета, ночью — из тёмной палитры.
Color get _green => AppColors.dark ? AppColors.green : const Color(0xFF087D1C);
Color get _softGreen =>
    AppColors.dark ? AppColors.greenSoft : const Color(0xFFE2F3E4);
const _shadow = BoxShadow(
  color: Color(0x0D213A2D),
  blurRadius: 14,
  offset: Offset(0, 4),
);

class SearchQuickTiles extends StatelessWidget {
  const SearchQuickTiles({
    super.key,
    required this.catalog,
    required this.openNowCount,
    required this.onOpenNow,
    required this.onCategory,
    required this.iconFor,
  });

  final Catalog catalog;
  final int openNowCount;
  final VoidCallback onOpenNow;
  final ValueChanged<String> onCategory;
  final IconData Function(String category) iconFor;

  static const _featured = [
    'Диабет',
    'Простуда и нос',
    'Кожа и раны',
    'Аллергия',
  ];

  @override
  Widget build(BuildContext context) {
    final categories = catalog.categories;
    final ordered = [
      ..._featured.where(categories.contains),
      ...categories.where((category) => !_featured.contains(category)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final width = (constraints.maxWidth - 3 * gap) / 4;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            spacing: gap,
            children: [
              for (final category in ordered)
                _QuickTile(
                  width: width,
                  icon: switch (category) {
                    'Диабет' => Icons.bloodtype_outlined,
                    'Простуда и нос' => Icons.air_rounded,
                    'Кожа и раны' => Icons.healing_outlined,
                    'Аллергия' => Icons.local_florist_outlined,
                    _ => iconFor(category),
                  },
                  label: tr(context, category),
                  featured: category == _featured.first,
                  onTap: () => onCategory(category),
                ),
              _QuickTile(
                width: width,
                icon: Icons.storefront_outlined,
                label: '${tr(context, 'Открыто сейчас')} · $openNowCount',
                onTap: onOpenNow,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.onTap,
    this.featured = false,
  });

  final double width;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [_shadow],
      ),
      child: Material(
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: featured ? BorderSide(color: _green) : BorderSide.none,
        ),
        color: featured ? _softGreen : AppColors.surface,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox(
            width: width,
            height: 80,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: _green, size: 28),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
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

class SearchHelpTiles extends StatelessWidget {
  const SearchHelpTiles({
    super.key,
    required this.onSymptoms,
    required this.onCompare,
    required this.onOpenNow,
    required this.onPrescription,
  });

  final VoidCallback onSymptoms;
  final VoidCallback onCompare;
  final VoidCallback onOpenNow;
  final VoidCallback onPrescription;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5, bottom: 3),
          child: Text(
            tr(context, 'Чем помочь?'),
            style: TextStyle(
              color: AppColors.text,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: _HelpTile(
                icon: Icons.thermostat_outlined,
                title: 'По симптомам',
                subtitle: 'Подобрать по жалобам',
                onTap: onSymptoms,
              ),
            ),
            Expanded(
              child: _HelpTile(
                icon: Icons.price_check_rounded,
                featured: true,
                title: 'Сравнить цены',
                subtitle: 'Где дешевле рядом',
                onTap: onCompare,
              ),
            ),
          ],
        ),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: _HelpTile(
                icon: Icons.location_on_outlined,
                title: 'Открыто сейчас',
                subtitle: 'Ближайшие аптеки',
                onTap: onOpenNow,
              ),
            ),
            Expanded(
              child: _HelpTile(
                icon: Icons.receipt_long_outlined,
                title: 'Льготный рецепт',
                subtitle: 'Проверить наличие',
                onTap: onPrescription,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HelpTile extends StatelessWidget {
  const _HelpTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.featured = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(
        color: featured
            ? (AppColors.dark ? AppColors.green : const Color(0xFFC2DEC8))
            : AppColors.border,
      ),
    );
    return Material(
      color: featured
          ? (AppColors.dark ? AppColors.greenSoft : const Color(0xFFEBF6ED))
          : AppColors.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: featured ? AppColors.greenSoft : _softGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Icon(icon, size: 20, color: AppColors.greenDark),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.greenDark,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tr(context, title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(29),
                child: Text(
                  tr(context, subtitle),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.18,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchHistoryCard extends StatelessWidget {
  const SearchHistoryCard({
    super.key,
    required this.recent,
    required this.onPick,
    required this.onRemove,
    required this.onClear,
  });

  final List<Drug> recent;
  final ValueChanged<Drug> onPick;
  final ValueChanged<Drug> onRemove;
  final VoidCallback onClear;

  void _showHistory(BuildContext context) {
    final remaining = recent.toList();
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(context, 'Недавно искали'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onClear();
                    },
                    child: Text(tr(context, 'Очистить')),
                  ),
                ],
              ),
              for (final drug in remaining)
                ListTile(
                  leading: const Icon(Icons.search_rounded),
                  title: Text(drug.title),
                  onTap: () {
                    Navigator.of(context).pop();
                    onPick(drug);
                  },
                  trailing: IconButton(
                    tooltip: tr(context, 'Удалить из истории'),
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      setState(() => remaining.remove(drug));
                      onRemove(drug);
                      if (remaining.isEmpty) Navigator.of(context).pop();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (recent.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, color: _green, size: 21),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  tr(context, 'Недавно искали'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _showHistory(context),
                style: TextButton.styleFrom(foregroundColor: _green),
                child: Row(
                  children: [
                    Text(
                      tr(context, 'Все'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 19),
                  ],
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 5,
            children: [
              for (final drug in recent.take(3))
                DecoratedBox(
                  decoration: const ShapeDecoration(
                    shape: StadiumBorder(),
                    shadows: [_shadow],
                  ),
                  child: ActionChip(
                    avatar: Icon(
                      Icons.search_rounded,
                      size: 17,
                      color: AppColors.textMuted,
                    ),
                    label: Text(drug.title, overflow: TextOverflow.ellipsis),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: AppColors.text,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    backgroundColor: AppColors.surface,
                    side: BorderSide(color: AppColors.border),
                    shape: const StadiumBorder(),
                    onPressed: () => onPick(drug),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
