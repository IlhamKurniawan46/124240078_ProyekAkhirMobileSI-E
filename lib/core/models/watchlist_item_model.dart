import 'base_entity.dart';
import 'card_model.dart';

class WatchlistItemModel implements BaseEntity {
  final String cardId;
  final String userId;
  final double? alertPriceIdr;
  final DateTime? addedAt;
  final CardModel? card;

  const WatchlistItemModel({
    required this.cardId,
    required this.userId,
    this.alertPriceIdr,
    this.addedAt,
    this.card,
  });

  @override
  String get id => '${userId}_$cardId';

  factory WatchlistItemModel.fromMap(
    Map<String, dynamic> map, {
    CardModel? card,
  }) {
    final rawCard = map['card'];
    final cardObj = card ??
        (rawCard is Map
            ? CardModel.fromJson(Map<String, dynamic>.from(rawCard))
            : null);

    DateTime? parsedAddedAt;
    if (map['added_at'] != null) {
      if (map['added_at'] is int) {
        parsedAddedAt =
            DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int);
      } else if (map['added_at'] is String) {
        parsedAddedAt = DateTime.tryParse(map['added_at'] as String);
      }
    }

    return WatchlistItemModel(
      cardId: (map['card_id'] ?? map['id'] ?? '') as String,
      userId: (map['user_id'] as String?) ?? '',
      alertPriceIdr: (map['alert_price_idr'] as num?)?.toDouble(),
      addedAt: parsedAddedAt,
      card: cardObj,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'card_id': cardId,
        'user_id': userId,
        'alert_price_idr': alertPriceIdr,
        'added_at': (addedAt ?? DateTime.now()).millisecondsSinceEpoch,
      };

  factory WatchlistItemModel.fromJson(
    Map<String, dynamic> json, {
    String? userId,
  }) {
    final map = Map<String, dynamic>.from(json);
    if (userId != null) {
      map['user_id'] = userId;
    }
    return WatchlistItemModel.fromMap(map);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'card_id': cardId,
        'user_id': userId,
        'alert_price_idr': alertPriceIdr,
        'added_at': addedAt?.toIso8601String(),
        if (card != null) 'card': card!.toJson(),
      };

  WatchlistItemModel copyWith({
    String? cardId,
    String? userId,
    double? alertPriceIdr,
    DateTime? addedAt,
    CardModel? card,
  }) =>
      WatchlistItemModel(
        cardId: cardId ?? this.cardId,
        userId: userId ?? this.userId,
        alertPriceIdr: alertPriceIdr ?? this.alertPriceIdr,
        addedAt: addedAt ?? this.addedAt,
        card: card ?? this.card,
      );
}
