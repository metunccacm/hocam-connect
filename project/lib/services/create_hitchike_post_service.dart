// lib/services/hitchhike_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class HitchikeService {
  final _supa = Supabase.instance.client;

  Future<void> createHitchikePost({
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

    // owner_id = the post owner (driver).
    final insert = {
      'owner_id': user.id,
      'from_location': fromLocation,
      'to_location': toLocation,
      'date_time': dateTime.toUtc().toIso8601String(), // store UTC
      'seats': seats,
      'fuel_shared': fuelShared,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    await _supa.from('hitchike_posts').insert(insert);
  }

  /// Optional: returns only non-expired rides
Future<List<Map<String, dynamic>>> fetchActivePosts() async {
  try {
    final rows = await _supa
        .from('hitchike_posts_view')
        .select(
          'id,owner_id,owner_name,owner_image_url:owner_image,'
          'from_location,to_location,date_time,seats,fuel_shared,created_at'
        )
        .order('date_time', ascending: true);
    return (rows as List).cast<Map<String, dynamic>>();
  } on PostgrestException catch (e) {
    // owner_image kolonu view’da yoksa dar bir seçimle tekrar dene
    if (e.message.contains('owner_image') || e.code == '42703' || e.code == 'PGRST100') {
      final rows = await _supa
          .from('hitchike_posts_view')
          .select(
            'id,owner_id,owner_name,'
            'from_location,to_location,date_time,seats,fuel_shared,created_at'
          )
          .order('date_time', ascending: true);
      return (rows as List).cast<Map<String, dynamic>>();
    }
    rethrow;
  }
}


  /// Optional client-side cleanup fallback (in case cron is delayed)
  Future<int> pruneExpired() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final res = await _supa
        .from('hitchike_posts')
        .delete()
        .lt('date_time', nowIso)
        .select(); // returns deleted rows
    return (res as List).length;
  }

  Future<void> deletePost(String id) async {
    await _supa.from('hitchike_posts').delete().eq('id', id);
  }
}

