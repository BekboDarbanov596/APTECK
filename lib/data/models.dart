/// Модели данных. Тот же формат лежит в assets/demo_data.json
/// и потом будет храниться в Firestore (коллекции drugs, pharmacies, offers).
library;

class Drug {
  const Drug({
    required this.id,
    required this.name,
    required this.strength,
    required this.form,
    required this.pack,
    required this.inn,
    required this.rx,
    this.aliases = const [],
    this.category = '',
  });

  final String id;
  final String name;

  /// Дозировка, например «500 мг». Может быть пустой.
  final String strength;
  final String form;
  final String pack;

  /// Действующее вещество (МНН). Препараты с одинаковым МНН — аналоги.
  final String inn;

  /// true — отпускается только по рецепту.
  final bool rx;
  final List<String> aliases;

  /// Раздел каталога: «Аллергия», «Антибиотики»…
  final String category;

  /// «Парацетамол 500 мг»
  String get title => strength.isEmpty ? name : '$name $strength';

  /// «Таблетки, 10 шт.»
  String get subtitle => '$form, $pack';

  factory Drug.fromJson(Map<String, dynamic> json) => Drug(
        id: json['id'] as String,
        name: json['name'] as String,
        strength: (json['strength'] as String?) ?? '',
        form: json['form'] as String,
        pack: json['pack'] as String,
        inn: json['inn'] as String,
        rx: json['rx'] as bool,
        aliases: ((json['aliases'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(),
        category: (json['category'] as String?) ?? '',
      );
}

class Pharmacy {
  const Pharmacy({
    required this.id,
    required this.chain,
    required this.address,
    required this.lat,
    required this.lng,
    this.opensAt,
    this.closesAt,
    this.phone,
  });

  final String id;
  final String chain;
  final String address;
  final double lat;
  final double lng;

  /// «08:00». null у обоих полей — аптека круглосуточная.
  final String? opensAt;
  final String? closesAt;
  final String? phone;

  bool get isAroundTheClock => opensAt == null || closesAt == null;

  factory Pharmacy.fromJson(Map<String, dynamic> json) => Pharmacy(
        id: json['id'] as String,
        chain: json['chain'] as String,
        address: json['address'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        opensAt: json['opensAt'] as String?,
        closesAt: json['closesAt'] as String?,
        phone: json['phone'] as String?,
      );
}

/// Наличие препарата в конкретной аптеке и его цена (в сомах).
class Offer {
  const Offer({
    required this.pharmacyId,
    required this.drugId,
    required this.price,
  });

  final String pharmacyId;
  final String drugId;
  final int price;

  factory Offer.fromJson(Map<String, dynamic> json) => Offer(
        pharmacyId: json['pharmacyId'] as String,
        drugId: json['drugId'] as String,
        price: (json['price'] as num).toInt(),
      );
}

/// Всё, что приложение знает о лекарствах и аптеках.
class Catalog {
  Catalog({
    required this.drugs,
    required this.pharmacies,
    required this.offers,
    required this.isDemo,
  })  : _drugById = {for (final d in drugs) d.id: d},
        _pharmacyById = {for (final p in pharmacies) p.id: p};

  final List<Drug> drugs;
  final List<Pharmacy> pharmacies;
  final List<Offer> offers;

  /// true — данные демонстрационные, в интерфейсе показываем плашку.
  final bool isDemo;

  final Map<String, Drug> _drugById;
  final Map<String, Pharmacy> _pharmacyById;

  Drug? drug(String id) => _drugById[id];
  Pharmacy? pharmacy(String id) => _pharmacyById[id];

  List<Offer> offersForDrug(String drugId) =>
      offers.where((o) => o.drugId == drugId).toList();

  List<Offer> offersForPharmacy(String pharmacyId) =>
      offers.where((o) => o.pharmacyId == pharmacyId).toList();

  /// Разделы каталога в порядке первого появления.
  List<String> get categories => [
        for (final c in {for (final d in drugs) d.category})
          if (c.isNotEmpty) c,
      ];

  List<Drug> drugsInCategory(String category) =>
      drugs.where((d) => d.category == category).toList();

  /// Минимальная цена препарата или null, если нигде нет.
  int? minPrice(String drugId) {
    int? best;
    for (final o in offers) {
      if (o.drugId == drugId && (best == null || o.price < best)) best = o.price;
    }
    return best;
  }

  /// Другие препараты с тем же действующим веществом.
  List<Drug> analogs(Drug drug) =>
      drugs.where((d) => d.id != drug.id && d.inn == drug.inn).toList();

  factory Catalog.fromJson(Map<String, dynamic> json) => Catalog(
        drugs: (json['drugs'] as List)
            .map((e) => Drug.fromJson(e as Map<String, dynamic>))
            .toList(),
        pharmacies: (json['pharmacies'] as List)
            .map((e) => Pharmacy.fromJson(e as Map<String, dynamic>))
            .toList(),
        offers: (json['offers'] as List)
            .map((e) => Offer.fromJson(e as Map<String, dynamic>))
            .toList(),
        isDemo: ((json['meta'] as Map?)?['demo'] as bool?) ?? false,
      );
}
