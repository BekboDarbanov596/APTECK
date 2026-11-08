import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

/// Источник данных для приложения.
///
/// Сейчас — [DemoCatalogRepository] (локальный JSON с демо-данными).
/// Когда появится Firebase-проект, добавляем FirestoreCatalogRepository
/// с тем же интерфейсом — экраны менять не придётся.
abstract interface class CatalogRepository {
  Future<Catalog> load();
}

class DemoCatalogRepository implements CatalogRepository {
  const DemoCatalogRepository({this.assetPath = 'assets/demo_data.json'});

  final String assetPath;

  @override
  Future<Catalog> load() async {
    final raw = await rootBundle.loadString(assetPath);
    return Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
