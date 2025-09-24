// lib/viewmodel/hitchike_viewmodel.dart
import 'package:flutter/foundation.dart';
import '../models/hitchike_post.dart';
import '../services/create_hitchike_post_service.dart' show HitchhikeService;

class HitchikeViewModel extends ChangeNotifier {
  final HitchhikeService _svc = HitchhikeService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  final List<HitchikePost> _all = <HitchikePost>[];
  List<HitchikePost> _posts = <HitchikePost>[];
  List<HitchikePost> get posts => _posts;

  String _query = '';

  /// Refresh the list from the backend.
  Future<void> refreshPosts() async {
    _setLoading(true);
    try {
      // Optional safety: prune expired (DB cron should also handle this)
      try {
        await _svc.pruneExpired();
      } catch (_) {}

      final rows = await _svc.fetchActivePosts();
      final items = HitchikePost.listFrom(rows);

      _all
        ..clear()
        ..addAll(items);

      _applyFilter();
    } finally {
      _setLoading(false);
    }
  }

  /// Search by destination/owner (case-insensitive).
  void searchPosts(String q) {
    _query = q.trim().toLowerCase();
    _applyFilter();
  }

  Future<void> deletePost(String id) async {
    // Optimistic update
    final beforeAll = List<HitchikePost>.from(_all);
    final beforePosts = List<HitchikePost>.from(_posts);

    _all.removeWhere((e) => e.id == id);
    _applyFilter(notify: false);
    notifyListeners();

    try {
      await _svc.deletePost(id);
    } catch (_) {
      // rollback on failure
      _all
        ..clear()
        ..addAll(beforeAll);
      _posts = beforePosts;
      notifyListeners();
      rethrow;
    }
  }

  // ----------------- helpers -----------------

  void _applyFilter({bool notify = true}) {
    if (_query.isEmpty) {
      _posts = List<HitchikePost>.from(_all);
    } else {
      _posts = _all.where((p) {
        final text = p.searchableText; // fromLocation + toLocation + ownerName
        return text.contains(_query);
      }).toList();
    }

    // keep soonest rides first
    _posts.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (notify) notifyListeners();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }
}
