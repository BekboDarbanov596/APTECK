import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/lang.dart';
import '../../logic/geo.dart';
import '../../logic/routing.dart';
import '../../logic/transit.dart';
import '../../state/route_state.dart';
import '../actions.dart';
import '../theme.dart';
import '../travel_mode_style.dart';
import 'transit_legs.dart';

/// Панель маршрута, как в 2ГИС:
/// «откуда → куда», карточки вариантов (время → прибытие, «В путь»,
/// полоса участков, интервал), «О маршруте» и снизу способы со временем.
class RoutePanel extends StatefulWidget {
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

  @override
  State<RoutePanel> createState() => _RoutePanelState();
}

class _RoutePanelState extends State<RoutePanel> {
  bool _details = false;

  RouteState get route => widget.route;

  Future<void> _share(BuildContext context) async {
    final target = route.target!;
    final url = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${target.lat},${target.lng}',
      'travelmode': route.mode.googleMode,
    });
    await _copy(
      context,
      '${target.chain} · ${target.address}\n$url',
      'Ссылка на маршрут скопирована',
    );
  }

  Future<void> _copy(BuildContext context, String text, String success) async {
    final messenger = ScaffoldMessenger.of(context);
    final copied = tr(context, success);
    final failed = tr(context, 'Не удалось скопировать');
    String message;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      message = copied;
    } catch (_) {
      message = failed;
    }
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = route.target!;
    final result = route.result;
    final transit = result?.transit;
    final phone = target.phone?.trim().isNotEmpty ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Endpoints(route: route, onClose: widget.onClose),
        const SizedBox(height: 12),
        _Body(route: route),
        const SizedBox(height: 12),
        _ModeBar(route: route),
        const SizedBox(height: 8),

        // «О маршруте» и быстрые действия в один ряд.
        Row(
          children: [
            if (transit != null)
              TextButton.icon(
                onPressed: () => setState(() => _details = !_details),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.background,
                  foregroundColor: AppColors.text,
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: Icon(
                  _details
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                ),
                label: Text(tr(context, 'О маршруте')),
              ),
            if (transit != null) const SizedBox(width: 6),
            // На узком экране кнопки листаются, а не вылезают за край.
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (widget.onShowMap != null && result != null)
                          _IconAction(
                            icon: Icons.zoom_out_map_rounded,
                            tooltip: tr(context, 'Весь маршрут'),
                            onTap: widget.onShowMap,
                          ),
                        _IconAction(
                          icon: Icons.copy_rounded,
                          tooltip: tr(context, 'Скопировать адрес'),
                          onTap: () => _copy(
                            context,
                            target.address,
                            'Адрес скопирован',
                          ),
                        ),
                        _IconAction(
                          icon: Icons.ios_share_rounded,
                          tooltip: tr(context, 'Поделиться'),
                          onTap: () => _share(context),
                        ),
                        if (widget.onToggleFavorite != null)
                          _IconAction(
                            icon: widget.isFavorite
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            tooltip: widget.isFavorite
                                ? 'Убрать из избранного'
                                : 'Сохранить аптеку',
                            onTap: widget.onToggleFavorite,
                            highlighted: widget.isFavorite,
                          ),
                        if (phone)
                          _IconAction(
                            icon: Icons.phone_rounded,
                            tooltip: tr(context, 'Позвонить'),
                            onTap: () => callPharmacy(context, target),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (transit != null && _details) ...[
          const SizedBox(height: 12),
          TransitDetails(option: transit),
        ],
        const SizedBox(height: 6),
        Text(
          transit != null
              ? tr(context, 'Маршрут и транспорт: 2ГИС · карта © OpenStreetMap')
              : result != null
              ? tr(context, 'Маршрут: OSRM · © участники OpenStreetMap')
              : '© ${tr(context, 'участники OpenStreetMap')}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// ● Моё местоположение / ● Аптека — и крестик.
class _Endpoints extends StatelessWidget {
  const _Endpoints({required this.route, required this.onClose});

  final RouteState route;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final target = route.target!;
    final hours = target.isAroundTheClock
        ? tr(context, 'круглосуточно')
        : (target.opensAt != null && target.closesAt != null)
        ? '${target.opensAt}–${target.closesAt}'
        : null;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Point(
                  color: AppColors.green,
                  title: tr(
                    context,
                    route.fromDevice ? 'Моё местоположение' : 'Площадь Ала-Тоо',
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 22, top: 6, bottom: 6),
                  child: Divider(height: 1, color: AppColors.border),
                ),
                _Point(
                  color: AppColors.userDot,
                  title: target.chain,
                  subtitle: hours == null
                      ? target.address
                      : '${target.address} · $hours',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: tr(context, 'Закрыть маршрут'),
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded, size: 22),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.text,
            minimumSize: const Size.square(44),
          ),
        ),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.color, required this.title, this.subtitle});

  final Color color;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3.5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
              children: [
                if (subtitle != null)
                  TextSpan(
                    text: '  $subtitle',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Загрузка, ошибка, «в 2ГИС» или карточки вариантов.
class _Body extends StatelessWidget {
  const _Body({required this.route});

  final RouteState route;

  @override
  Widget build(BuildContext context) {
    final accent = travelModeColor(route.mode);
    final result = route.result;

    if (route.loading) {
      return _Card(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                tr(context, 'Строим маршрут…'),
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!route.inApp) {
      return _Card(
        child: Row(
          children: [
            Icon(travelModeIcon(route.mode), color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr(context, 'Номера автобусов, маршруток и пересадки — в 2ГИС'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: AppColors.text),
              ),
            ),
            FilledButton.tonal(
              onPressed: () =>
                  openRoute(context, route.target!, mode: route.mode),
              child: Text(tr(context, 'Открыть в 2ГИС')),
            ),
          ],
        ),
      );
    }

    // 2ГИС предлагает только пешком — аптека рядом, автобус не нужен.
    if (result == null && route.walkInstead) {
      final walk = _modeTime(route, TravelMode.walk);
      return _Card(
        child: Row(
          children: [
            Icon(
              travelModeIcon(TravelMode.walk),
              color: travelModeColor(TravelMode.walk),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, 'Автобус не нужен'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    walk == null
                        ? tr(context, 'Пешком быстрее')
                        : '${tr(context, 'Пешком быстрее')}: $walk',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => route.setMode(TravelMode.walk),
              child: Text(tr(context, 'Пешком')),
            ),
          ],
        ),
      );
    }

    if (result == null) {
      return _Card(
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr(context, route.error ?? 'Маршрут до аптеки'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: AppColors.text),
              ),
            ),
            if (route.error != null)
              TextButton(
                onPressed: route.retry,
                child: Text(tr(context, 'Повторить')),
              ),
          ],
        ),
      );
    }

    if (result.transit != null) {
      return _TransitCarousel(
        key: ObjectKey(result.transitOptions),
        route: route,
        options: result.transitOptions,
      );
    }

    final from = tr(
      context,
      route.fromDevice ? 'от вас' : 'от площади Ала-Тоо',
    );
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TimeRow(
            seconds: result.duration,
            arrival: null,
            onGo: () => openRoute(context, route.target!, mode: route.mode),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatDistance(result.distance)} · $from',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.selected = false});

  final Widget child;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppColors.border : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: child,
    );
  }
}

