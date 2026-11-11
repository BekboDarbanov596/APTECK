import 'package:flutter/material.dart';

import '../theme.dart';
import '../../l10n/lang.dart';

/// Зелёный крест — логотип приложения.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    final bar = size * 0.36;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: bar,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(size * 0.1),
            ),
          ),
          Container(
            width: size,
            height: bar,
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(size * 0.1),
            ),
          ),
          Icon(Icons.eco, color: Colors.white, size: size * 0.32),
        ],
      ),
    );
  }
}

/// Цветная «таблетка» с текстом: «Открыто», «Нужен рецепт», «Демо-данные».
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.onTap,
    this.fontSize = 14,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final VoidCallback? onTap;
  final double fontSize;

  factory Pill.open({String? label}) => Pill(
        label: label ?? trNow('Открыто'),
        background: AppColors.greenSoft,
        foreground: AppColors.greenDark,
      );

  factory Pill.closed({String? label}) => Pill(
        label: label ?? trNow('Закрыто'),
        background: AppColors.greySoft,
        foreground: AppColors.textMuted,
      );

  factory Pill.rx() => Pill(
        label: 'Нужен рецепт',
        icon: Icons.description_outlined,
        background: AppColors.orangeSoft,
        foreground: AppColors.orange,
      );

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 4, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(
            tr(context, label),
            style: TextStyle(
              color: foreground,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// Плашка «Демо-данные», по нажатию объясняет, что это.
class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Pill(
      label: tr(context, 'Демо-данные'),
      icon: Icons.info_outline,
      background: AppColors.orangeSoft,
      foreground: AppColors.orange,
      fontSize: 13,
      onTap: () => showDemoInfo(context),
    );
  }
}

void showDemoInfo(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr(context, 'Демо-данные')),
      content: Text(
        tr(
          context,
          // Одной строкой — это ключ перевода в strings.dart.
          'Аптеки и их адреса на карте настоящие — из OpenStreetMap. Названия лекарств настоящие, а цены и наличие пока примерные.\n\nРеальные остатки появятся после подключения аптек к сервису. Перед поездкой уточняйте наличие по телефону.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'Понятно')),
        ),
      ],
    ),
  );
}

/// Белая кнопка-«таблетка» из ряда «Карта / Список / Фильтры / Сортировка».
class ToolbarChip extends StatelessWidget {
  const ToolbarChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.text;
    return Material(
      color: selected ? AppColors.green : AppColors.surface,
      borderRadius: BorderRadius.circular(100),
      elevation: selected ? 2 : 0,
      shadowColor: const Color(0x33000000),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: selected ? null : Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 6),
                CircleAvatar(
                  radius: 10,
                  backgroundColor: selected ? Colors.white : AppColors.green,
                  child: Text(
                    '$badge',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.green : Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Круглая зелёная иконка с крестом (аптека в списке).
class PharmacyAvatar extends StatelessWidget {
  const PharmacyAvatar({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: cardShadow,
      ),
      alignment: Alignment.center,
      child: Container(
        width: size * 0.66,
        height: size * 0.66,
        decoration: BoxDecoration(
          color: AppColors.green,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.add, color: Colors.white, size: size * 0.5, weight: 900),
      ),
    );
  }
}

/// Сообщение на весь блок: «ничего не найдено», «нет интернета» и т. п.
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppColors.green),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          if (text != null) ...[
            const SizedBox(height: 8),
            Text(
              text!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textMuted),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Цена: «68 сом».
String formatPrice(int price) => trNow('{n} сом', {'n': price});
