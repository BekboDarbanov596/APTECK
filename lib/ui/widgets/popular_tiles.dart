import 'package:flutter/material.dart';

import '../../logic/tips.dart';
import '../three/mesh.dart';
import '../three/object3d.dart';
import 'motion.dart';

/// Яркие плитки «Популярное» (как в каталоге сервисов): 2 сверху, 3 снизу.
/// В каждой — заголовок и вращающийся 3D-объект.
class PopularTiles extends StatelessWidget {
  const PopularTiles({
    super.key,
    required this.tips,
    required this.onTipAction,
    required this.onIntro,
    required this.introTitle,
  });

  final List<Tip> tips;
  final ValueChanged<TipAction> onTipAction;

  /// «Как это работает».
  final VoidCallback onIntro;
  final String introTitle;

  Tip? _tip(TipKind kind) {
    for (final t in tips) {
      if (t.kind == kind) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final night = _tip(TipKind.nightPharmacy);
    final saving = _tip(TipKind.savings);
    final open = _tip(TipKind.openNow);
    final benefit = _tip(TipKind.benefit);

    Widget tile(
      Tip? tip, {
      required int index,
      required Color color,
      required Shape3D shape,
      int flex = 1,
    }) {
      if (tip == null) return const SizedBox.shrink();
      final action = tip.action;
      return Expanded(
        flex: flex,
        child: _Tile(
          index: index,
          title: tip.title,
          color: color,
          shape: shape,
          onTap: action == null ? null : () => onTipAction(action),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _Tile(
                index: 0,
                title: introTitle,
                color: const Color(0xFFF08A3C),
                shape: Shape3D.capsule,
                onTap: onIntro,
              ),
            ),
            const SizedBox(width: 10),
            tile(night, index: 1, color: const Color(0xFF8E4FC9), shape: Shape3D.bottle, flex: 3),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            tile(saving, index: 2, color: const Color(0xFF1E8A4C), shape: Shape3D.tablet),
            const SizedBox(width: 10),
            tile(open, index: 3, color: const Color(0xFF1A9BD7), shape: Shape3D.heart),
            const SizedBox(width: 10),
            tile(benefit, index: 4, color: const Color(0xFF2F6BEA), shape: Shape3D.bandage),
          ],
        ),
      ],
    );
  }
}

class _Tile extends StatefulWidget {
  const _Tile({
    required this.index,
    required this.title,
    required this.color,
    required this.shape,
    required this.onTap,
  });

  final int index;
  final String title;
  final Color color;
  final Shape3D shape;
  final VoidCallback? onTap;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  final _object = Object3DController();

  @override
  void dispose() {
    _object.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    final onTap = widget.onTap;
    if (onTap == null) return;
    _object.spin();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) onTap();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final card = Container(
      height: 118,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(c, Colors.white, 0.12)!, c],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -14,
            bottom: -16,
            child: Object3D(
              shape: widget.shape,
              size: 96,
              controller: _object,
              phase: widget.index * 0.17,
            ),
          ),
          Positioned(
            left: 12,
            top: 11,
            right: 12,
            child: Text(
              widget.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    return FlipIn(
      delay: Duration(milliseconds: 60 * widget.index),
      child: widget.onTap == null ? card : PressTilt(onTap: _tap, child: card),
    );
  }
}
