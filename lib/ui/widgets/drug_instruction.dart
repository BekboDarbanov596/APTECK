import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models.dart';
import '../../l10n/lang.dart';
import '../theme.dart';

class DrugInstruction extends StatelessWidget {
  const DrugInstruction({super.key, required this.drug});

  final Drug drug;

  static final _nazivinLeaflet = Uri.https(
    'nasivin.com.kz',
    '/kz/assets/template/pdf/Називин_спрей_005_rus.pdf',
  );

  @override
  Widget build(BuildContext context) {
    final hasLeaflet =
        drug.id == 'nazivin-005' &&
        drug.strength == '0,05%' &&
        drug.form == 'Спрей назальный' &&
        drug.pack == '10 мл';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 14,
          children: [
            _section(
              context,
              'Состав',
              hasLeaflet
                  ? 'Оксиметазолина гидрохлорид, 0,5 мг в 1 мл раствора.'
                  : drug.inn.isEmpty
                  ? tr(context, 'Состав уточняйте в инструкции к упаковке.')
                  : drug.inn,
            ),
            if (hasLeaflet) ...[
              _section(
                context,
                'Когда применяют',
                'При насморке на фоне ОРЗ, аллергическом и вазомоторном рините.',
              ),
              _section(
                context,
                'Как применять',
                'С 6 лет: по одному впрыскиванию в каждую ноздрю, 2–3 раза за сутки. Без консультации врача курс не должен превышать 5–7 дней.',
              ),
              _section(
                context,
                'Когда нельзя применять',
                'До 6 лет, при атрофическом рините, аллергии на компоненты и после некоторых операций на твёрдой мозговой оболочке. Сверьте ограничения и взаимодействия с инструкцией из упаковки.',
              ),
              OutlinedButton.icon(
                onPressed: () => _openLeaflet(context),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(
                  tr(context, 'Инструкция для этой формы (Казахстан)'),
                ),
              ),
            ] else
              _section(
                context,
                'Как применять',
                tr(
                  context,
                  'Дозировка и ограничения указаны в инструкции к конкретной упаковке.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLeaflet(BuildContext context) async {
    if (await launchUrl(
      _nazivinLeaflet,
      mode: LaunchMode.externalApplication,
    )) {
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'Не удалось открыть инструкцию'))),
      );
    }
  }

  Widget _section(BuildContext context, String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(
          tr(context, title),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        Text(
          tr(context, body),
          style: TextStyle(color: AppColors.textMuted, height: 1.35),
        ),
      ],
    );
  }
}
