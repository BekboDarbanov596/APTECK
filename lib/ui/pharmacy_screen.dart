import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../logic/geo.dart';
import '../logic/opening_hours.dart';
import '../state/app_state.dart';
import 'actions.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Карточка аптеки: адрес, часы, телефон, выбранное лекарство и ассортимент.
class PharmacyScreen extends StatelessWidget {
  const PharmacyScreen({super.key, required this.pharmacyId});

  final String pharmacyId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final catalog = state.catalog!;
    final p = catalog.pharmacy(pharmacyId);
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const MessageView(icon: Icons.error_outline, title: 'Аптека не найдена'),
      );
    }

    final now = state.now;
    final open = isOpenAt(p, now);
    final distance = distanceMeters(state.userLat, state.userLng, p.lat, p.lng);
    final fav = state.isFavoritePharmacy(p.id);
    final drug = state.selectedDrug;
    final offers = catalog.offersForPharmacy(p.id)
      ..sort((a, b) => catalog.drug(a.drugId)!.name.compareTo(catalog.drug(b.drugId)!.name));
    final selectedOffer = drug == null
        ? null
        : offers.where((o) => o.drugId == drug.id).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: fav ? 'Убрать из избранного' : 'В избранное',
            onPressed: () => state.toggleFavoritePharmacy(p.id),
            icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                color: fav ? AppColors.green : AppColors.text),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => callPharmacy(context, p),
                  icon: const Icon(Icons.call),
                  label: const Text('Позвонить'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openRoute(context, p),
                  icon: const Icon(Icons.directions),
                  label: const Text('Маршрут'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              const PharmacyAvatar(size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.chain,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                    Text('${p.address} · ${formatDistance(distance)}',
                        style: const TextStyle(fontSize: 16, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: open
                ? Pill.open(label: openingStatus(p, now))
                : Pill.closed(label: openingStatus(p, now)),
          ),
          const SizedBox(height: 16),
          if (drug != null) ...[
            _Card(
              child: Row(
                children: [
                  const Icon(Icons.medication, color: AppColors.green, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(drug.title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        Text(drug.subtitle,
                            style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
                        if (drug.rx) ...[const SizedBox(height: 6), Pill.rx()],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (selectedOffer != null) ...[
                        Text(formatPrice(selectedOffer.price),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        const Text('Есть в наличии',
                            style: TextStyle(
                                color: AppColors.greenDark, fontWeight: FontWeight.w600)),
                      ] else
                        const Text('Нет в наличии',
                            style: TextStyle(
                                color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _Card(
            child: Column(
              children: [
                _InfoRow(icon: Icons.schedule, title: 'Часы работы', value: scheduleText(p)),
                const Divider(height: 24),
                _InfoRow(
                  icon: Icons.call_outlined,
                  title: 'Телефон',
                  value: p.phone ?? 'Появится после подключения аптеки',
                ),
                const Divider(height: 24),
                _InfoRow(icon: Icons.place_outlined, title: 'Адрес', value: 'Бишкек, ${p.address}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 170,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(p.lat, p.lng),
                  initialZoom: 15.5,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'kg.aptekaryadom.apteka_ryadom',
                  ),
                  MarkerLayer(markers: [
                    Marker(
                      point: LatLng(p.lat, p.lng),
                      width: 40,
                      height: 40,
                      child: const PharmacyAvatar(size: 40),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('В наличии в этой аптеке (${offers.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _Card(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final o in offers)
                  if (catalog.drug(o.drugId) case final d?)
                    ListTile(
                      title: Text(d.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(d.rx ? '${d.subtitle} · по рецепту' : d.subtitle),
                      trailing: Text(formatPrice(o.price),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
              ],
            ),
          ),
          if (catalog.isDemo) ...[
            const SizedBox(height: 12),
            const Text(
              'Демо-данные: цены и наличие примерные. Уточняйте в аптеке.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      );
}
