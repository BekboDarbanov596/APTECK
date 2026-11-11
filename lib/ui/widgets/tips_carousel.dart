import 'dart:async';

import 'package:flutter/material.dart';

import '../../logic/tips.dart';
import '../theme.dart';
import 'motion.dart';

/// Карусель карточек-советов: соседние карточки повёрнуты в 3D,
/// при листании они «разворачиваются» к пользователю.
class TipsCarousel extends StatefulWidget {
  const TipsCarousel({super.key, required this.tips, required this.onAction});

  final List<Tip> tips;
  final ValueChanged<TipAction> onAction;

  @override
  State<TipsCarousel> createState() => _TipsCarouselState();
}

class _TipsCarouselState extends State<TipsCarousel> {
  final _page = PageController(viewportFraction: 0.84);
  double _current = 0;
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    _page.addListener(() => setState(() => _current = _page.page ?? 0));
    _startAuto();
  }

  /// Каждые 5 секунд — следующая карточка; после ручного листания отсчёт заново.
  void _startAuto() {
    _auto?.cancel();
    _auto = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_page.hasClients || widget.tips.isEmpty) return;
      final next = (_current.round() + 1) % widget.tips.length;
      _goTo(next, restart: false);
    });
  }

  void _goTo(int index, {bool restart = true}) {
    _page.animateToPage(
      index,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
    );
    if (restart) _startAuto();
  }

  @override
  void dispose() {
    _auto?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tips = widget.tips;
    return Column(
      children: [
        SizedBox(
          height: 172,
          child: NotificationListener<ScrollStartNotification>(
            // Человек сам листает — откладываем автопрокрутку.
            onNotification: (n) {
              if (n.dragDetails != null) _startAuto();
              return false;
            },
            child: PageView.builder(
            controller: _page,
            itemCount: tips.length,
            // Шторка — вертикальный скролл; карусель листается по горизонтали.
            padEnds: false,
            itemBuilder: (context, i) {
              final offset = (i - _current).clamp(-1.0, 1.0);
              return Transform(
                alignment: offset > 0 ? Alignment.centerLeft : Alignment.centerRight,
                transform: perspective(0.0016)
                  ..rotateY(-0.55 * offset)
                  ..scaleByDouble(1 - 0.08 * offset.abs(), 1 - 0.08 * offset.abs(), 1, 1),
                child: Opacity(
                  opacity: 1 - 0.35 * offset.abs(),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: FlipIn(
                      delay: Duration(milliseconds: 80 * i.clamp(0, 3)),
                      child: _TipCard(tip: tips[i], onAction: widget.onAction),
                    ),
                  ),
                ),
              );
            },
          ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < tips.length; i++)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _goTo(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: (_current.round() == i) ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _current.round() == i ? AppColors.green : const Color(0xFFCCD5CF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TipStyle {
  const _TipStyle(this.icon, this.from, this.to, this.accent);

  final IconData icon;
  final Color from;
  final Color to;
  final Color accent;
}

final _styles = {
  TipKind.savings: _TipStyle(Icons.savings_outlined, Color(0xFFE6F6E9), Color(0xFFCDEDD4), AppColors.greenDark),
  TipKind.nightPharmacy: _TipStyle(Icons.nightlight_round, Color(0xFFE8ECFB), Color(0xFFD3DBF7), Color(0xFF3B4FA8)),
  TipKind.openNow: _TipStyle(Icons.storefront_outlined, Color(0xFFE5F4F6), Color(0xFFCBE8EC), Color(0xFF1F7180)),
  TipKind.benefit: _TipStyle(Icons.receipt_long_outlined, Color(0xFFFFF2DC), Color(0xFFFDE3B8), AppColors.orange),
  TipKind.searchHint: _TipStyle(Icons.science_outlined, Color(0xFFF1EAFB), Color(0xFFE2D6F6), Color(0xFF6A43A8)),
  TipKind.homeKit: _TipStyle(Icons.medical_services_outlined, Color(0xFFFCE9EC), Color(0xFFF8D3DA), Color(0xFFA83A52)),
};

class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip, required this.onAction});

  final Tip tip;
  final ValueChanged<TipAction> onAction;

  @override
  Widget build(BuildContext context) {
    final s = _styles[tip.kind]!;
    final action = tip.action;
    final card = Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [s.from, s.to],
        ),
      ),
      child: Stack(
        children: [
          // Крупная полупрозрачная иконка-фон.
          Positioned(
            right: -10,
            bottom: -14,
            child: Icon(s.icon, size: 96, color: s.accent.withValues(alpha: 0.10)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(s.icon, color: s.accent, size: 26),
              const SizedBox(height: 10),
              Text(
                tip.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: s.accent),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  tip.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, height: 1.3, color: AppColors.text),
                ),
              ),
              if (tip.actionLabel != null && action != null)
                Row(
                  children: [
                    Text(
                      tip.actionLabel!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: s.accent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 16, color: s.accent),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
    if (action == null) return card;
    return PressTilt(onTap: () => onAction(action), child: card);
  }
}
