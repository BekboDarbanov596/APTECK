import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../logic/routing.dart';

/// Позвонить в аптеку. В демо-данных телефонов нет — честно сообщаем.
Future<void> callPharmacy(BuildContext context, Pharmacy pharmacy) async {
  final phone = pharmacy.phone;
  final messenger = ScaffoldMessenger.of(context);
  if (phone == null || phone.isEmpty) {
    messenger.showSnackBar(const SnackBar(
      content: Text('Номер телефона появится после подключения аптеки к сервису'),
    ));
    return;
  }
  final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), ''));
  if (!await launchUrl(uri)) {
    messenger.showSnackBar(SnackBar(content: Text('Не удалось позвонить: $phone')));
  }
}

/// Открыть маршрут до аптеки во внешнем навигаторе (Google Карты).
Future<void> openRoute(BuildContext context, Pharmacy pharmacy, {TravelMode? mode}) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '${pharmacy.lat},${pharmacy.lng}',
    if (mode != null) 'travelmode': mode == TravelMode.walk ? 'walking' : 'driving',
  });
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Не удалось открыть карты')),
    );
  }
}
