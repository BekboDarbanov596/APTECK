import '../data/models.dart';

/// Открыта ли аптека в момент [now]. Учитывает график через полночь.
bool isOpenAt(Pharmacy p, DateTime now) {
  if (p.isAroundTheClock) return true;
  final open = _minutes(p.opensAt!);
  final close = _minutes(p.closesAt!);
  final m = now.hour * 60 + now.minute;
  if (open == close) return true;
  if (open < close) return m >= open && m < close;
  return m >= open || m < close; // например 20:00–08:00
}

/// «Открыто до 22:00», «Закрыто до 08:00», «Круглосуточно».
String openingStatus(Pharmacy p, DateTime now) {
  if (p.isAroundTheClock) return 'Круглосуточно';
  return isOpenAt(p, now) ? 'Открыто до ${p.closesAt}' : 'Закрыто до ${p.opensAt}';
}

/// «08:00–22:00» или «Круглосуточно».
String scheduleText(Pharmacy p) =>
    p.isAroundTheClock ? 'Круглосуточно' : 'Ежедневно ${p.opensAt}–${p.closesAt}';

int _minutes(String hhmm) {
  final parts = hhmm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}
