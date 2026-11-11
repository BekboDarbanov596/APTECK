import 'package:flutter/material.dart';

import '../../logic/geo.dart' show formatDistance;
import '../../logic/routing.dart' show formatDuration;
import '../../l10n/lang.dart';
import '../../logic/transit.dart';
import '../theme.dart';

/// Цвет линии и номера: автобус — синий, как в 2ГИС.
Color transitColor(String? kind) => switch (kind) {
  'trolleybus' => const Color(0xFF0E9AA7),
  'shuttle_bus' => const Color(0xFF7A4FD6),
  'tram' => const Color(0xFFD84343),
  _ => const Color(0xFF2B6FE0),
};

IconData transitIcon(String? kind) => switch (kind) {
  'trolleybus' => Icons.directions_transit_rounded,
  'shuttle_bus' => Icons.airport_shuttle_rounded,
  'tram' => Icons.tram_rounded,
  _ => Icons.directions_bus_rounded,
};

/// Номер маршрута в плашке: [55].
class LineChip extends StatelessWidget {
  const LineChip(
    this.text, {
    super.key,
    required this.color,
    this.muted = false,
  });

  final String text;
  final Color color;

  /// «+1» — остальные номера.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: muted ? AppColors.greySoft : color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          color: muted ? AppColors.textMuted : Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Номера маршрута: первые [max] и «+N».
List<Widget> lineChips(TransitLeg leg, {int max = 2}) {
  final color = transitColor(leg.kind);
  final lines = leg.lines;
  return [
    for (final l in lines.take(max)) LineChip(l, color: color),
    if (lines.length > max)
      LineChip('+${lines.length - max}', color: color, muted: true),
    if (lines.isEmpty) LineChip(leg.kindLabel, color: color),
  ];
}

/// Участки без «пустых» пеших кусочков в пару метров.
List<TransitLeg> visibleLegs(TransitOption option) =>
    option.legs.where((l) => !l.walk || l.distance >= 15).toList();

/// Полоса участков, как в 2ГИС:
/// 🚶 3 мин ── 🚌 [55][8][+1] ──────── 🚶 6 мин
/// Длина каждого участка — по времени в пути.
class TransitSegmentsBar extends StatelessWidget {
  const TransitSegmentsBar({super.key, required this.option});

  final TransitOption option;

  @override
  Widget build(BuildContext context) {
    final legs = visibleLegs(option);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < legs.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            // Короткие участки не сжимаются в ноль.
            flex: (legs[i].movingSeconds + legs[i].waitingSeconds)
                .clamp(legs[i].walk ? 300.0 : 480.0, 100000.0)
                .round(),
            child: _Segment(leg: legs[i]),
          ),
        ],
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.leg});

  final TransitLeg leg;

  @override
  Widget build(BuildContext context) {
    final color = leg.walk ? AppColors.textMuted : transitColor(leg.kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: leg.walk
                ? [
                    Icon(
                      Icons.directions_walk_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      formatDuration(leg.movingSeconds),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ]
                : [
                    Icon(transitIcon(leg.kind), size: 20, color: color),
                    const SizedBox(width: 4),
                    for (final chip in lineChips(leg)) ...[
                      chip,
                      const SizedBox(width: 3),
                    ],
                  ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: leg.walk ? AppColors.border : color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

/// «О маршруте»: по шагам — куда идти, где садиться, где выходить.
class TransitDetails extends StatelessWidget {
  const TransitDetails({super.key, required this.option});

  final TransitOption option;

  @override
  Widget build(BuildContext context) {
    final legs = visibleLegs(option);
    final rows = <Widget>[];
    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      TransitLeg? next;
      for (var j = i + 1; j < legs.length; j++) {
        if (!legs[j].walk) {
          next = legs[j];
          break;
        }
      }
      final last = i == legs.length - 1;
      if (leg.walk) {
        rows.add(
          _DetailRow(
            icon: Icons.directions_walk_rounded,
            color: AppColors.textMuted,
            dashed: true,
            last: last,
            title: next == null
                ? tr(context, 'Пешком до аптеки')
                : tr(context, 'Пешком до остановки «{s}»', {
                    's': next.fromStop ?? '—',
                  }),
            subtitle:
                '${formatDuration(leg.movingSeconds)} · ${formatDistance(leg.distance)}',
          ),
        );
      } else {
        rows.add(
          _DetailRow(
            icon: transitIcon(leg.kind),
            color: transitColor(leg.kind),
            last: last,
            title: tr(context, 'Посадка: «{s}»', {'s': leg.fromStop ?? '—'}),
            chips: lineChips(leg, max: 5),
            subtitle: [
              if (leg.toStop != null)
                tr(context, 'выход: «{s}»', {'s': leg.toStop!}),
              if (leg.stopCount > 0)
                tr(context, '{n} ост.', {'n': leg.stopCount}),
              tr(context, 'в пути {t}', {
                't': formatDuration(leg.movingSeconds),
              }),
              if (leg.waitingSeconds >= 60)
                tr(context, 'ожидание ~{t}', {
                  't': formatDuration(leg.waitingSeconds),
                }),
            ].join(' · '),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...rows,
        Text(
          tr(context, 'Данные о транспорте: 2ГИС'),
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.chips = const [],
    this.dashed = false,
    this.last = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<Widget> chips;
  final bool dashed;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Icon(icon, size: 20, color: color),
                Expanded(
                  child: last
                      ? const SizedBox()
                      : Container(
                          width: 3,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: dashed ? AppColors.border : color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(spacing: 4, runSpacing: 4, children: chips),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
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
