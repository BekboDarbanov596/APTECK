import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../logic/assistant.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets/motion.dart';

/// Открыть ассистента во всплывающем окне снизу поверх карты.
/// Отвечает по каталогу: где есть лекарство, где дешевле, аналоги.
/// Медицинских советов не даёт.
Future<void> showAssistantSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x33000000),
    builder: (context) => const _AssistantSheet(),
  );
}

class _Message {
  const _Message(this.text, {required this.fromUser, this.drug});

  final String text;
  final bool fromUser;
  final Drug? drug;
}

class _AssistantSheet extends StatefulWidget {
  const _AssistantSheet();

  @override
  State<_AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends State<_AssistantSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Message>[const _Message(assistantGreeting, fromUser: false)];
  bool _typing = false;
  Timer? _reply;

  @override
  void dispose() {
    _reply?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _typing) return;
    final state = AppScope.read(context);
    final catalog = state.catalog;
    final reply = catalog == null
        ? const AssistantReply('Данные ещё загружаются, попробуйте через пару секунд.')
        : assistantReply(
            message: text,
            catalog: catalog,
            userLat: state.userLat,
            userLng: state.userLng,
            now: state.now,
          );
    setState(() {
      _messages.add(_Message(text, fromUser: true));
      _typing = true;
    });
    _input.clear();
    _scrollToEnd();
    // Короткая пауза с индикатором «печатает» — ответ не «выпрыгивает» мгновенно.
    _reply = Timer(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      setState(() {
        _typing = false;
        _messages.add(_Message(reply.text, fromUser: false, drug: reply.drug));
      });
      _scrollToEnd();
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _showOnMap(Drug drug) {
    AppScope.read(context).selectDrug(drug);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = math.min(media.size.height * 0.64, 560.0);

    return Padding(
      // Окно поднимается над клавиатурой.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _Header(onClose: () => Navigator.of(context).pop()),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                itemCount: _messages.length + (_typing ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _messages.length) return const _TypingBubble();
                  return FlipIn(
                    key: ValueKey(i),
                    fromAngle: 0.6,
                    duration: const Duration(milliseconds: 380),
                    child: _Bubble(message: _messages[i], onShowOnMap: _showOnMap),
                  );
                },
              ),
            ),
            if (_messages.length == 1)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final q in const [
                      'Где есть Нурофен?',
                      'Аналоги Но-шпы',
                      'Амоксициллин',
                      'Смекта дешевле',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(q),
                          backgroundColor: AppColors.surface,
                          shape: const StadiumBorder(),
                          side: BorderSide.none,
                          onPressed: () => _send(q),
                        ),
                      ),
                  ],
                ),
              ),
            _InputBar(controller: _input, onSend: _send, enabled: !_typing),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFCCD5CF),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Row(
            children: [
              const _Orb(size: 40),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ассистент',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(
                      'Где есть лекарство, цены и аналоги',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Закрыть',
                onPressed: onClose,
                icon: const Icon(Icons.close, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Та же зелёная сфера, что и кнопка на карте.
class _Orb extends StatelessWidget {
  const _Orb({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.35, -0.4),
          radius: 0.9,
          colors: [Color(0xFF6BD47F), AppColors.green, AppColors.greenDark],
          stops: [0, 0.55, 1],
        ),
      ),
      child: Icon(Icons.auto_awesome, color: Colors.white, size: size * 0.46),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend, required this.enabled});

  final TextEditingController controller;
  final void Function([String?]) onSend;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Например: где есть Но-шпа?',
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(100),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Отправить',
              onPressed: enabled ? onSend : null,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.green,
                minimumSize: const Size(50, 50),
              ),
              icon: const Icon(Icons.arrow_upward),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onShowOnMap});

  final _Message message;
  final ValueChanged<Drug> onShowOnMap;

  @override
  Widget build(BuildContext context) {
    final mine = message.fromUser;
    final drug = message.drug;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: mine ? AppColors.green : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                color: mine ? Colors.white : AppColors.text,
              ),
            ),
            if (drug != null) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => onShowOnMap(drug),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.place, size: 18),
                label: const Text('Показать на карте'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Три прыгающие точки, пока ассистент «печатает».
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Transform.translate(
                  offset: Offset(0, -4 * math.max(0, math.sin(2 * math.pi * (_c.value - i * 0.15)))),
                  child: Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: const BoxDecoration(
                      color: AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
