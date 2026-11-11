import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../theme.dart';

/// Подложки карты. Все бесплатные и без ключа; у каждой своя подпись авторов.
enum MapLayer {
  scheme(
    'Схема',
    Icons.map_outlined,
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    [],
    'участники OpenStreetMap',
  ),
  // Ночная карта: те же плитки OpenStreetMap, перекрашенные фильтром
  // (у тёмных плиток CARTO теперь нужен ключ).
  dark(
    'Тёмная',
    Icons.dark_mode_outlined,
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    [],
    'участники OpenStreetMap',
  ),
  satellite(
    'Спутник',
    Icons.satellite_alt_outlined,
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    [],
    'Esri, Maxar, Earthstar Geographics',
  );

  const MapLayer(
    this.label,
    this.icon,
    this.urlTemplate,
    this.subdomains,
    this.attribution,
  );

  final String label;
  final IconData icon;
  final String urlTemplate;
  final List<String> subdomains;
  final String attribution;

  /// Схему приглушаем, чтобы акцентом были метки аптек; остальные — как есть.
  bool get muted => this == MapLayer.scheme;

  /// Какую подложку показать: выбранную вручную, а если не выбирали —
  /// ночную в тёмной теме (как в 2ГИС) и обычную схему в светлой.
  static MapLayer auto({required bool dark, MapLayer? chosen}) =>
      chosen ?? (dark ? MapLayer.dark : MapLayer.scheme);
}

/// Колонка кнопок карты как в макете: слои, «+ / −» в одной капсуле,
/// зелёная «где я».
class MapControls extends StatelessWidget {
  const MapControls({
    super.key,
    required this.onLayers,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocate,
    this.locating = false,
  });

  final VoidCallback onLayers;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocate;

  /// Геолокация определяется — вместо стрелки точки.
  final bool locating;

  static const _shadow = [
    BoxShadow(color: Color(0x22343C2D), blurRadius: 8, offset: Offset(0, 3)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MapCircleButton(
          tooltip: tr(context, 'Слои карты'),
          onTap: onLayers,
          child: Icon(
            Icons.layers_outlined,
            color: AppColors.text,
            size: 22,
          ),
        ),
        const SizedBox(height: 14),
        // «+» и «−» в одной белой капсуле.
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(100),
            boxShadow: _shadow,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                _ZoomButton(
                  icon: Icons.add_rounded,
                  tooltip: tr(context, 'Приблизить'),
                  onTap: onZoomIn,
                  top: true,
                ),
                Container(width: 22, height: 1, color: AppColors.border),
                _ZoomButton(
                  icon: Icons.remove_rounded,
                  tooltip: tr(context, 'Отдалить'),
                  onTap: onZoomOut,
                  top: false,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        MapCircleButton(
          tooltip: tr(context, 'Где я'),
          onTap: onLocate,
          color: AppColors.green,
          child: locating
              ? const Icon(Icons.more_horiz, color: Colors.white)
              : const Icon(
                  Icons.near_me_rounded,
                  color: Colors.white,
                  size: 22,
                ),
        ),
      ],
    );
  }
}

class MapCircleButton extends StatelessWidget {
  const MapCircleButton({
    super.key,
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.color,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  /// Фон кнопки; по умолчанию — поверхность темы.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: MapControls._shadow,
        ),
        child: Material(
          color: color ?? AppColors.surface,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(dimension: 48, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.top,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool top;

  @override
  Widget build(BuildContext context) {
    final r = const Radius.circular(100);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.vertical(
          top: top ? r : Radius.zero,
          bottom: top ? Radius.zero : r,
        ),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: AppColors.text, size: 24),
        ),
      ),
    );
  }
}

/// Окно выбора подложки.
Future<void> showMapLayersSheet(
  BuildContext context, {
  required MapLayer current,
  required ValueChanged<MapLayer> onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(context, 'Слои карты'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final layer in MapLayer.values) ...[
                  if (layer != MapLayer.values.first) const SizedBox(width: 10),
                  Expanded(
                    child: _LayerOption(
                      layer: layer,
                      selected: layer == current,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onSelected(layer);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _LayerOption extends StatelessWidget {
  const _LayerOption({
    required this.layer,
    required this.selected,
    required this.onTap,
  });

  final MapLayer layer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 92,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.green : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                layer.icon,
                color: selected ? AppColors.green : AppColors.text,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                tr(context, layer.label),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.greenDark : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
