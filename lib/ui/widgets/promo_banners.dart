import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../theme.dart';
import '../../l10n/lang.dart';

/// Иконка и цвет по разделу каталога — общие для баннеров и заголовка лекарства.
IconData iconForCategory(String category) => switch (category) {
  'Боль и температура' => Icons.thermostat_rounded,
  'Аллергия' => Icons.local_florist_rounded,
  'Антибиотики' => Icons.medication_rounded,
  'Желудок и кишечник' => Icons.restaurant_rounded,
  'Сердце и давление' => Icons.favorite_rounded,
  'Диабет' => Icons.bloodtype_rounded,
  'Простуда и нос' => Icons.air_rounded,
  'Кожа и раны' => Icons.healing_rounded,
  _ => Icons.medication_liquid_rounded,
};

Color colorForCategory(String category) => switch (category) {
  'Боль и температура' => const Color(0xFFE0663A),
  'Аллергия' => const Color(0xFF8A5CD1),
  'Антибиотики' => const Color(0xFF2F7CF6),
  'Желудок и кишечник' => const Color(0xFFD4952B),
  'Сердце и давление' => const Color(0xFFD94667),
  'Диабет' => const Color(0xFF1E9C9C),
  'Простуда и нос' => const Color(0xFF3A8FD6),
  'Кожа и раны' => const Color(0xFF2E9F46),
  _ => AppColors.green,
};

/// Рекламный блок вместо каталога: неподвижная мозаика из баннеров разного
/// размера с фотографиями (Unsplash, бесплатная лицензия). Цена «от … сом» —
/// из каталога. Нажатие выбирает лекарство и показывает аптеки на карте.
class PromoBanners extends StatelessWidget {
  const PromoBanners({
    super.key,
    required this.catalog,
    required this.onDrugPicked,
  });

  final Catalog catalog;
  final ValueChanged<Drug> onDrugPicked;

  Widget _ad(_Ad ad, {required double height, bool big = false}) {
    final drug = catalog.drug(ad.drugId);
    if (drug == null) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: _AdCard(
        ad: ad,
        big: big,
        price: catalog.minPrice(drug.id),
        onTap: () => onDrugPicked(drug),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ad(_ads[0], height: 210, big: true),
        const SizedBox(height: gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _ad(_ads[1], height: 270, big: true)),
            const SizedBox(width: gap),
            Expanded(
              child: Column(
                children: [
                  _ad(_ads[2], height: 130),
                  const SizedBox(height: gap),
                  _ad(_ads[3], height: 130),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: gap),
        _ad(_ads[4], height: 160, big: true),
        const SizedBox(height: gap),
        Row(
          children: [
            Expanded(child: _ad(_ads[5], height: 190)),
            const SizedBox(width: gap),
            Expanded(child: _ad(_ads[6], height: 190)),
          ],
        ),
      ],
    );
  }
}

class _Ad {
  const _Ad({
    required this.photo,
    required this.drugId,
    required this.kicker,
    required this.title,
    this.text,
    required this.accent,
    this.focus = Alignment.center,
  });

  final String photo;
  final String drugId;
  final String kicker;
  final String title;
  final String? text;
  final Color accent;

  /// Какую часть фото держать в кадре.
  final Alignment focus;
}

const _ads = [
  _Ad(
    photo: 'assets/ads/cold.jpg',
    drugId: 'theraflu',
    kicker: 'Сезон простуд',
    title: 'Насморк и озноб?',
    text: 'Терафлю и капли для носа — в аптеках рядом',
    accent: Color(0xFF2C7BD6),
    focus: Alignment(0, -0.3),
  ),
  _Ad(
    photo: 'assets/ads/allergy.jpg',
    drugId: 'loratadin-10',
    kicker: 'Аллергия',
    title: 'Весна\nбез чихания',
    text: 'Лоратадин',
    accent: Color(0xFF8A5CD1),
  ),
  _Ad(
    photo: 'assets/ads/headache.jpg',
    drugId: 'nurofen-200',
    kicker: 'Боль',
    title: 'Болит голова?',
    accent: Color(0xFFE0663A),
    focus: Alignment(0, -0.4),
  ),
  _Ad(
    photo: 'assets/ads/stomach.jpg',
    drugId: 'smecta-3',
    kicker: 'Желудок',
    title: 'Съели не то?',
    accent: Color(0xFFD4952B),
  ),
  _Ad(
    photo: 'assets/ads/prices.jpg',
    drugId: 'paracetamol-500',
    kicker: 'Сравните цены',
    title: 'Сравните цены',
    text: 'Парацетамол в соседних аптеках стоит по-разному',
    accent: Color(0xFF2E9F46),
  ),
  _Ad(
    photo: 'assets/ads/firstaid.jpg',
    drugId: 'levomekol-40',
    kicker: 'Первая помощь',
    title: 'Ссадины\nи порезы',
    accent: Color(0xFF1E9C9C),
  ),
  _Ad(
    photo: 'assets/ads/sport.jpg',
    drugId: 'ibuprofen-200',
    kicker: 'Спорт',
    title: 'Ушибы\nи растяжения',
    accent: Color(0xFF2E9F46),
    focus: Alignment(0, -0.2),
  ),
];

class _AdCard extends StatelessWidget {
  const _AdCard({
    required this.ad,
    required this.big,
    required this.price,
    required this.onTap,
  });

