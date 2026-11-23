abstract class BaseEntity {
  /// Identitas unik entitas (digunakan sebagai primary key pada Hive Box).
  String get id;

  /// Serialisasi objek model menjadi `Map<String, dynamic>` secara manual
  /// tanpa code generation (`build_runner`).
  Map<String, dynamic> toMap();
}
