import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../logic/assistant.dart';
import '../logic/llm_providers.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'voice_call_screen.dart';
import '../l10n/lang.dart';

/// Открыть ассистента во всплывающем окне снизу поверх карты.
/// Отвечает на русском, кыргызском и английском, только на аптечные темы:
/// где есть лекарство, где дешевле, аналоги и что купить при частых проблемах.
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
  const _Message(
    this.text, {
    required this.fromUser,
    this.drug,
    this.suggestions = const [],
    this.lang = AssistantLang.ru,
  });

  final String text;
  final bool fromUser;
  final Drug? drug;
  final List<Drug> suggestions;
  final AssistantLang lang;
}

class _AssistantSheet extends StatefulWidget {
  const _AssistantSheet();

  @override
  State<_AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends State<_AssistantSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Message>[
    const _Message(assistantGreeting, fromUser: false),
  ];
  bool _typing = false;
  Timer? _reply;

  /// Нейросеть на встроенном ключе; без ключа — офлайн-правила.
  final LlmAssistant? _llm = builtInLlmAssistant();

  @override
  void dispose() {
    _reply?.cancel();
    _llm?.close();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _addReply(AssistantReply reply) {
    if (!mounted) return;
    setState(() {
      _typing = false;
      _messages.add(
        _Message(
          reply.text,
          fromUser: false,
          drug: reply.drug,
          suggestions: reply.suggestions,
          lang: reply.lang,
        ),
      );
    });
    _scrollToEnd();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _typing) return;
    final state = AppScope.read(context);
    final catalog = state.catalog;
    AssistantReply offline() => catalog == null
        ? const AssistantReply(
            'Данные ещё загружаются, попробуйте через пару секунд.\n'
            'Маалымат жүктөлүүдө, бир аздан кийин кайталаңыз.\n'
            'Data is still loading, try again in a few seconds.',
          )
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

    final llm = _llm;
    if (llm == null || catalog == null) {
      // Короткая пауза с индикатором «печатает» — ответ не «выпрыгивает» мгновенно.
      final reply = offline();
      _reply = Timer(const Duration(milliseconds: 550), () => _addReply(reply));
      return;
    }

    try {
      final reply = await llm.reply(
        message: text,
        catalog: catalog,
        userLat: state.userLat,
        userLng: state.userLng,
        now: state.now,
      );
      _addReply(reply);
    } on LlmAssistantException catch (e) {
      debugPrint('$e');
      final fallback = offline();
      if (!mounted) return;
      final note = e.isAuthError
          ? tr(context, 'Ключ {p} не подошёл. Пока отвечаю офлайн.', {'p': llm.label})
          : e.isRateLimited
          ? tr(context, 'Лимит бесплатных запросов {p} исчерпан — попробуйте через минуту. Пока отвечаю офлайн.', {'p': llm.label})
          : tr(context, 'Нет связи с {p} — отвечаю офлайн.', {'p': llm.label});
      _addReply(
        AssistantReply(
          '${fallback.text}\n\n($note)',
          drug: fallback.drug,
          suggestions: fallback.suggestions,
          lang: fallback.lang,
        ),
      );
    }
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
    final height = math.min(media.size.height * 0.8, 680.0);

    return Padding(
      // Окно поднимается над клавиатурой.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _Header(
              provider: _llm?.label,
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                itemCount: _messages.length + (_typing ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _messages.length) return const _TypingBubble();
                  return FadeSlideIn(
                    key: ValueKey(i),
                    child: _Bubble(
                      message: _messages[i],
                      onShowOnMap: _showOnMap,
                    ),
                  );
                },
              ),
            ),
            if (_messages.length == 1)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                  children: [
                    for (final q in [
                      tr(context, 'Где есть Нурофен?'),
                      tr(context, 'Съел самсу, болит живот'),
                      tr(context, 'Заложен нос'),
                      tr(context, 'Аллергия на пыльцу'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _SuggestionChip(label: q, onTap: () => _send(q)),
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

/// Простое появление сообщения: снизу вверх с проявлением.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.provider,
    required this.onClose,
  });

  /// «Gemini» / «Claude», null — офлайн-правила.
  final String? provider;
  bool get online => provider != null;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFCCD5CF),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Row(
            children: [
              const _Orb(size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, 'Ассистент'),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: online ? AppColors.green : const Color(0xFFB4BDB8),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${online ? tr(context, 'ИИ {p}', {'p': provider!}) : tr(context, 'Офлайн')} · RU · KG · EN',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Голосовой «звонок» ассистенту (раньше — кнопка на карте).
              IconButton(
                tooltip: tr(context, 'Позвонить ассистенту'),
                onPressed: () {
                  // Навигатор берём до закрытия окна — потом контекст недействителен.
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => const VoiceCallScreen(),
                    ),
                  );
                },
                icon: Icon(Icons.call_rounded, color: AppColors.green),
              ),
              IconButton(
                tooltip: tr(context, 'Закрыть'),
                onPressed: onClose,
                icon: Icon(Icons.close_rounded, color: AppColors.textMuted),
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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.35, -0.4),
          radius: 0.9,
          colors: [Color(0xFF6BD47F), AppColors.green, AppColors.greenFill],
          stops: [0, 0.55, 1],
        ),
      ),
      child: Icon(Icons.auto_awesome, color: Colors.white, size: size * 0.46),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: AppColors.text),
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.enabled,
  });

  final TextEditingController controller;
  final void Function([String?]) onSend;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 4, 4, 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: tr(context, 'Спросите про лекарство…'),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: tr(context, 'Отправить'),
                    onPressed: enabled ? onSend : null,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.green,
                      minimumSize: const Size(44, 44),
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr(context, 'Ассистент не заменяет врача. При опасных симптомах звоните 103.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
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
    final catalog = AppScope.read(context).catalog;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * (mine ? 0.78 : 0.88),
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: mine ? AppColors.green : AppColors.surface,
          border: mine ? null : Border.all(color: AppColors.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(mine ? 20 : 6),
            bottomRight: Radius.circular(mine ? 6 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              // Приветствие — на языке интерфейса; ответы — как пришли.
              message.fromUser ? message.text : tr(context, message.text),
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: mine ? Colors.white : AppColors.text,
              ),
            ),
            if (drug != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => onShowOnMap(drug),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.place_rounded, size: 18),
                label: Text(showOnMapLabel(message.lang)),
              ),
            ],
            if (message.suggestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final d in message.suggestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _DrugCard(
                    drug: d,
                    minPrice: catalog?.minPrice(d.id),
                    lang: message.lang,
                    onTap: () => onShowOnMap(d),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Препарат из ответа: название, цена «от», переход на карту.
class _DrugCard extends StatelessWidget {
  const _DrugCard({
    required this.drug,
    required this.minPrice,
    required this.lang,
    required this.onTap,
  });

  final Drug drug;
  final int? minPrice;
  final AssistantLang lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = minPrice == null
        ? switch (lang) {
            AssistantLang.ky => 'азыр жок',
            AssistantLang.en => 'out of stock',
            AssistantLang.ru => 'нет в наличии',
          }
        : switch (lang) {
            AssistantLang.ky => '$minPrice сомдон',
            AssistantLang.en => 'from $minPrice som',
            AssistantLang.ru => 'от $minPrice сом',
          };
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.medication_rounded, size: 18, color: AppColors.green),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drug.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      price,
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.place_rounded, size: 18, color: AppColors.green),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
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

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

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
        decoration: BoxDecoration(
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
                  offset: Offset(
                    0,
                    -4 *
                        math.max(
                          0,
                          math.sin(2 * math.pi * (_c.value - i * 0.15)),
                        ),
                  ),
                  child: Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
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
