import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../../l10n/lang.dart';
import '../../logic/geo.dart';
import '../../logic/opening_hours.dart';
import '../../logic/routing.dart';
import '../../state/app_state.dart';
import '../actions.dart';
import '../theme.dart';
import '../travel_mode_style.dart';
import 'common.dart';

/// Карточка аптеки, которая сразу выезжает снизу после нажатия на метку
/// (как карточка места в 2ГИС): название, время в пути, адрес, статус,
/// цена выбранного лекарства и ряд кнопок действий.
class PharmacyCard extends StatelessWidget {
  const PharmacyCard({
    super.key,
    required this.result,
    required this.catalog,
    required this.drug,
    required this.now,
    required this.mode,
    required this.isFavorite,
    required this.onClose,
    required this.onRoute,
    required this.onDetails,
    required this.onToggleFavorite,
  });

  final PharmacyResult result;
  final Catalog catalog;

  /// Лекарство, которое человек искал (если искал).
  final Drug? drug;
  final DateTime now;
  final TravelMode mode;
  final bool isFavorite;
  final VoidCallback onClose;
  final VoidCallback onRoute;
  final VoidCallback onDetails;
  final VoidCallback onToggleFavorite;

  Future<void> _share(BuildContext context) async {
    final p = result.pharmacy;
    final url = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${p.lat},${p.lng}',
    });
    final messenger = ScaffoldMessenger.of(context);
    final copied = tr(context, 'Адрес аптеки скопирован');
    final failed = tr(context, 'Не удалось скопировать');
    try {
      await Clipboard.setData(
        ClipboardData(
          text: '${p.chain} · ${p.address}, ${tr(context, 'Бишкек')}\n$url',
        ),
      );
      messenger.showSnackBar(SnackBar(content: Text(copied)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = result.pharmacy;
    final d = drug;
    final price = result.price;
    final eta = mode.estimateSeconds(result.distance);
    final open = result.isOpen;
    final offers = catalog.offersForPharmacy(p.id);
    int? minPrice;
    for (final o in offers) {
      if (minPrice == null || o.price < minPrice) minPrice = o.price;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PharmacyPhotoStrip(),
        const SizedBox(height: 10),
        // Название и закрыть.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.chain,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tr(context, 'Аптека'),
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Material(
              color: AppColors.greySoft,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onClose,
                child: SizedBox.square(
                  dimension: 46,
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.text,
                    semanticLabel: tr(context, 'Закрыть'),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Адрес и время в пути.
        Row(
          children: [
            Expanded(
              child: Text(
                '${p.address}, ${tr(context, 'Бишкек')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, color: AppColors.text),
              ),
            ),
            const SizedBox(width: 10),
            Icon(travelModeIcon(mode), size: 19, color: AppColors.greenDark),
            const SizedBox(width: 4),
            Text(
              eta == null
                  ? formatDistance(result.distance)
                  : '≈ ${formatDuration(eta)}',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Статус: зелёный — открыто, красный — закрыто.
        Text(
          openingStatus(p, now),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: open ? AppColors.greenDark : const Color(0xFFBE3333),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1, color: AppColors.border),
        ),
        // Что есть в аптеке.
        if (d != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  d.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: price == null
                      ? AppColors.greySoft
                      : AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  price == null
                      ? tr(context, 'Нет в наличии')
                      : formatPrice(price),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: price == null
                        ? AppColors.textMuted
                        : AppColors.greenDark,
                  ),
                ),
              ),
            ],
          )
        else
          Text(
            minPrice == null
                ? tr(context, 'Нет данных о наличии')
                : '${tr(context, 'В наличии')}: ${offers.length} ${tr(context, 'препаратов')} · '
                      '${tr(context, 'от')} ${formatPrice(minPrice)}',
            style: TextStyle(fontSize: 15.5, color: AppColors.text),
          ),
        if (catalog.isDemo) ...[
          const SizedBox(height: 6),
          Text(
            tr(context, 'Демо-данные: цены и наличие примерные'),
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
        const SizedBox(height: 16),
        // Кнопки действий.
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              FilledButton.icon(
                onPressed: onRoute,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.route_rounded, size: 22),
                label: Text(
                  tr(context, 'Маршрут'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ActionSquare(
                icon: Icons.call_rounded,
                tooltip: tr(context, 'Позвонить'),
                onTap: () => callPharmacy(context, p),
              ),
              const SizedBox(width: 8),
              _ActionSquare(
                icon: isFavorite
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                tooltip: tr(
                  context,
                  isFavorite ? 'Убрать из избранного' : 'В избранное',
                ),
                active: isFavorite,
                onTap: onToggleFavorite,
              ),
              const SizedBox(width: 8),
              _ActionSquare(
                icon: Icons.share_rounded,
                tooltip: tr(context, 'Поделиться'),
                onTap: () => _share(context),
              ),
              const SizedBox(width: 8),
              _ActionSquare(
                icon: Icons.info_outline_rounded,
                tooltip: tr(context, 'Подробнее'),
                onTap: onDetails,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PharmacyPhotoStrip extends StatelessWidget {
  const _PharmacyPhotoStrip();

  static const _images = [
    ('assets/route-pharmacy.png', Alignment.centerRight),
    ('assets/ads/prices.jpg', Alignment.center),
    ('assets/route-pharmacy-evening.jpg', Alignment.centerRight),
    ('assets/ads/firstaid.jpg', Alignment.center),
  ];

  void _openGallery(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'Все фото')),
        scrollable: true,
        content: SizedBox(
          width: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Text(tr(context, 'Фото для иллюстрации')),
              for (final (asset, _) in _images)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(asset),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr(context, 'Закрыть')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          spacing: 8,
          children: [
            for (final (index, (asset, alignment)) in _images.indexed)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: SizedBox(
                    height: 82,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          asset,
                          fit: BoxFit.cover,
                          alignment: alignment,
                          excludeFromSemantics: true,
                        ),
                        if (index == _images.length - 1)
                          TextButton(
                            onPressed: () => _openGallery(context),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(3),
                              shape: const RoundedRectangleBorder(),
                            ),
                            child: Text(
                              tr(context, 'Все фото'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          tr(context, 'Фото для иллюстрации'),
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _ActionSquare extends StatelessWidget {
  const _ActionSquare({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? AppColors.greenSoft : AppColors.greySoft,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              icon,
              color: active ? AppColors.greenDark : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
