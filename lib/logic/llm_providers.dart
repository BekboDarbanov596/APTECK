import 'package:http/http.dart' as http;

import 'claude_assistant.dart';
import 'gemini_assistant.dart';
import 'groq_assistant.dart';

export 'llm_assistant.dart';

/// Подобрать модель по ключу: «gsk_…» — Groq (Qwen, бесплатно),
/// «sk-ant-…» — Claude, остальные (у Gemini — «AIza…») — Gemini.
LlmAssistant? llmAssistantForKey(String key, {http.Client? client}) {
  final k = key.trim();
  if (k.isEmpty) return null;
  if (k.startsWith('gsk_')) return GroqAssistant(apiKey: k, client: client);
  if (k.startsWith('sk-ant-')) return ClaudeAssistant(apiKey: k, client: client);
  return GeminiAssistant(apiKey: k, client: client);
}
