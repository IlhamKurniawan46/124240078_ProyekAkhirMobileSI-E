import 'base_entity.dart';

class CardModel implements BaseEntity {
  @override
  final String id;
  final String? localId;
  final String name;
  final String? setId;
  final String? setName;
  final String? rarity;
  final String? cardType;
  final String? imageUrl;
  final double? priceIdr;
  final double? priceUsd;
  final double? priceEur;
  final double? priceRefUsd;
  final String? priceSource;
  final bool hasPrice;
  final DateTime? seededAt;

  const CardModel({
    required this.id,
    this.localId,
    required this.name,
    this.setId,
    this.setName,
    this.rarity,
    this.cardType,
    this.imageUrl,
    this.priceIdr,
    this.priceUsd,
    this.priceEur,
    this.priceRefUsd,
    this.priceSource,
    this.hasPrice = false,
    this.seededAt,
  });

  /// URL gambar resolusi rendah untuk thumbnail grid / list (low.webp)
  String? get lowResImageUrl =>
      imageUrl != null && imageUrl!.isNotEmpty ? '$imageUrl/low.webp' : null;

  /// URL gambar resolusi tinggi untuk detail / efek holo (high.webp)
  String? get highResImageUrl =>
      imageUrl != null && imageUrl!.isNotEmpty ? '$imageUrl/high.webp' : null;

  /// Deserialisasi dari Map Hive atau JSON REST API
  factory CardModel.fromJson(Map<String, dynamic> json) {
    final rawHasPrice = json['has_price'];
    final parsedHasPrice = rawHasPrice is bool
        ? rawHasPrice
        : (rawHasPrice is num ? rawHasPrice != 0 : false);

    DateTime? parsedSeededAt;
    final rawSeeded = json['seeded_at'] ?? json['last_synced'];
    if (rawSeeded is int) {
      parsedSeededAt = DateTime.fromMillisecondsSinceEpoch(rawSeeded);
    } else if (rawSeeded is String) {
      parsedSeededAt = DateTime.tryParse(rawSeeded);
    }

    return CardModel(
      id: json['id']?.toString() ?? '',
      localId: json['local_id']?.toString(),
      name: json['name'] as String? ?? 'Unknown Card',
      setId: json['set_id'] as String?,
      setName: json['set_name'] as String?,
      rarity: json['rarity'] as String?,
      cardType: json['card_type'] as String? ?? json['type'] as String?,
      imageUrl: json['image_url'] as String?,
      priceIdr: (json['price_idr'] as num?)?.toDouble(),
      priceUsd: (json['price_usd'] as num?)?.toDouble(),
      priceEur: (json['price_eur'] as num?)?.toDouble(),
      priceRefUsd: (json['price_ref_usd'] as num?)?.toDouble(),
      priceSource: json['price_source'] as String?,
      hasPrice: parsedHasPrice,
      seededAt: parsedSeededAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'local_id': localId,
        'name': name,
        'set_id': setId,
        'set_name': setName,
        'rarity': rarity,
        'card_type': cardType,
        'type': cardType,
        'image_url': imageUrl,
        'price_idr': priceIdr,
        'price_usd': priceUsd,
        'price_eur': priceEur,
        'price_ref_usd': priceRefUsd,
        'price_source': priceSource,
        'has_price': hasPrice,
        'seeded_at': (seededAt ?? DateTime.now()).toIso8601String(),
      };

  factory CardModel.fromMap(Map<String, dynamic> map) =>
      CardModel.fromJson(map);

  @override
  Map<String, dynamic> toMap() => toJson();

  CardModel copyWith({
    String? id,
    String? localId,
    String? name,
    String? setId,
    String? setName,
    String? rarity,
    String? cardType,
    String? imageUrl,
    double? priceIdr,
    double? priceUsd,
    double? priceEur,
    double? priceRefUsd,
    String? priceSource,
    bool? hasPrice,
    DateTime? seededAt,
  }) =>
      CardModel(
        id: id ?? this.id,
        localId: localId ?? this.localId,
        name: name ?? this.name,
        setId: setId ?? this.setId,
        setName: setName ?? this.setName,
        rarity: rarity ?? this.rarity,
        cardType: cardType ?? this.cardType,
        imageUrl: imageUrl ?? this.imageUrl,
        priceIdr: priceIdr ?? this.priceIdr,
        priceUsd: priceUsd ?? this.priceUsd,
        priceEur: priceEur ?? this.priceEur,
        priceRefUsd: priceRefUsd ?? this.priceRefUsd,
        priceSource: priceSource ?? this.priceSource,
        hasPrice: hasPrice ?? this.hasPrice,
        seededAt: seededAt ?? this.seededAt,
      );
}
