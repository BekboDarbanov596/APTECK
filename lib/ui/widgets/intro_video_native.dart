import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/lang.dart';

class IntroPlayer extends StatelessWidget {
  const IntroPlayer({super.key, required this.url});
  final String url;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF173E39),
    child: Center(
      child: FilledButton.icon(
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(tr(context, 'Открыть видео')),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final failText = tr(context, 'Не удалось открыть видео');
          final uri = Uri.tryParse(url);
          if (uri == null || !uri.hasScheme || !await launchUrl(uri)) {
            messenger.showSnackBar(
              SnackBar(content: Text(failText)),
            );
          }
        },
      ),
    ),
  );
}
