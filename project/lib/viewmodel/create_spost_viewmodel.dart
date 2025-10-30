// lib/viewmodel/create_spost_viewmodel.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/social_user.dart';
import '../services/social_service.dart';
import '../services/social_repository.dart';

class CreateSPostViewModel extends ChangeNotifier {
  final SocialService service;
  final SocialRepository repository;

  CreateSPostViewModel({
    required this.service,
    required this.repository,
  });

  // UI state
  final TextEditingController contentCtrl = TextEditingController();
  bool isSubmitting = false;
  bool isLoading = false;

  // Picked images (cached as bytes to upload)
  final List<_PickedImage> _images = [];
  List<_PickedImage> get images => List.unmodifiable(_images);

  // Friends cache for @mentions
  final Map<String, SocialUser> _friends = {}; // id -> user

  // Hashtags: (tag, lastUsed, count)
  List<({String tag, DateTime lastUsed, int count})> _hashtags = [];

  String get meId => Supabase.instance.client.auth.currentUser?.id ?? '';

  /* ========================
   * Lifecycle
   * ======================== */
  Future<void> init() async {
    isLoading = true;
    notifyListeners();
    try {
      // Load friends (accepted friendships)
      final ids = await repository.listFriendIds(meId);
      final users = await repository.getUsersByIds(ids);
      _friends
        ..clear()
        ..addEntries(users.map((u) => MapEntry(u.id, u)));

      // Prefetch hashtags (most current first, then most used)
      final supa = Supabase.instance.client;
      final rows = await supa
          .from('hashtags')
          .select('name, usage_count, last_used_at')
          .order('last_used_at', ascending: false)
          .order('usage_count', ascending: false)
          .limit(200);

      final list = <({String tag, DateTime lastUsed, int count})>[];
      for (final r in (rows as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        final name = (m['name'] as String).trim();
        final count = (m['usage_count'] as int?) ?? 0;
        final luRaw = m['last_used_at'];
        final lastUsed = (luRaw is String)
            ? DateTime.tryParse(luRaw) ?? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.fromMillisecondsSinceEpoch(0);
        list.add((tag: name, lastUsed: lastUsed, count: count));
      }
      _hashtags = list;
    } catch (_) {
      // fail-soft
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /* ========================
   * Images
   * ======================== */
  Future<void> addImagePaths(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        final ext = _normalizeExt(p.extension(path));
        _images.add(_PickedImage(bytes: bytes, ext: ext, localPath: path));
      } catch (_) {
        // ignore
      }
    }
    notifyListeners();
  }

  void removeImageAt(int index) {
    if (index < 0 || index >= _images.length) return;
    _images.removeAt(index);
    notifyListeners();
  }

  void reorderImages(int from, int to) {
    if (from == to) return;
    if (from < 0 || to < 0) return;
    if (from >= _images.length || to >= _images.length) return;
    final tmp = _images[from];
    _images[from] = _images[to];
    _images[to] = tmp;
    notifyListeners();
  }

  /* ========================
   * Mentions & Hashtags
   * ======================== */
  List<String> hashtagSuggestions(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty || _hashtags.isEmpty) return const <String>[];
    final filtered = _hashtags
        .where((h) => h.tag.toLowerCase().startsWith(q))
        .toList()
      ..sort((a, b) {
        final timeCmp = b.lastUsed.compareTo(a.lastUsed);
        if (timeCmp != 0) return timeCmp; // newer first
        return b.count.compareTo(a.count); // more used first
      });
    return filtered.take(10).map((e) => e.tag).toList();
  }

  Future<List<SocialUser>> mentionSuggestions(String query) async {
    final q = query.toLowerCase();
    return _friends.values
        .where((u) => u.displayName.toLowerCase().contains(q))
        .take(10)
        .toList();
  }

  List<String> extractMentionNames(String text) {
    final regex = RegExp(r'@([A-Za-z0-9_ğüşöçıİĞÜŞÖÇ.]+)');
    return [for (final m in regex.allMatches(text)) m.group(1)!];
  }

  bool canMentionAllNames(Iterable<String> names) {
    final friendNames = _friends.values.map((u) => u.displayName).toSet();
    for (final n in names) {
      if (!friendNames.contains(n)) return false;
    }
    return true;
  }

  /* ========================
   * Submit
   * ======================== */
  bool get canSubmit =>
      contentCtrl.text.trim().isNotEmpty || _images.isNotEmpty;

  /// Creates the post via SocialService (signature:
  /// createPost({required authorId, required content, required imagePaths}))
  /// Returns created postId on success.
  Future<String?> submit() async {
    if (!canSubmit || isSubmitting) return null;

    // (Optional) Validate mentions limited to friends
    final names = extractMentionNames(contentCtrl.text);
    if (!canMentionAllNames(names)) {
      // Caller/UI can show a snackbar; we just prevent submit
      return null;
    }

    isSubmitting = true;
    notifyListeners();
    try {
      // Upload images to Supabase Storage, get public URLs
      final urls = await _uploadImagesAndGetUrls();

      // Create post through your SocialService API (matches your signature)
      final post = await service.createPost(
        authorId: meId,
        content: contentCtrl.text.trim(),
        imagePaths: urls,
      );

      // Clear composer state
      contentCtrl.clear();
      _images.clear();
      notifyListeners();

      return post.id; // convert Post -> String? for caller
    } catch (e) {
      rethrow;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  /* ========================
   * Helpers
   * ======================== */
  Future<List<String>> _uploadImagesAndGetUrls() async {
    if (_images.isEmpty) return const <String>[];

    final supa = Supabase.instance.client;
    final bucket = supa.storage.from('social-images');
    final now = DateTime.now().millisecondsSinceEpoch;
    final urls = <String>[];

    for (var i = 0; i < _images.length; i++) {
      final img = _images[i];
      final ext = _normalizeExt(img.ext);
      // Use a path that does not require a postId first
      final path = 'posts/$meId/$now-$i.$ext';

      await bucket.uploadBinary(
        path,
        img.bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: _contentTypeFromExt(ext),
        ),
      );
      final pub = bucket.getPublicUrl(path);
      urls.add(pub);
    }

    return urls;
    }

  String _normalizeExt(String ext) {
    final e = ext.toLowerCase().replaceAll('.', '');
    const allow = {'jpg', 'jpeg', 'png', 'webp', 'heic'};
    return allow.contains(e) ? e : 'jpg';
  }

  String _contentTypeFromExt(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  void dispose() {
    contentCtrl.dispose();
    super.dispose();
  }
}

/* ========================
 * Private model
 * ======================== */

class _PickedImage {
  final Uint8List bytes;
  final String ext;
  final String? localPath;

  _PickedImage({
    required this.bytes,
    required this.ext,
    this.localPath,
  });
}
