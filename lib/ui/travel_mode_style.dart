import 'package:flutter/material.dart';

import '../logic/routing.dart';
import 'theme.dart';

/// Иконка способа передвижения.
IconData travelModeIcon(TravelMode mode) => switch (mode) {
      TravelMode.walk => Icons.directions_walk_rounded,
      TravelMode.bus => Icons.directions_bus_rounded,
      TravelMode.bike => Icons.directions_bike_rounded,
      TravelMode.scooter => Icons.electric_scooter_rounded,
      TravelMode.car => Icons.directions_car_rounded,
    };

/// Цвет способа передвижения — для плашек, панели маршрута и линии.
Color travelModeColor(TravelMode mode) => switch (mode) {
      TravelMode.walk => AppColors.green,
      TravelMode.bus => const Color(0xFFE0821E),
      TravelMode.bike => const Color(0xFF0E9AA7),
      TravelMode.scooter => const Color(0xFF7A4FD6),
      TravelMode.car => const Color(0xFF1F6FD1),
    };
