import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_state.dart';

const _green = Color(0xFF204C43);
const _muted = Color(0xFF72827B);

class ProfilePreferences extends StatelessWidget {
  const ProfilePreferences({super.key, required this.state});
  final AppState state;

  Future<void> _copyFavorites(BuildContext context) async {
    final catalog = state.catalog;
    final lines = <String>[
      'Мой список · Аптека рядом',
      for (final id in state.favoriteDrugIds)
        if (catalog?.drug(id) case final drug?)
          '• ${drug.title} — ${drug.subtitle}',
      if (state.favoritePharmacyIds.isNotEmpty) '\nАптеки:',
      for (final id in state.favoritePharmacyIds)
        if (catalog?.pharmacy(id) case final pharmacy?)
          '• ${pharmacy.chain}, ${pharmacy.address}',
    ];
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: lines.join('\n')));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Список скопирован — его можно отправить близким'),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Не удалось скопировать список. Попробуйте ещё раз.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFavorites =
        state.favoriteDrugIds.any((id) => state.catalog?.drug(id) != null) ||
        state.favoritePharmacyIds.any(
          (id) => state.catalog?.pharmacy(id) != null,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('КАК ИСКАТЬ АПТЕКИ'),
        const SizedBox(height: 10),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(23),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                activeTrackColor: _green,
                title: const Text(
                  'Только открытые',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Скрывать аптеки, закрытые сейчас',
                  style: TextStyle(fontSize: 10, height: 1.4, color: _muted),
                ),
                value: state.onlyOpen,
                onChanged: (value) =>
                    state.setSearchPreferences(onlyOpen: value),
              ),
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Color(0xFFEDF0ED),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Сначала показывать',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 11),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<SortMode>(
                        style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          selectedBackgroundColor: const Color(0xFFE3EEE7),
                          selectedForegroundColor: _green,
                          side: const BorderSide(color: Color(0xFFE1E8E3)),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: SortMode.nearest,
                            label: Text('Ближе'),
                            icon: Icon(Icons.near_me_outlined, size: 15),
                          ),
                          ButtonSegment(
                            value: SortMode.cheapest,
                            label: Text('Дешевле'),
                            icon: Icon(Icons.payments_outlined, size: 15),
                          ),
                        ],
                        selected: {state.sort},
                        onSelectionChanged: (value) =>
                            state.setSearchPreferences(sort: value.first),
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'Сортировка по цене работает после выбора лекарства. Настройки сохраняются на этом устройстве.',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.5,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 23),
        const _Label('МОИ ДАННЫЕ'),
        const SizedBox(height: 10),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(23),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                activeTrackColor: _green,
                title: const Text(
                  'Сохранять историю',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  state.historyEnabled
                      ? 'Быстро возвращаться к недавним поискам'
                      : 'Новые поиски не записываются. Старую историю можно очистить отдельно.',
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.4,
                    color: _muted,
                  ),
                ),
                value: state.historyEnabled,
                onChanged: state.setHistoryEnabled,
              ),
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Color(0xFFEDF0ED),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                enabled: hasFavorites,
                leading: const Icon(
                  Icons.copy_all_outlined,
                  size: 20,
                  color: _green,
                ),
                title: const Text(
                  'Скопировать избранное',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  hasFavorites
                      ? 'Лекарства и адреса аптек одним списком'
                      : 'Сначала добавьте лекарство или аптеку',
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.4,
                    color: _muted,
                  ),
                ),
                trailing: Icon(
                  Icons.north_east_rounded,
                  size: 15,
                  color: hasFavorites ? _green : const Color(0xFFAFBBB3),
                ),
                onTap: hasFavorites ? () => _copyFavorites(context) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w700,
        color: _muted,
      ),
    ),
  );
}
