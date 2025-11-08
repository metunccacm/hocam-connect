// lib/models/hitchike_post.dart

/// Hitchike post domain model.
/// Matches DB columns:
///   id, owner_id, from_location, to_location, date_time, seats, fuel_shared, created_at
/// Optionally (from a view/join): owner_name
class HitchikePost {
  final String id;
  final String ownerId;
  final String fromLocation;
  final String toLocation;
  final DateTime dateTime;
  final int seats;       // 1..5
  final int fuelShared;  // 0 or 1
  final String? ownerName;   // resolved via join/view
  final String? ownerImageUrl;
  final DateTime? createdAt; // optional

  const HitchikePost({
    required this.id,
    required this.ownerId,
    required this.fromLocation,
    required this.toLocation,
    required this.dateTime,
    required this.seats,
    required this.fuelShared,
    this.ownerName,
    this.ownerImageUrl,
    this.createdAt,
  });

  /// Convenience flags / helpers
  bool get fuelWillBeShared => fuelShared == 1;
  bool get isExpired => DateTime.now().isAfter(dateTime);

  HitchikePost copyWith({
    String? id,
    String? ownerId,
    String? fromLocation,
    String? toLocation,
    DateTime? dateTime,
    int? seats,
    int? fuelShared,
    String? ownerImageUrl,
    String? ownerName,
    DateTime? createdAt,
  }) {
    return HitchikePost(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      dateTime: dateTime ?? this.dateTime,
      seats: seats ?? this.seats,
      fuelShared: fuelShared ?? this.fuelShared,
      ownerName: ownerName ?? this.ownerName,
      ownerImageUrl: ownerImageUrl ?? this.ownerImageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Parse a Supabase value that may be String or DateTime.
  static DateTime _parseDt(dynamic v) {
    if (v == null) {
      throw ArgumentError('date_time is null');
    } else if (v is DateTime) {
      return v.toUtc();
    } else if (v is String) {
      return DateTime.parse(v).toUtc();
    } else {
      throw ArgumentError('Unsupported date type: ${v.runtimeType}');
    }
  }

  /// Build from a raw DB row (table or view).
  factory HitchikePost.fromMap(Map<String, dynamic> m) {
    return HitchikePost(
      id: (m['id'] ?? m['post_id']).toString(),
      ownerId: (m['owner_id'] ?? m['driver_id']).toString(),
      fromLocation: (m['from_location'] ?? m['from']).toString(),
      toLocation: (m['to_location'] ?? m['to']).toString(),
      dateTime: _parseDt(m['date_time']),
      seats: (m['seats'] as num).toInt(),
      fuelShared: (m['fuel_shared'] as num).toInt(),
      ownerName: m['owner_name'] as String?,
      ownerImageUrl: (m['owner_image_url'] ?? m['owner_image']) as String?,
      createdAt: m['created_at'] != null ? _parseDt(m['created_at']) : null,
    );
  }

  /// For inserts (service will add `owner_id` from auth).
  Map<String, dynamic> toDbInsert() => {
        'owner_id': ownerId,
        'from_location': fromLocation,
        'to_location': toLocation,
        'date_time': dateTime.toUtc().toIso8601String(),
        'seats': seats,
        'fuel_shared': fuelShared,
      };

  /// Full JSON (useful for caching / diagnostics)
  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'from_location': fromLocation,
        'to_location': toLocation,
        'date_time': dateTime.toUtc().toIso8601String(),
        'seats': seats,
        'fuel_shared': fuelShared,
        'owner_name': ownerName,
        'owner_image_url': ownerImageUrl,
        'created_at': createdAt?.toUtc().toIso8601String(),
      };

  static List<HitchikePost> listFrom(dynamic rows) {
    if (rows is! List) return const <HitchikePost>[];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(HitchikePost.fromMap)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  /// Handy lowercased text to filter in ViewModel search
  String get searchableText =>
      '$fromLocation $toLocation ${ownerName ?? ''}'.toLowerCase();

  @override
  String toString() =>
      'HitchikePost(id=$id, from=$fromLocation, to=$toLocation, at=$dateTime, seats=$seats, fuel=$fuelShared, owner=$ownerId, url=$ownerImageUrl)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HitchikePost && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
