import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../l10n/lang.dart';
import '../logic/assistant.dart';
import '../logic/llm_providers.dart';
import '../state/app_state.dart';
import 'assistant_screen.dart';
import 'theme.dart';

enum _CallState { connecting, listening, thinking, speaking, muted, error }

/// «Звонок» ассистенту: слушает голос, отвечает голосом и снова слушает.
/// Отвечает той же нейросетью, что и чат (ключ из настроек ассистента),
/// а без ключа — встроенными правилами.
class VoiceCallScreen extends StatefulWidget {
  const VoiceCallScreen({super.key});

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> with SingleTickerProviderStateMixin {
  final _speech = SpeechToText();
  final _tts = FlutterTts();
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  LlmAssistant? _llm;
  _CallState _state = _CallState.connecting;
  String _heard = '';
  String _reply = '';
  String? _error;
  double _level = 0;
  bool _ended = false;
  final _started = DateTime.now();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _ended = true;
    _clock?.cancel();
    _pulse.dispose();
    _speech.cancel();
    _tts.stop();
    _llm?.close();
    super.dispose();
  }

  AppLang get _lang => langOf(context);

  String get _sttLocale => switch (_lang) {
        AppLang.ru => 'ru_RU',
        AppLang.ky => 'ky_KG',
        AppLang.en => 'en_US',
      };

  Future<void> _start() async {
    // Ключ нейросети — тот же, что сохранён в окне ассистента.
    try {
      if (AppScope.read(context).useDeviceServices) {
        final prefs = await SharedPreferences.getInstance();
        final key = prefs.getString('llm_api_key') ?? prefs.getString('claude_api_key');
        if (key != null && key.isNotEmpty) _llm = llmAssistantForKey(key);
      }
    } catch (_) {}

    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(kIsWeb ? 1.0 : 0.5);
    } catch (_) {
      // Озвучки нет — ответы будут только текстом на экране.
    }