  final _Ad ad;
  final bool big;
  final int? price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1F2A24),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, c) {
            final narrow = c.maxWidth < 220;
            final titleSize = narrow
                ? (big ? 18.0 : 14.5)
                : (big ? 22.0 : 16.0);
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  ad.photo,
                  fit: BoxFit.cover,
                  alignment: ad.focus,
                  excludeFromSemantics: true,
                ),
                // Затемнение снизу, чтобы текст читался на любом фото.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.45, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _PriceTag(
                    price: price,
                    size: big && !narrow ? 76 : 62,
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr(context, ad.title),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Unbounded',
                          fontVariations: const [FontVariation('wght', 700)],
                          fontSize: titleSize,
                          height: 1.12,
                          letterSpacing: -0.6,
                          color: Colors.white,
                          shadows: const [
                            Shadow(color: Color(0x66000000), blurRadius: 14),
                          ],
                        ),
                      ),
                    ],
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

/// Ценник «от … сом».
class _PriceTag extends StatelessWidget {
  const _PriceTag({required this.price, required this.size});

  final int? price;
  final double size;

  @override
  Widget build(BuildContext context) {
    final unit = size / 62;
    final content = price == null
        ? Text(
            tr(context, 'рядом'),
            style: TextStyle(
              fontFamily: 'Unbounded',
              fontVariations: const [FontVariation('wght', 600)],
              fontSize: 10 * unit,
              color: Colors.white,
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr(context, 'ОТ'),
                style: TextStyle(
                  fontSize: 8 * unit,
                  height: 1,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              SizedBox(height: 2 * unit),
              FittedBox(
                child: Text(
                  '$price',
                  style: TextStyle(
                    fontFamily: 'Unbounded',
                    fontVariations: const [FontVariation('wght', 700)],
                    fontSize: 19 * unit,
                    height: 1,
                    letterSpacing: -0.8,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 2 * unit),
              Text(
                tr(context, 'сом'),
                style: TextStyle(
                  fontFamily: 'Unbounded',
                  fontVariations: const [FontVariation('wght', 400)],
                  fontSize: 8.5 * unit,
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          );

    // Круглый матовый «стикер»: сильное размытие, ровная заливка,
    // тонкая кромка, зерно и лёгкий поворот, как ценник на витрине.
    return Transform.rotate(
      angle: -0.14,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.compose(
              outer: _saturate(1.35),
              inner: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            ),
            child: CustomPaint(
              foregroundPainter: _GrainPainter(),
              child: Container(
                padding: EdgeInsets.all(8 * unit),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                alignment: Alignment.center,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Матрица насыщенности для фона под стеклом.
ColorFilter _saturate(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  final i = 1 - s;
  return ColorFilter.matrix(<double>[
    r * i + s, g * i, b * i, 0, 0, //
    r * i, g * i + s, b * i, 0, 0, //
    r * i, g * i, b * i + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);
}

/// Мелкое зерно поверх стекла — даёт «матовость».
class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final light = Paint()..color = Colors.white.withValues(alpha: 0.10);
    final dark = Paint()..color = Colors.black.withValues(alpha: 0.06);
    final count = (size.width * size.height / 6).round();
    for (var n = 0; n < count; n++) {
      final o = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
      );
      canvas.drawRect(Rect.fromLTWH(o.dx, o.dy, 1, 1), n.isEven ? light : dark);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
