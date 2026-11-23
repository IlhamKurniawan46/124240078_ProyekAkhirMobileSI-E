import 'base_entity.dart';
import 'card_model.dart';

/// Model item kartu di Koleksi Saya (koleksi fisik pengguna yang diperoleh dari pembelian).
class CollectionItemModel implements BaseEntity {
  final String cardId;
  final String userId;
  final String acquiredVia;
  final DateTime? acquiredAt;
  final CardModel? card;

  const CollectionItemModel({
    required this.cardId,
    required this.userId,
    this.acquiredVia = 'purchase',
    this.acquiredAt,
    this.card,
  });

  @override
  String get id => '${userId}_$cardId';

  factory CollectionItemModel.fromJson(
    Map<String, dynamic> json, {
    String? userId,
    CardModel? card,
  }) {
    final rawCard = json['card'];
    final cardObj = card ??
        (rawCard is Map
            ? CardModel.fromJson(Map<String, dynamic>.from(rawCard))
            : null);

    DateTime? parsedAcquiredAt;
    if (json['acquired_at'] != null) {
      if (json['acquired_at'] is int) {
        parsedAcquiredAt =
            DateTime.fromMillisecondsSinceEpoch(json['acquired_at'] as int);
      } else if (json['acquired_at'] is String) {
        parsedAcquiredAt = DateTime.tryParse(json['acquired_at'] as String);
      }
    }

    return CollectionItemModel(
      cardId: (json['card_id'] ?? json['id'] ?? '') as String,
      userId: userId ?? (json['user_id'] as String? ?? ''),
      acquiredVia: (json['acquired_via'] as String?) ?? 'purchase',
      acquiredAt: parsedAcquiredAt,
      card: cardObj,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'card_id': cardId,
        'user_id': userId,
        'acquired_via': acquiredVia,
        'acquired_at': acquiredAt?.toIso8601String(),
        if (card != null) 'card': card!.toJson(),
      };

  factory CollectionItemModel.fromMap(
    Map<String, dynamic> map, {
    CardModel? card,
  }) =>
      CollectionItemModel.fromJson(map, card: card);

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'card_id': cardId,
        'user_id': userId,
        'acquired_via': acquiredVia,
        'acquired_at':
            (acquiredAt ?? DateTime.now()).millisecondsSinceEpoch,
      };

  CollectionItemModel copyWith({
    String? cardId,
    String? userId,
    String? acquiredVia,
    DateTime? acquiredAt,
    CardModel? card,
  }) =>
      CollectionItemModel(
        cardId: cardId ?? this.cardId,
        userId: userId ?? this.userId,
        acquiredVia: acquiredVia ?? this.acquiredVia,
        acquiredAt: acquiredAt ?? this.acquiredAt,
        card: card ?? this.card,
      );
}