    bool ok = false;
    try {
      ok = await _speech.initialize(
        onStatus: (s) {
          if (!mounted || _ended) return;
          // Пользователь замолчал, а итоговой фразы нет — слушаем снова.
          if ((s == SpeechToText.doneStatus || s == SpeechToText.notListeningStatus) &&
              _state == _CallState.listening &&
              !_speech.isListening) {
            Future.delayed(const Duration(milliseconds: 400), _listen);
          }
        },
        onError: (e) {
          if (!mounted || _ended) return;
          if (e.errorMsg.contains('permission') || e.errorMsg.contains('not-allowed')) {
            setState(() {
              _state = _CallState.error;
              _error = tr(context, 'Нет доступа к микрофону. Разрешите его в настройках браузера.');
            });
          } else if (_state == _CallState.listening) {
            Future.delayed(const Duration(milliseconds: 600), _listen);
          }
        },
      );
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _state = _CallState.error;
        _error = tr(context, 'Голосовой ввод недоступен на этом устройстве.');
      });
      return;
    }
    final hello = tr(context, 'Слушаю вас. Спросите про лекарство или расскажите, что беспокоит.');
    setState(() => _reply = hello);
    await _say(hello);
    _listen();
  }

  Future<void> _listen() async {
    if (!mounted || _ended || _state == _CallState.muted || _state == _CallState.error) return;
    if (_speech.isListening) return;
    setState(() {
      _state = _CallState.listening;
      _level = 0;
    });
    try {
      await _speech.listen(
        onResult: (r) {
          if (!mounted || _ended) return;
          setState(() => _heard = r.recognizedWords);
          if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
            _answer(r.recognizedWords.trim());
          }
        },
        onSoundLevelChange: (l) {
          if (mounted) setState(() => _level = ((l + 2) / 12).clamp(0.0, 1.0));
        },
        listenOptions: SpeechListenOptions(
          localeId: _sttLocale,
          partialResults: true,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          cancelOnError: true,
        ),
      );
    } catch (_) {}
  }

  Future<void> _answer(String text) async {
    if (_state == _CallState.thinking) return;
    await _speech.stop();
    if (!mounted) return;
    setState(() {
      _state = _CallState.thinking;
      _heard = text;
    });

    final state = AppScope.read(context);
    final catalog = state.catalog;
    AssistantReply reply;
    if (catalog == null) {
      reply = AssistantReply(tr(context, 'Каталог ещё загружается.'));
    } else {
      final offline = assistantReply(
        message: text,
        catalog: catalog,
        userLat: state.userLat,
        userLng: state.userLng,
        now: state.now,
      );
      final llm = _llm;
      if (llm == null) {
        reply = offline;
      } else {
        try {
          reply = await llm.reply(
            message: text,
            catalog: catalog,
            userLat: state.userLat,
            userLng: state.userLng,
            now: state.now,
          );
        } on LlmAssistantException {
          reply = offline;
        }
      }
    }
    if (!mounted || _ended) return;
    setState(() => _reply = reply.text);
    await _say(reply.text, lang: reply.lang);
    _listen();
  }

  /// Озвучить ответ: без значков списков и предупреждений, не слишком длинно.
  Future<void> _say(String text, {AssistantLang? lang}) async {
    if (!mounted || _ended) return;
    setState(() => _state = _CallState.speaking);
    final code = switch (lang) {
      AssistantLang.ky => 'ky-KG',
      AssistantLang.en => 'en-US',
      AssistantLang.ru => 'ru-RU',
      null => switch (_lang) {
          AppLang.ky => 'ky-KG',
          AppLang.en => 'en-US',
          AppLang.ru => 'ru-RU',
        },
    };
    try {
      // Если кыргызского голоса нет — читаем по-русски, это ближе всего.
      final ok = await _tts.isLanguageAvailable(code);
      await _tts.setLanguage(ok == true ? code : (code == 'ky-KG' ? 'ru-RU' : code));
    } catch (_) {}
    var clean = text
        .replaceAll(RegExp(r'[•⚠️✅❗]'), '')
        .replaceAll(RegExp(r'\s*\n+\s*'), '. ')
        .replaceAll(RegExp(r'\.\s*\.'), '.')
        .trim();
    if (clean.length > 600) clean = '${clean.substring(0, 600)}…';
    try {
      await _tts.speak(clean);
    } catch (_) {}
  }

  Future<void> _toggleMute() async {
    if (_state == _CallState.muted) {
      setState(() => _state = _CallState.listening);
      _listen();
    } else {
      await _speech.stop();
      await _tts.stop();
      if (mounted) setState(() => _state = _CallState.muted);
    }
  }

  void _openChat() {
    final nav = Navigator.of(context);
    nav.pop();
    showAssistantSheet(nav.context);
  }

  String get _status => switch (_state) {
        _CallState.connecting => tr(context, 'Соединяем…'),
        _CallState.listening => tr(context, 'Слушаю…'),
        _CallState.thinking => tr(context, 'Думаю…'),
        _CallState.speaking => tr(context, 'Говорю…'),
        _CallState.muted => tr(context, 'Микрофон выключен'),
        _CallState.error => tr(context, 'Не получается слушать'),
      };

  String get _duration {
    final d = DateTime.now().difference(_started);
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final provider = _llm?.label;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF123A2A), Color(0xFF0B1F17)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              children: [
                Text(
                  tr(context, 'Ассистент'),
                  style: const TextStyle(
                    fontFamily: 'Unbounded',
                    fontVariations: [FontVariation('wght', 700)],
                    fontSize: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${provider == null ? tr(context, 'Офлайн') : 'ИИ $provider'} · $_duration',
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
                ),
                const Spacer(),
                // Шар ассистента: дышит, когда слушает — растёт от громкости.
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    final t = _pulse.value;
                    final active = _state == _CallState.listening || _state == _CallState.speaking;
                    final boost = _state == _CallState.listening ? _level * 0.25 : 0.0;
                    return SizedBox.square(
                      dimension: 260,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Opacity(
                              opacity: active ? (1 - ((t + i / 3) % 1)) * 0.35 : 0.08,
                              child: Container(
                                width: 150 + 110 * ((t + i / 3) % 1),
                                height: 150 + 110 * ((t + i / 3) % 1),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF6BD47F), width: 1.5),
                                ),
                              ),
                            ),
                          Transform.scale(
                            scale: 1 +
                                boost +
                                (_state == _CallState.thinking ? 0.04 * math.sin(t * math.pi * 4) : 0),
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  center: Alignment(-0.35, -0.4),
                                  radius: 0.9,
                                  colors: [Color(0xFF8BE39B), AppColors.green, AppColors.greenDark],
                                  stops: [0, 0.55, 1],
                                ),
                                boxShadow: [
                                  BoxShadow(color: Color(0x662E9F46), blurRadius: 50, spreadRadius: 6),
                                ],
                              ),
                              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 54),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  _status,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 18),
                // Последние реплики.
                SizedBox(
                  height: 150,
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Column(
                      children: [
                        if (_heard.isNotEmpty)
                          Text(
                            '«$_heard»',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, height: 1.4, color: Colors.white.withValues(alpha: 0.6)),
                          ),
                        if (_heard.isNotEmpty) const SizedBox(height: 10),
                        Text(
                          _error ?? _reply,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, height: 1.45, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallButton(
                      icon: _state == _CallState.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: tr(context, _state == _CallState.muted ? 'Включить' : 'Микрофон'),
                      onTap: _state == _CallState.error ? null : _toggleMute,
                      selected: _state == _CallState.muted,
                    ),
                    _CallButton(
                      icon: Icons.call_end_rounded,
                      label: tr(context, 'Завершить'),
                      color: const Color(0xFFE5484D),
                      big: true,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    _CallButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: tr(context, 'Чат'),
                      onTap: _openChat,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.big = false,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool big;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final size = big ? 76.0 : 62.0;
    final bg = color ?? (selected ? Colors.white : Colors.white.withValues(alpha: 0.12));
    final fg = color != null ? Colors.white : (selected ? const Color(0xFF123A2A) : Colors.white);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, color: fg, size: big ? 34 : 26),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75))),
      ],
    );
  }
}
