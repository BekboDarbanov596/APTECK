import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data/models.dart';
import '../logic/drug_search.dart';
import '../state/app_state.dart';
import 'home_screen.dart' show popularDrugIds;
import 'theme.dart';
import 'widgets/common.dart';
import '../l10n/lang.dart';

/// Поиск лекарства: ввод текстом или голосом, подсказки по мере ввода.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.onPicked,
    this.embedded = false,
    this.startVoice = false,
  });

  /// Человек выбрал лекарство.
  final ValueChanged<Drug> onPicked;

  /// true — экран открыт вкладкой внизу (без стрелки «назад»).
  final bool embedded;
  final bool startVoice;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _speech = SpeechToText();
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    if (widget.startVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toggleVoice());
    } else if (!widget.embedded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    bool available;
    try {
      available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) {
            setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
    } catch (_) {
      available = false;
    }
    if (!mounted) return;
    if (!available) {
      messenger.showSnackBar(SnackBar(
        content: Text(tr(context, 'Голосовой ввод недоступен: разрешите доступ к микрофону')),
      ));
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        _controller.value = TextEditingValue(
          text: result.recognizedWords,
          selection: TextSelection.collapsed(offset: result.recognizedWords.length),
        );
      },
      listenOptions: SpeechListenOptions(
        localeId: 'ru_RU',
        partialResults: true,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  void _pick(Drug drug) {
    FocusScope.of(context).unfocus();
    widget.onPicked(drug);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final catalog = state.catalog;
    final query = _controller.text;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        titleSpacing: widget.embedded ? 16 : 0,
        toolbarHeight: 72,
        title: _buildField(),
      ),
      body: catalog == null
          ? const Center(child: CircularProgressIndicator())
          : query.trim().isEmpty
              ? _buildSuggestions(state, catalog)
              : _buildResults(state, catalog, query),
    );
  }

  Widget _buildField() {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 17),
        decoration: InputDecoration(
          hintText: _listening ? 'Говорите…' : 'Название лекарства',
          filled: true,
          fillColor: AppColors.surface,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  tooltip: tr(context, 'Очистить'),
                  onPressed: _controller.clear,
                  icon: const Icon(Icons.close),
                )
              : IconButton(
                  tooltip: tr(context, _listening ? 'Остановить' : 'Голосовой поиск'),
                  onPressed: _toggleVoice,
                  icon: Icon(
                    _listening ? Icons.stop_circle : Icons.mic,
                    color: _listening ? Colors.red : AppColors.green,
                  ),
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: const BorderSide(color: AppColors.green, width: 1.5),
          ),
        ),
        onSubmitted: (text) {
          final found = searchDrugs(AppScope.read(context).catalog?.drugs ?? const [], text);
          if (found.isNotEmpty) _pick(found.first);
        },
      ),
    );
  }

  Widget _buildSuggestions(AppState state, Catalog catalog) {
    final recent = state.recentDrugs;
    final popular = [
      for (final id in popularDrugIds)
        ?catalog.drug(id),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (recent.isNotEmpty) ...[
          const _SectionTitle('Вы недавно искали'),
          for (final d in recent) _DrugRow(drug: d, onTap: () => _pick(d), leading: Icons.history),
          const SizedBox(height: 12),
        ],
        const _SectionTitle('Часто ищут'),
        for (final d in popular) _DrugRow(drug: d, onTap: () => _pick(d)),
      ],
    );
  }

  Widget _buildResults(AppState state, Catalog catalog, String query) {
    final found = searchDrugs(catalog.drugs, query);
    if (found.isEmpty) {
      return SingleChildScrollView(
        child: MessageView(
          icon: Icons.search_off,
          title: tr(context, 'Ничего не нашли'),
          text: 'Проверьте название. Можно искать по действующему веществу, '
              'например «ибупрофен».',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        for (final d in found) _DrugRow(drug: d, onTap: () => _pick(d), showAvailability: true),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      );
}

class _DrugRow extends StatelessWidget {
  const _DrugRow({
    required this.drug,
    required this.onTap,
    this.leading = Icons.medication_outlined,
    this.showAvailability = false,
  });

  final Drug drug;
  final VoidCallback onTap;
  final IconData leading;
  final bool showAvailability;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    String? availability;
    if (showAvailability) {
      final offers = state.catalog!.offersForDrug(drug.id);
      availability = offers.isEmpty
          ? 'Нет в наличии'
          : 'В ${offers.length} аптеках · от ${formatPrice(offers.map((o) => o.price).reduce((a, b) => a < b ? a : b))}';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(leading, color: AppColors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(drug.title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      Text(drug.subtitle,
                          style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
                      if (availability != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            availability,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.greenDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (drug.rx) ...[const SizedBox(width: 8), Pill.rx()],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
