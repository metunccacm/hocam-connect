// lib/services/hitchhike_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class HitchhikeService {
  final _supa = Supabase.instance.client;

  Future<void> createHitchhikePost({
    required String fromLocation,
    required String toLocation,
    required DateTime dateTime,
    required int seats,
    required int fuelShared, // 0 or 1
  }) async {
    final user = _supa.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    // owner_id = the post owner (driver). We’ll resolve name via a join/view when reading.
    final insert = {
      'owner_id': user.id,
      'from_location': fromLocation,
      'to_location': toLocation,
      'date_time': dateTime.toUtc().toIso8601String(), // store UTC
      'seats': seats,
      'fuel_shared': fuelShared,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    await _supa.from('hitchhike_posts').insert(insert);
  }

  /// Optional: returns only non-expired rides
  Future<List<Map<String, dynamic>>> fetchActivePosts() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final rows = await _supa
        .from('hitchhike_posts_view') // recommend a view that already joins profiles
        .select()
        .gte('date_time', nowIso)
        .order('date_time', ascending: true);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Optional client-side cleanup fallback (in case cron is delayed)
  Future<int> pruneExpired() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final res = await _supa
        .from('hitchhike_posts')
        .delete()
        .lt('date_time', nowIso)
        .select(); // returns deleted rows
    return (res as List).length;
  }

  Future<void> deletePost(String id) async {
    await _supa.from('hitchhike_posts').delete().eq('id', id);
  }
}