/// «19 мин → 16:02» и зелёная «В путь».
class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.seconds,
    required this.arrival,
    required this.onGo,
  });

  final double seconds;
  final String? arrival;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final at =
        arrival ??
        () {
          final t = DateTime.now().add(Duration(seconds: seconds.round()));
          return '${t.hour.toString().padLeft(2, '0')}:'
              '${t.minute.toString().padLeft(2, '0')}';
        }();
    return Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatDuration(seconds),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.greenDark,
                    height: 1.1,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  at,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: onGo,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.greenFill,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(tr(context, 'В путь')),
        ),
      ],
    );
  }
}

/// Варианты поездки листаются вбок; выбранный рисуется на карте.
class _TransitCarousel extends StatefulWidget {
  const _TransitCarousel({
    super.key,
    required this.route,
    required this.options,
  });

  final RouteState route;
  final List<TransitOption> options;

  @override
  State<_TransitCarousel> createState() => _TransitCarouselState();
}

class _TransitCarouselState extends State<_TransitCarousel> {
  late final PageController _pages = PageController(
    viewportFraction: widget.options.length > 1 ? 0.9 : 1,
    initialPage: widget.route.transitIndex,
  );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final selected = widget.route.transitIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 150 * scale,
          child: PageView.builder(
            controller: _pages,
            padEnds: false,
            itemCount: widget.options.length,
            onPageChanged: widget.route.selectTransit,
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.only(
                right: widget.options.length > 1 ? 8 : 0,
              ),
              child: _TransitCard(
                option: widget.options[i],
                selected: i == selected && widget.options.length > 1,
                onGo: () => openRoute(
                  context,
                  widget.route.target!,
                  mode: TravelMode.bus,
                ),
              ),
            ),
          ),
        ),
        if (widget.options.length > 1) ...[
          const SizedBox(height: 8),
          Text(
            '${tr(context, 'Вариант')} ${selected + 1} '
            '${tr(context, 'из')} ${widget.options.length} · '
            '${tr(context, 'листайте')} →',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _TransitCard extends StatelessWidget {
  const _TransitCard({
    required this.option,
    required this.selected,
    required this.onGo,
  });

  final TransitOption option;
  final bool selected;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final ride = option.rides.isEmpty ? null : option.rides.first;
    final sub = [
      if (option.departure != null)
        tr(context, 'отправление в {t}', {'t': option.departure!}),
      option.transfers == 0
          ? tr(context, 'без пересадок')
          : tr(context, 'пересадок: {n}', {'n': option.transfers}),
    ].join(' · ');
    final interval = option.intervalMinutes;
    return _Card(
      selected: selected,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TimeRow(
            seconds: option.totalSeconds,
            arrival: option.arrival,
            onGo: onGo,
          ),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const Spacer(),
          TransitSegmentsBar(option: option),
          const Spacer(),
          if (ride != null)
            Row(
              children: [
                Icon(
                  transitIcon(ride.kind),
                  size: 20,
                  color: transitColor(ride.kind),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tr(context, 'от «{s}»', {'s': ride.fromStop ?? '—'}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.text,
                    ),
                  ),
                ),
                if (interval != null && interval > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    tr(context, 'Каждые {n} мин', {'n': interval}),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// Время для способа: уже построенное или оценка по расстоянию («~12 мин»).
String? _modeTime(RouteState route, TravelMode mode) {
  final known = route.knownDurations[mode];
  if (known != null) return formatDuration(known);
  final t = route.target, f = route.from;
  if (t == null || f == null) return null;
  final estimate = mode.estimateSeconds(
    distanceMeters(f.latitude, f.longitude, t.lat, t.lng),
  );
  return estimate == null ? null : '~${formatDuration(estimate)}';
}

/// Способы передвижения со временем: 🚗 5 мин · 🚌 19 мин · 🚶 ~12 мин…
class _ModeBar extends StatelessWidget {
  const _ModeBar({required this.route});

  final RouteState route;

  String? _time(TravelMode mode) => _modeTime(route, mode);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final mode in TravelMode.values)
          Expanded(
            child: _ModeTab(
              selected: route.mode == mode,
              color: travelModeColor(mode),
              icon: travelModeIcon(mode),
              label: tr(context, mode.label),
              time: _time(mode),
              onTap: () => route.setMode(mode),
            ),
          ),
      ],
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.selected,
    required this.color,
    required this.icon,
    required this.label,
    required this.time,
    required this.onTap,
  });

  final bool selected;
  final Color color;
  final IconData icon;
  final String label;
  final String? time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? color : AppColors.textMuted;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 54,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.11)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.45)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: fg),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    time ?? label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: fg,
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
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: highlighted
              ? AppColors.greenSoft
              : AppColors.background,
          foregroundColor: highlighted ? AppColors.green : AppColors.text,
          minimumSize: const Size.square(42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
