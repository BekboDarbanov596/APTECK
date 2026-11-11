import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../l10n/lang.dart';
import '../theme.dart';
import 'medical_illustration.dart';
import 'common.dart';
import 'motion.dart';
import 'liquid_glass.dart';

class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    super.key,
    required this.catalog,
    required this.onDrugPicked,
  });
  final Catalog catalog;
  final ValueChanged<Drug> onDrugPicked;

  @override
  Widget build(BuildContext context) {
    final categories = catalog.categories;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE4EDE9), Color(0xFFE9ECEB), Color(0xFFDEE8E4)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < categories.length; i++)
                  SizedBox(
                    width: width,
                    child: _GlassCategory(
                      title: categories[i],
                      index: i,
                      count: catalog.drugsInCategory(categories[i]).length,
                      onTap: () => showCategorySheet(
                        context,
                        catalog: catalog,
                        category: categories[i],
                        onDrugPicked: onDrugPicked,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GlassCategory extends StatelessWidget {
  const _GlassCategory({
    required this.title,
    required this.index,
    required this.count,
    required this.onTap,
  });
  final String title;
  final int index, count;
  final VoidCallback onTap;
  static const accents = [
    Color(0xFF199F88),
    Color(0xFF9473DB),
    Color(0xFFE97681),
    Color(0xFFD4A257),
    Color(0xFFDA729D),
    Color(0xFF539ED8),
    Color(0xFF60B9BF),
    Color(0xFFC99C7D),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = accents[index % accents.length];
    return Semantics(
      button: true,
      label: '${tr(context, title)}, ${tr(context, 'препаратов: {n}', {'n': count})}',
      child: PressTilt(
        onTap: onTap,
        child: SizedBox(
          height: 178,
          child: Stack(
            children: [
              Positioned(
                top: 12,
                left: 10,
                right: 10,
                height: 132,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: 0.10),
                        accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: LiquidGlass(radius: 23, child: const SizedBox.expand()),
              ),
              Positioned(
                top: 13,
                left: 0,
                right: 0,
                child: Center(
                  child: MedicalIllustration(category: title, size: 94),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Icon(
                  Icons.north_east_rounded,
                  size: 14,
                  color: const Color(0xFF536B68).withValues(alpha: 0.7),
                ),
              ),
              Positioned(
                left: 12,
                right: 10,
                bottom: 13,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, title),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.08,
                        letterSpacing: -0.35,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      tr(context, '{n} препаратов', {'n': count}),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF526B66),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Окно раздела: лекарства с минимальной ценой и пометкой о рецепте.
Future<void> showCategorySheet(
  BuildContext context, {
  required Catalog catalog,
  required String category,
  required ValueChanged<Drug> onDrugPicked,
}) {
  final drugs = catalog.drugsInCategory(category)
    ..sort((a, b) => a.name.compareTo(b.name));
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Text(
              tr(context, category),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < drugs.length; i++)
              FlipIn(
                delay: Duration(milliseconds: 50 * i),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PressTilt(
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onDrugPicked(drugs[i]);
                    },
                    child: _DrugRow(
                      drug: drugs[i],
                      minPrice: catalog.minPrice(drugs[i].id),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _DrugRow extends StatelessWidget {
  const _DrugRow({required this.drug, required this.minPrice});

  final Drug drug;
  final int? minPrice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drug.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${drug.subtitle}${drug.rx ? ' · по рецепту' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: drug.rx ? AppColors.orange : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            minPrice == null
                ? tr(context, 'нет')
                : '${tr(context, 'от')} ${formatPrice(minPrice!)}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
