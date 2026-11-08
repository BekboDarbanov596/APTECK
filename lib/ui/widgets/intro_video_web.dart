import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class IntroPlayer extends StatefulWidget {
  const IntroPlayer({super.key, required this.url});
  final String url;
  @override
  State<IntroPlayer> createState() => _IntroPlayerState();
}

class _IntroPlayerState extends State<IntroPlayer> {
  web.HTMLVideoElement? _video;
  bool _failed = false;
  late final JSFunction _onError = ((web.Event event) {
    if (mounted) setState(() => _failed = true);
  }).toJS;

  @override
  void dispose() {
    _video?.removeEventListener('error', _onError);
    _video?.pause();
    _video?.removeAttribute('src');
    _video?.load();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _failed
      ? const ColoredBox(
          color: Color(0xFF173E39),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Не удалось загрузить видео. Попробуйте открыть его позже.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        )
      : HtmlElementView.fromTagName(
          tagName: 'video',
          onElementCreated: (element) {
            final video = element as web.HTMLVideoElement;
            _video = video;
            video.controls = true;
            video.playsInline = true;
            video.preload = 'metadata';
            video.style.width = '100%';
            video.style.height = '100%';
            video.style.objectFit = 'contain';
            video.style.backgroundColor = '#173e39';
            video.setAttribute(
              'aria-label',
              'Ознакомительное видео Аптека рядом',
            );
            video.addEventListener('error', _onError);
            video.src = widget.url;
          },
        );
}
