import 'package:flutter/material.dart';

import '../data/models.dart';
import '../logic/geo.dart';
import '../logic/opening_hours.dart';
import '../state/app_state.dart';
import 'home_screen.dart' show flipRoute;
import 'pharmacy_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';

export 'profile_screen.dart';

/// Вкладка «Избранное»: сохранённые лекарства и аптеки.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, required this.onDrugPicked});

  final ValueChanged<Drug> onDrugPicked;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final catalog = state.catalog;
    final drugs = [for (final id in state.favoriteDrugIds) ?catalog?.drug(id)];
    final pharmacies = [
      for (final id in state.favoritePharmacyIds) ?catalog?.pharmacy(id),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Избранное')),
      body: drugs.isEmpty && pharmacies.isEmpty
          ? const Center(
              child: SingleChildScrollView(
                child: MessageView(
                  icon: Icons.favorite_border,
                  title: 'Здесь пока пусто',
                  text: 'Нажмите ♡ у лекарства или аптеки, чтобы быстро находить их здесь.',
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (drugs.isNotEmpty) ...[
                  const _Title('Лекарства'),
                  for (final d in drugs)
                    _Tile(
                      icon: Icons.medication_outlined,
                      title: d.title,
                      subtitle: d.subtitle,
                      onTap: () => onDrugPicked(d),
                      onRemove: () => state.toggleFavoriteDrug(d.id),
                    ),
                ],
                if (pharmacies.isNotEmpty) ...[
                  const _Title('Аптеки'),
                  for (final p in pharmacies)
                    _Tile(
                      icon: Icons.local_pharmacy_outlined,
                      title: p.chain,
                      subtitle:
                          '${p.address} · ${formatDistance(distanceMeters(state.userLat, state.userLng, p.lat, p.lng))}'
                          ' · ${openingStatus(p, state.now)}',
                      onTap: () => Navigator.of(context)
                          .push(flipRoute(PharmacyScreen(pharmacyId: p.id))),
                      onRemove: () => state.toggleFavoritePharmacy(p.id),
                    ),
                ],
              ],
            ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onRemove,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(icon, color: AppColors.green),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        onTap: onTap,
        trailing: IconButton(
          tooltip: 'Убрать из избранного',
          onPressed: onRemove,
          icon: const Icon(Icons.favorite, color: AppColors.green),
        ),
      ),
    ),
  );
}
