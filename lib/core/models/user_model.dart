import 'base_entity.dart';

class UserModel implements BaseEntity {
  @override
  final String id;
  final String username;
  final String? email;
  final String? photoUrl;
  final double balanceIdr;
  final String? whatsappNumber;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.username,
    this.email,
    this.photoUrl,
    this.balanceIdr = 0,
    this.whatsappNumber,
    this.createdAt,
  });

  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? photoUrl,
    double? balanceIdr,
    String? whatsappNumber,
    bool resetWhatsappNumber = false,
    DateTime? createdAt,
  }) =>
      UserModel(
        id: id ?? this.id,
        username: username ?? this.username,
        email: email ?? this.email,
        photoUrl: photoUrl ?? this.photoUrl,
        balanceIdr: balanceIdr ?? this.balanceIdr,
        whatsappNumber: resetWhatsappNumber
            ? null
            : (whatsappNumber ?? this.whatsappNumber),
        createdAt: createdAt ?? this.createdAt,
      );

  factory UserModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreated;
    final rawCreated = json['created_at'];
    if (rawCreated is int) {
      parsedCreated = DateTime.fromMillisecondsSinceEpoch(rawCreated);
    } else if (rawCreated is String) {
      parsedCreated = DateTime.tryParse(rawCreated);
    }

    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String?,
      photoUrl: (json['photo_url'] ?? json['photo_path']) as String?,
      balanceIdr: (json['balance_idr'] as num?)?.toDouble() ?? 0,
      whatsappNumber: json['whatsapp_number'] as String?,
      createdAt: parsedCreated,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'photo_url': photoUrl,
        'photo_path': photoUrl,
        'balance_idr': balanceIdr,
        'whatsapp_number': whatsappNumber,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  factory UserModel.fromMap(Map<String, dynamic> map) =>
      UserModel.fromJson(map);

  @override
  Map<String, dynamic> toMap() => toJson();
}
