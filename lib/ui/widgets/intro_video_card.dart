import 'package:flutter/material.dart';

import 'medical_illustration.dart';
import 'liquid_glass.dart';
import '../../l10n/lang.dart';
import 'intro_video_native.dart'
    if (dart.library.js_interop) 'intro_video_web.dart'
    as player;

/// Set INTRO_VIDEO_URL at build time or pass videoUrl directly.
class IntroVideoCard extends StatelessWidget {
  const IntroVideoCard({
    super.key,
    this.videoUrl = const String.fromEnvironment('INTRO_VIDEO_URL'),
  });
  final String videoUrl;

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF2F7F5),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'Аптека рядом'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 16),
              if (videoUrl.isNotEmpty) ...[
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: player.IntroPlayer(url: videoUrl),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              _Step(
                number: '01',
                title: tr(context, 'Найдите лекарство'),
                text: tr(context, 'Введите название или выберите категорию.'),
              ),
              _Step(
                number: '02',
                title: tr(context, 'Сравните аптеки'),
                text: tr(context, 'Посмотрите цены, наличие и часы работы.'),
              ),
              _Step(
                number: '03',
                title: tr(context, 'Выберите удобный маршрут'),
                text: tr(context, 'Откройте аптеку на карте и постройте маршрут.'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tr(context, videoUrl.isEmpty
        ? 'Как работает Аптека рядом'
        : 'Смотреть ознакомительное видео'),
    child: GestureDetector(
      onTap: () => _open(context),
      child: Container(
        height: 238,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF123E3B), Color(0xFF236660), Color(0xFF638A91)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -35,
              top: -45,
              child: Container(
                width: 220,
                height: 220,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x996DE9CE), Color(0x006DE9CE)],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -25,
              top: 28,
              child: Transform.rotate(
                angle: 0.55,
                child: const MedicalIllustration(
                  category: 'Антибиотики',
                  size: 155,
                  light: true,
                ),
              ),
            ),
            Positioned(
              right: 37,
              top: 12,
              child: Transform.rotate(
                angle: -0.35,
                child: const SizedBox.shrink(),
              ),
            ),
            Positioned(
              left: 20,
              top: 20,
              child: LiquidGlass(
                dark: true,
                radius: 100,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  child: Text(
                    tr(context, videoUrl.isEmpty ? 'ЗНАКОМЬТЕСЬ' : 'ВИДЕОГИД'),
                    style: const TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.7,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE0F3EA),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              top: 65,
              right: 80,
              child: Text(
                tr(context, 'Ближе к вам.\nПроще для вас.'),
                style: const TextStyle(
                  fontSize: 27,
                  height: 1.05,
                  letterSpacing: -1.1,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: LiquidGlass(
                dark: true,
                radius: 20,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDBF5DF),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          videoUrl.isEmpty
                              ? Icons.arrow_forward_rounded
                              : Icons.play_arrow_rounded,
                          color: const Color(0xFF174B42),
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(context, videoUrl.isEmpty
                                  ? 'Как это работает'
                                  : 'Смотреть знакомство'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              tr(context, 'Найти · сравнить · добраться'),
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFD6EAE4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.text});
  final String number, title, text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFDCEDE6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Color(0xFF276658),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: const TextStyle(fontSize: 13, color: Color(0xFF596C64)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
