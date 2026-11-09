import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logic/geo.dart';
import '../../logic/routing.dart';
import '../../state/route_state.dart';
import '../actions.dart';

const _ink = Color(0xFF0C1730);
const _muted = Color(0xFF344B66);

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
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(
        ClipboardData(text: '${target.chain} · ${target.address}\n$url'),
      );
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Ссылка на маршрут скопирована')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Не удалось скопировать ссылку')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = route.target!;
    final result = route.result;
    final walking = route.mode == TravelMode.walk;
    final main = walking ? const Color(0xFF008644) : const Color(0xFF006EBE);
    final dark = walking ? const Color(0xFF00512D) : const Color(0xFF003B82);
    final soft = walking ? const Color(0xFFD9F3E4) : const Color(0xFFD9EDFE);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        walking ? const Color(0xFF3EBA78) : const Color(0xFF42B5EF),
        main,
        dark,
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _TopButton(
              icon: Icons.arrow_back_ios_new_rounded,
              label: 'Закрыть маршрут',
              onTap: onClose,
            ),
            const Expanded(
              child: Text(
                'Маршрут до аптеки',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
            _TopButton(
              icon: isFavorite
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              label: isFavorite ? 'Убрать из избранного' : 'Сохранить аптеку',
              onTap: onToggleFavorite,
            ),
          ],
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 88,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: constraints.maxWidth * 0.54,
                  child: const _ReferenceCrop(
                    rect: Rect.fromLTRB(496, 96, 935, 306),
                    fade: true,
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 2,
                  right: constraints.maxWidth * 0.43,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: gradient,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: Colors.white70),
                          boxShadow: [
                            BoxShadow(
                              color: main.withValues(alpha: 0.26),
                              blurRadius: 9,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_pharmacy_outlined,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              target.chain,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                height: 1.08,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.place_outlined,
                                  size: 13,
                                  color: _muted,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    target.address,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      height: 1.1,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            if (target.isAroundTheClock ||
                                (target.opensAt != null &&
                                    target.closesAt != null))
                              _Pill(
                                icon: Icons.schedule_rounded,
                                color: Colors.white.withValues(alpha: 0.89),
                                foreground: dark,
                                label: target.isAroundTheClock
                                    ? 'Круглосуточно'
                                    : '${target.opensAt}–${target.closesAt}',
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _Surface(
          radius: 18,
          padding: const EdgeInsets.all(5),
          child: Row(
            children: [
              for (final mode in TravelMode.values) ...[
                if (mode == TravelMode.car) const SizedBox(width: 5),
                Expanded(
                  child: _GlossButton(
                    height: 31,
                    selected: route.mode == mode,
                    gradient: gradient,
                    onTap: () => route.setMode(mode),
                    icon: mode == TravelMode.walk
                        ? Icons.directions_walk_rounded
                        : Icons.directions_car_filled_rounded,
                    label: mode.label,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ColoredBox(
            color: soft,
            child: SizedBox(
              height: 96,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        width: constraints.maxWidth * 0.62,
                        child: walking
                            ? const _FadeLeft(
                                child: Image(
                                  image: AssetImage('assets/route-walk.png'),
                                  fit: BoxFit.cover,
                                  alignment: Alignment.centerRight,
                                  excludeFromSemantics: true,
                                ),
                              )
                            : const _ReferenceCrop(
                                rect: Rect.fromLTRB(420, 433, 900, 657),
                                fade: true,
                              ),
                      ),
                      if (walking)
                        Positioned(
                          right: constraints.maxWidth * 0.10,
                          top: 6,
                          child: Icon(
                            Icons.location_on_rounded,
                            color: main,
                            size: 31,
                            shadows: const [
                              Shadow(color: Colors.white70, blurRadius: 8),
                            ],
                          ),
                        ),
                      Positioned(
                        top: 11,
                        bottom: 9,
                        left: 15,
                        right: constraints.maxWidth * 0.45,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (route.loading) ...[
                              SizedBox.square(
                                dimension: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: main,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Flexible(
                                child: Text(
                                  'Строим маршрут…',
                                  style: TextStyle(fontSize: 12, color: _ink),
                                ),
                              ),
                            ] else if (result != null) ...[
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      formatDuration(result.duration),
                                      style: TextStyle(
                                        fontSize: 29,
                                        height: 1,
                                        fontWeight: FontWeight.w800,
                                        color: dark,
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                      ),
                                      width: 1,
                                      height: 16,
                                      color: main.withValues(alpha: 0.25),
                                    ),
                                    Text(
                                      formatDistance(result.distance),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: _ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 5),
                              Flexible(
                                child: Text(
                                  route.fromDevice
                                      ? 'Быстрый маршрут\nдо аптеки'
                                      : 'От площади Ала-Тоо',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _muted,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ] else ...[
                              Flexible(
                                child: Text(
                                  route.error ?? 'Маршрут до аптеки',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              if (route.error != null)
                                InkWell(
                                  onTap: route.retry,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
                                    child: Text(
                                      'Повторить',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: dark,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        if (result != null && result.steps.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Surface(
            radius: 20,
            padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 0, 4),
                  child: Row(
                    children: [
                      Icon(Icons.route_rounded, color: main, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Пошаговый маршрут',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (var i = 0; i < result.steps.length; i++)
                  _Step(
                    step: result.steps[i],
                    first: i == 0,
                    last: i == result.steps.length - 1,
                    main: main,
                    dark: dark,
                    soft: soft,
                    walking: walking,
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 11),
        _GlossButton(
          height: 40,
          selected: true,
          gradient: gradient,
          onTap: () => openRoute(context, target, mode: route.mode),
          icon: Icons.near_me_outlined,
          label: 'Открыть в навигаторе',
          arrow: true,
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              child: _Shortcut(
                icon: Icons.map_outlined,
                label: 'Показать на карте',
                color: main,
                onTap: onShowMap,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Shortcut(
                icon: isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: isFavorite ? 'Сохранено' : 'В избранное',
                color: main,
                onTap: onToggleFavorite,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Shortcut(
                icon: Icons.share_outlined,
                label: 'Поделиться',
                color: main,
                onTap: () => _share(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFFD1E0EC)),
        const SizedBox(height: 9),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline_rounded, size: 14, color: _muted),
            SizedBox(width: 5),
            Flexible(
              child: Text(
                'Маршрут: OSRM, данные © участники OpenStreetMap',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9, color: _muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReferenceCrop extends StatelessWidget {
  const _ReferenceCrop({required this.rect, this.fade = false});
  final Rect rect;
  final bool fade;

  @override
  Widget build(BuildContext context) {
    final crop = LayoutBuilder(
      builder: (context, constraints) {
        final sx = constraints.maxWidth / rect.width;
        final sy = constraints.maxHeight / rect.height;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: -rect.left * sx,
              top: -rect.top * sy,
              width: 954 * sx,
              height: 1648 * sy,
              child: const Image(
                image: AssetImage('assets/route-reference.png'),
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
          ],
        );
      },
    );
    return fade ? _FadeLeft(child: crop) : crop;
  }
}

class _FadeLeft extends StatelessWidget {
  const _FadeLeft({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (rect) => const LinearGradient(
      colors: [Colors.transparent, Colors.white],
      stops: [0, 0.42],
    ).createShader(rect),
    child: child,
  );
}

class _TopButton extends StatelessWidget {
  const _TopButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onTap,
    icon: Icon(icon, size: 19),
    style: IconButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: 0.85),
      foregroundColor: _ink,
      padding: EdgeInsets.zero,
      minimumSize: const Size.square(34),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    ),
  );
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    required this.radius,
    this.padding = EdgeInsets.zero,
  });
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Color(0xFFEFF5FB)],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x21315579),
          blurRadius: 9,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class _GlossButton extends StatelessWidget {
  const _GlossButton({
    required this.height,
    required this.selected,
    required this.gradient,
    required this.onTap,
    required this.icon,
    required this.label,
    this.arrow = false,
  });
  final double height;
  final bool selected, arrow;
  final LinearGradient gradient;
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : _ink;
    final radius = BorderRadius.circular(99);
    return Semantics(
      button: true,
      selected: arrow ? null : selected,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: Colors.white),
            gradient: selected
                ? gradient
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Color(0xFFE9F0FA)],
                  ),
            boxShadow: [
              BoxShadow(
                color: (selected ? gradient.colors.last : _muted).withValues(
                  alpha: 0.20,
                ),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: foreground, size: arrow ? 19 : 17),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            color: foreground,
                            fontSize: arrow ? 14 : 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (arrow)
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.foreground,
    this.icon,
  });
  final String label;
  final Color color, foreground;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 10, color: foreground),
          const SizedBox(width: 3),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({
    required this.step,
    required this.first,
    required this.last,
    required this.main,
    required this.dark,
    required this.soft,
    required this.walking,
  });
  final RouteStep step;
  final bool first, last, walking;
  final Color main, dark, soft;

  @override
  Widget build(BuildContext context) {
    final arrive = step.kind == 'arrive';
    final icon = switch (step.kind) {
      'depart' => Icons.trip_origin_rounded,
      'left' => Icons.turn_left_rounded,
      'right' => Icons.turn_right_rounded,
      'uturn' => Icons.u_turn_left_rounded,
      'roundabout' => Icons.roundabout_right_rounded,
      'arrive' => Icons.storefront_rounded,
      _ => Icons.straight_rounded,
    };
    final rect = switch (step.kind) {
      'arrive' => const Rect.fromLTRB(692, 1092, 874, 1180),
      'right' => const Rect.fromLTRB(691, 873, 875, 956),
      'left' => const Rect.fromLTRB(691, 990, 875, 1072),
      'depart' || 'straight' => const Rect.fromLTRB(691, 757, 875, 840),
      _ => null,
    };
    Widget thumbnail = rect == null
        ? ColoredBox(
            color: soft,
            child: Icon(icon, color: main, size: 25),
          )
        : _ReferenceCrop(rect: rect);
    if (walking && !arrive && rect != null) {
      thumbnail = ColorFiltered(
        colorFilter: ColorFilter.mode(
          main.withValues(alpha: 0.7),
          BlendMode.color,
        ),
        child: thumbnail,
      );
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      decoration: BoxDecoration(
        color: arrive ? soft : null,
        borderRadius: BorderRadius.circular(12),
        border: !last && !arrive
            ? const Border(bottom: BorderSide(color: Color(0xFFDCE8F3)))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: CustomPaint(
        painter: _StepConnector(dark, first: first, last: last),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: arrive ? main : soft,
              ),
              child: Icon(icon, size: 17, color: arrive ? Colors.white : dark),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.instruction,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      height: 1.13,
                    ),
                  ),
                  if (!arrive && step.distance >= 5) ...[
                    const SizedBox(height: 3),
                    _Pill(
                      label: formatDistance(step.distance),
                      color: soft,
                      foreground: dark,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(width: 68, height: 35, child: thumbnail),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepConnector extends CustomPainter {
  const _StepConnector(this.color, {required this.first, required this.last});
  final Color color;
  final bool first, last;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final center = size.height / 2;
    final start = first ? center : -4.0;
    final end = last ? center : size.height + 4;
    for (var y = start; y + 3 <= end; y += 6) {
      canvas.drawLine(Offset(14, y), Offset(14, y + 3), pen);
    }
  }

  @override
  bool shouldRepaint(_StepConnector oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.first != first ||
      oldDelegate.last != last;
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => _Surface(
    radius: 15,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: SizedBox(
          height: 58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: _ink,
                      fontWeight: FontWeight.w600,
                    ),
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
