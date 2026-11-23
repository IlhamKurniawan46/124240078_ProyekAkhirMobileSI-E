import 'base_entity.dart';

class ReleaseEventModel implements BaseEntity {
  @override
  final String id;
  final String title;
  final String eventType; // 'set_release' | 'tournament'
  final DateTime eventDate; // Timestamp UTC
  final String? description;
  final String? setId;
  final String? location;

  const ReleaseEventModel({
    required this.id,
    required this.title,
    required this.eventType,
    required this.eventDate,
    this.description,
    this.setId,
    this.location,
  });

  bool get isSetRelease => eventType == 'set_release';
  bool get isTournament => eventType == 'tournament';

  factory ReleaseEventModel.fromJson(Map<String, dynamic> json) {
    return ReleaseEventModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Event Pokémon',
      eventType: json['event_type'] as String? ?? 'set_release',
      eventDate: json['event_date'] != null
          ? (json['event_date'] is int
              ? DateTime.fromMillisecondsSinceEpoch(
                  json['event_date'] as int,
                  isUtc: true,
                )
              : DateTime.tryParse(json['event_date'].toString())?.toUtc() ??
                  DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      description: json['description'] as String?,
      setId: json['set_id'] as String?,
      location: json['location'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'event_type': eventType,
        'event_date': eventDate.toIso8601String(),
        'description': description,
        'set_id': setId,
        'location': location,
      };

  factory ReleaseEventModel.fromMap(Map<String, dynamic> map) =>
      ReleaseEventModel.fromJson(map);

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'event_type': eventType,
        'event_date': eventDate.millisecondsSinceEpoch,
        'description': description,
        'set_id': setId,
        'location': location,
      };

  /// Daftar jadwal event rilis set & turnamen resmi Pokémon TCG mendatang
  /// Digunakan sebagai seed awal di Hive
  static List<ReleaseEventModel> get defaultEvents {
    final now = DateTime.now().toUtc();
    return [
      ReleaseEventModel(
        id: 'event-battle-deck-30th',
        title: '30th Celebration Battle Deck (Espeon & Umbreon)',
        eventType: 'set_release',
        eventDate: now.add(const Duration(days: 5, hours: 4)),
        description:
            'Rilis produk spesial 30th Celebration Battle Deck. Jadwalkan pengingat agar tidak kehabisan pre-order.',
        setId: 'swsh7',
        location: 'Global (Pokémon Center & Toko Hobi Resmi)',
      ),
      ReleaseEventModel(
        id: 'event-holodex-cup',
        title: 'Turnamen Nasional HoloDex Nusantara Cup',
        eventType: 'tournament',
        eventDate: now.add(const Duration(days: 10, hours: 8)),
        description:
            'Turnamen komunitas kolektor & pemain Pokémon TCG Indonesia format Standard.',
        setId: 'sv05',
        location: 'Jakarta Convention Center & Online Discord',
      ),
      ReleaseEventModel(
        id: 'event-upc-30th',
        title: '30th Celebration Ultra-Premium Collection',
        eventType: 'set_release',
        eventDate: now.add(const Duration(days: 18, hours: 2)),
        description:
            'Koleksi Ultra-Premium dengan kartu promo holofoil eksklusif dan aksesoris turnamen.',
        setId: 'sv01',
        location: 'Global Launch',
      ),
    ];
  }
}
