import 'package:flutter/material.dart';

import '../../logic/geo.dart';
import '../../logic/routing.dart';
import '../../state/route_state.dart';
import '../actions.dart';
import '../theme.dart';
import 'motion.dart';

/// Содержимое шторки, пока показан маршрут до аптеки.
class RoutePanel extends StatelessWidget {
  const RoutePanel({super.key, required this.route, required this.onClose});

  final RouteState route;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final target = route.target!;
    final result = route.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'МАРШРУТ ДО АПТЕКИ',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    target.chain,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    target.address,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Закрыть маршрут',
              onPressed: onClose,
              style: IconButton.styleFrom(backgroundColor: AppColors.surface),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ModeSwitch(value: route.mode, onChanged: route.setMode),
        const SizedBox(height: 16),
        if (route.loading)
          const _Loading()
        else if (route.error != null)
          _Error(message: route.error!, onRetry: route.retry)
        else if (result != null) ...[
          _Summary(result: result, fromDevice: route.fromDevice),
          const SizedBox(height: 14),
          for (var i = 0; i < result.steps.length; i++)
            FlipIn(
              key: ValueKey('${result.hashCode}-$i'),
              delay: Duration(milliseconds: 40 * (i < 10 ? i : 10)),
              child: _StepRow(
                step: result.steps[i],
                last: i == result.steps.length - 1,
              ),
            ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => openRoute(context, target, mode: route.mode),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Открыть в навигаторе'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Маршрут: OSRM, данные © участники OpenStreetMap',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.value, required this.onChanged});

  final TravelMode value;
  final ValueChanged<TravelMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.greySoft,
        borderRadius: BorderRadius.circular(100),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = (c.maxWidth) / 2;
          return Stack(
            children: [
              AnimatedAlign(
                alignment: value == TravelMode.walk
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                child: Container(
                  width: w,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: cardShadow,
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (mode, icon) in const [
                    (TravelMode.walk, Icons.directions_walk),
                    (TravelMode.car, Icons.directions_car_outlined),
                  ])
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(mode),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              size: 20,
                              color: value == mode
                                  ? AppColors.green
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              mode.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: value == mode
                                    ? AppColors.text
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.result, required this.fromDevice});

  final RouteResult result;
  final bool fromDevice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatDuration(result.duration),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.green,
                  height: 1,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  formatDistance(result.distance),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            fromDevice
                ? (result.mode == TravelMode.walk
                      ? 'Пешком от вас'
                      : 'На машине от вас')
                : 'От площади Ала-Тоо — включите геолокацию, чтобы строить от вас',
            style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.last});

  final RouteStep step;
  final bool last;

  IconData get _icon => switch (step.kind) {
    'left' => Icons.turn_left,
    'right' => Icons.turn_right,
    'uturn' => Icons.u_turn_left,
    'roundabout' => Icons.roundabout_right,
    'arrive' => Icons.local_pharmacy,
    'depart' => Icons.trip_origin,
    _ => Icons.straight,
  };

  @override
  Widget build(BuildContext context) {
    final arrive = step.kind == 'arrive';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: arrive ? AppColors.green : AppColors.greenSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _icon,
                    size: 18,
                    color: arrive ? Colors.white : AppColors.green,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 2, color: AppColors.greenSoft),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5, bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.instruction,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: arrive ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  if (step.distance >= 5 && !arrive)
                    Text(
                      formatDistance(step.distance),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        SizedBox(height: 12),
        Text(
          'Строим маршрут по улицам…',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ],
    ),
  );
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.orangeSoft,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: const TextStyle(color: AppColors.orange, fontSize: 15),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: const Text('Повторить')),
      ],
    ),
  );
}
