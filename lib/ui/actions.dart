import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../logic/routing.dart';
import '../l10n/lang.dart';

/// Позвонить в аптеку. В демо-данных телефонов нет — честно сообщаем.
Future<void> callPharmacy(BuildContext context, Pharmacy pharmacy) async {
  final phone = pharmacy.phone;
  final messenger = ScaffoldMessenger.of(context);
  if (phone == null || phone.isEmpty) {
    messenger.showSnackBar(SnackBar(
      content: Text(tr(context, 'Номер телефона появится после подключения аптеки к сервису')),
    ));
    return;
  }
  final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), ''));
  final failed = tr(context, 'Не удалось позвонить: {p}', {'p': phone});
  if (!await launchUrl(uri)) {
    messenger.showSnackBar(SnackBar(content: Text(failed)));
  }
}

/// Ссылка 2ГИС на маршрут общественным транспортом (`rsType/ctx`) от текущего
/// местоположения до точки. Координаты в 2ГИС — сначала долгота, потом широта.
/// Формат: https://help.2gis.com/question/developers-launching-2gis-navigation-using-deeplink
Uri twoGisTransitUri(double lat, double lng) =>
    Uri.parse('dgis://2gis.ru/routeSearch/rsType/ctx/to/$lng,$lat');

/// Открыть маршрут до аптеки во внешнем навигаторе.
/// Автобус и маршрутки — в 2ГИС: там реальные номера, пересадки и время
/// по Бишкеку. Если 2ГИС не установлен — Google Карты в режиме транспорта.
Future<void> openRoute(BuildContext context, Pharmacy pharmacy, {TravelMode? mode}) async {
  final messenger = ScaffoldMessenger.of(context);
  final failText = tr(context, 'Не удалось открыть карты');
  if (mode == TravelMode.bus) {
    try {
      if (await launchUrl(
        twoGisTransitUri(pharmacy.lat, pharmacy.lng),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      // 2ГИС не установлен — дальше откроем Google Карты.
    }
  }
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '${pharmacy.lat},${pharmacy.lng}',
    if (mode != null) 'travelmode': mode.googleMode,
  });
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    messenger.showSnackBar(
      SnackBar(content: Text(failText)),
    );
  }
}
