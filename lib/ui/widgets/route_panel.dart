import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logic/geo.dart';
import '../../logic/routing.dart';
import '../../state/route_state.dart';
import '../actions.dart';
import '../theme.dart';
import '../../l10n/lang.dart';

/// Пешком — фирменный зелёный, на машине — синий, как линия на карте.
const _carBlue = Color(0xFF1F6FD1);

/// Компактная карточка маршрута у нижнего края экрана.
/// Карта над ней остаётся видна — на ней нарисован сам маршрут.
class RoutePanel extends StatelessWidget {
  const RoutePanel({
    super.key,
    required this.route,
    required this.onClose,
    this.onShowMap,
    this.onToggleFavorite,
    this.isFavorite = false,
  });

  final RouteState route;
  final VoidCallback onClose;

  /// Показать весь маршрут на карте.
  final VoidCallback? onShowMap;
  final VoidCallback? onToggleFavorite;
  final bool isFavorite;

  Future<void> _share(BuildContext context) async {
    final target = route.target!;
    final url = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${target.lat},${target.lng}',
      'travelmode': route.mode == TravelMode.walk ? 'walking' : 'driving',
    });
    await _copy(
      context,
      '${target.chain} · ${target.address}\n$url',
      'Ссылка на маршрут скопирована',
    );
  }

  Future<void> _copy(BuildContext context, String text, String success) async {
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      message = success;
    } catch (_) {
      message = 'Не удалось скопировать';
    }
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = route.target!;
    final walking = route.mode == TravelMode.walk;
    final accent = walking ? AppColors.green : _carBlue;
    final hours = target.isAroundTheClock
        ? 'Круглосуточно'
        : (target.opensAt != null && target.closesAt != null)
            ? '${target.opensAt}–${target.closesAt}'
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Аптека и кнопка закрытия.
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.lerp(accent, Colors.white, 0.25)!, accent],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    target.chain,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hours == null ? target.address : '${target.address} · $hours',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: tr(context, 'Закрыть маршрут'),
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, size: 22),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.text,
                minimumSize: const Size.square(40),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Пешком / на машине.
        _ModeSwitch(route: route),
        const SizedBox(height: 14),

        // Время, расстояние и «весь маршрут».
        Row(
          children: [
            Expanded(child: _Summary(route: route, accent: accent)),
            if (onShowMap != null)
              IconButton(
                tooltip: tr(context, 'Весь маршрут'),
                onPressed: onShowMap,
                icon: const Icon(Icons.zoom_out_map_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.background,
                  foregroundColor: AppColors.text,
                  minimumSize: const Size.square(40),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),

        // Главное действие и быстрые кнопки в один ряд.
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => openRoute(context, target, mode: route.mode),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                icon: const Icon(Icons.navigation_rounded, size: 19),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(tr(context, 'В навигаторе')),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _IconAction(
              icon: Icons.copy_rounded,
              tooltip: tr(context, 'Скопировать адрес'),
              onTap: () => _copy(context, target.address, 'Адрес скопирован'),
            ),
            const SizedBox(width: 8),
            _IconAction(
              icon: Icons.ios_share_rounded,
              tooltip: tr(context, 'Поделиться'),
              onTap: () => _share(context),
            ),
            if (onToggleFavorite != null) ...[
              const SizedBox(width: 8),
              _IconAction(
                icon: isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                tooltip: isFavorite ? 'Убрать из избранного' : 'Сохранить аптеку',
                onTap: onToggleFavorite,
                highlighted: isFavorite,
              ),
            ],
            if (target.phone?.trim().isNotEmpty ?? false) ...[
              const SizedBox(width: 8),
              _IconAction(
                icon: Icons.phone_rounded,
                tooltip: tr(context, 'Позвонить'),
                onTap: () => callPharmacy(context, target),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          tr(context, 'Маршрут: OSRM · © участники OpenStreetMap'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.route});

  final RouteState route;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final mode in TravelMode.values)
            Expanded(
              child: _ModeTab(
                selected: route.mode == mode,
                color: mode == TravelMode.walk ? AppColors.green : _carBlue,
                icon: mode == TravelMode.walk
                    ? Icons.directions_walk_rounded
                    : Icons.directions_car_rounded,
                label: tr(context, mode.label),
                onTap: () => route.setMode(mode),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.selected,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? color : AppColors.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 38,
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? const [
                    BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: fg,
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

class _Summary extends StatelessWidget {
  const _Summary({required this.route, required this.accent});

  final RouteState route;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final result = route.result;
    final from = tr(context, route.fromDevice ? 'От вас' : 'От площади Ала-Тоо');

    if (route.loading) {
      return SizedBox(
        height: 48,
        child: Row(
          children: [
            SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: accent),
            ),
            const SizedBox(width: 12),
            Text(
              tr(context, 'Строим маршрут…'),
              style: TextStyle(fontSize: 15, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (result == null) {
      return Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              route.error ?? 'Маршрут до аптеки',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: AppColors.text),
            ),
          ),
          if (route.error != null)
            TextButton(onPressed: route.retry, child: Text(tr(context, 'Повторить'))),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formatDuration(result.duration),
          style: TextStyle(
            fontSize: 30,
            height: 1,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '${formatDistance(result.distance)} · $from',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 21),
      style: IconButton.styleFrom(
        backgroundColor: highlighted ? AppColors.greenSoft : AppColors.background,
        foregroundColor: highlighted ? AppColors.green : AppColors.text,
        minimumSize: const Size.square(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
