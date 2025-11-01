// lib/views/edit_spost_view.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/social_models.dart';
import '../models/social_user.dart';
import '../services/social_service.dart';
import '../services/social_repository.dart';

class EditSPostView extends StatelessWidget {
  /// Use this when navigating:
  /// EditSPostView(postId: post.id, repository: repository, initialPost: post)
  final String postId;
  final SocialRepository repository;
  final Post? initialPost;

  const EditSPostView({
    super.key,
    required this.postId,
    required this.repository,
    this.initialPost,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<_EditSPostVM>(
      create: (_) => _EditSPostVM(
        service: SocialService(),
        initialPost: initialPost,
        postId: postId,
      )..init(),
      child: const _EditSPostBody(),
    );
  }
}

class _EditSPostBody extends StatefulWidget {
  const _EditSPostBody();

  @override
  State<_EditSPostBody> createState() => _EditSPostBodyState();
}

class _EditSPostBodyState extends State<_EditSPostBody> {
  final _picker = ImagePicker();

  // Mention overlay
  final _mentionLink = LayerLink();
  OverlayEntry? _mentionOverlay;
  List<SocialUser> _mentionSuggestions = const [];

  List<String> _hashtagSuggestions = const [];

  @override
  void dispose() {
    _mentionOverlay?.remove();
    super.dispose();
  }

  Future<void> _pickImages(_EditSPostVM vm) async {
    final picks = await _picker.pickMultiImage(imageQuality: 85);
    if (picks.isEmpty) return;
    vm.addLocalImages(picks.map((e) => e.path).toList());
  }

  void _onChanged(_EditSPostVM vm, String t) async {
    // Mentions
    final at = t.lastIndexOf('@');
    if (at >= 0) {
      final q = t.substring(at + 1).split(RegExp(r'\s')).first;
      if (q.isNotEmpty) {
        _mentionSuggestions = await vm.fetchMentionSuggestions(q);
        _showMentions(vm);
      } else {
        _hideMentions();
      }
    } else {
      _hideMentions();
    }

    // Hashtags
    final hash = t.lastIndexOf('#');
    if (hash >= 0) {
      final q = t.substring(hash + 1).split(RegExp(r'\s')).first;
      if (q.isNotEmpty) {
        _hashtagSuggestions = await vm.fetchHashtagSuggestions(q);
        setState(() {});
      } else {
        if (_hashtagSuggestions.isNotEmpty) {
          setState(() => _hashtagSuggestions = const []);
        }
      }
    } else {
      if (_hashtagSuggestions.isNotEmpty) {
        setState(() => _hashtagSuggestions = const []);
      }
    }
  }

  void _showMentions(_EditSPostVM vm) {
    _mentionOverlay?.remove();
    if (_mentionSuggestions.isEmpty) return;
    final overlay = Overlay.of(context);
    _mentionOverlay = OverlayEntry(
      builder: (_) => Positioned(
        width: MediaQuery.of(context).size.width - 24,
        child: CompositedTransformFollower(
          link: _mentionLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 70),
          child: Material(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _mentionSuggestions.length,
                itemBuilder: (_, i) {
                  final u = _mentionSuggestions[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      backgroundImage: (u.avatarUrl != null && u.avatarUrl!.isNotEmpty)
                          ? NetworkImage(u.avatarUrl!)
                          : null,
                      child: (u.avatarUrl == null || u.avatarUrl!.isEmpty)
                          ? Icon(Icons.person, color: Colors.blue.shade700)
                          : null,
                    ),
                    title: Text(u.displayName),
                    onTap: () {
                      final ctrl = vm.textCtrl;
                      final text = ctrl.text;
                      final at = text.lastIndexOf('@');
                      final before = text.substring(0, at + 1);
                      final after = text.substring(at + 1);
                      final rest = after.contains(' ')
                          ? after.substring(after.indexOf(' '))
                          : '';
                      ctrl.text = '$before${u.displayName}$rest ';
                      ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
                      _hideMentions();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_mentionOverlay!);
  }

  void _hideMentions() {
    _mentionOverlay?.remove();
    _mentionOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<_EditSPostVM>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Post'),
        actions: [
          TextButton(
            onPressed: vm.canSubmit && !vm.isSaving
                ? () async {
                    final ok = await vm.save();
                    if (ok && context.mounted) Navigator.pop(context, true);
                  }
                : null,
            child: vm.isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.translucent,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: CompositedTransformTarget(
                            link: _mentionLink,
                            child: TextField(
                              controller: vm.textCtrl,
                              minLines: 5,
                              maxLines: null,
                              decoration: const InputDecoration(
                                hintText: 'Update your content…',
                                border: InputBorder.none,
                              ),
                              onChanged: (t) => _onChanged(vm, t),
                            ),
                          ),
                        ),
                      ),

                      // Hashtag suggestions
                      if (_hashtagSuggestions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: -6,
                          children: _hashtagSuggestions.map((tag) {
                            return ActionChip(
                              label: Text('#$tag'),
                              onPressed: () {
                                final ctrl = vm.textCtrl;
                                final text = ctrl.text;
                                final hash = text.lastIndexOf('#');
                                final before = text.substring(0, hash + 1);
                                final after = text.substring(hash + 1);
                                final rest = after.contains(' ') ? after.substring(after.indexOf(' ')) : '';
                                ctrl.text = '$before$tag$rest ';
                                ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
                                setState(() => _hashtagSuggestions = const []);
                              },
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 10),

                      if (vm.images.isNotEmpty) _ImagesGrid(
                        paths: vm.images,
                        onRemove: (i) => vm.removeImageAt(i),
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          _ToolButton(
                            icon: Icons.photo_outlined,
                            label: 'Gallery',
                            onTap: () => _pickImages(vm),
                          ),
                          const Spacer(),
                          Text('${vm.textCtrl.text.length}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ToolButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ImagesGrid extends StatelessWidget {
  final List<String> paths;
  final void Function(int index) onRemove;
  const _ImagesGrid({required this.paths, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    final show = paths.take(4).toList();
    final total = paths.length;
    final extra = total - show.length;

    Widget tile(int i, {BorderRadius? br}) {
      final child = ClipRRect(
        borderRadius: br ?? BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(show[i]), fit: BoxFit.cover),
            Positioned(
              top: 6,
              right: 6,
              child: InkWell(
                onTap: () => onRemove(i),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
            if (extra > 0 && i == 3)
              Container(
                alignment: Alignment.center,
                color: Colors.black45,
                child: Text(
                  '+$extra',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      );
      return child;
    }

    if (show.length == 1) {
      return AspectRatio(aspectRatio: 4 / 3, child: tile(0));
    }
    if (show.length == 2) {
      return Row(
        children: [
          Expanded(child: AspectRatio(aspectRatio: 1, child: tile(0))),
          const SizedBox(width: gap),
          Expanded(child: AspectRatio(aspectRatio: 1, child: tile(1))),
        ],
      );
    }
    if (show.length == 3) {
      return Row(
        children: [
          Expanded(flex: 2, child: AspectRatio(aspectRatio: 3 / 2, child: tile(0))),
          const SizedBox(width: gap),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(child: tile(1)),
                const SizedBox(height: gap),
                Expanded(child: tile(2)),
              ],
            ),
          ),
        ],
      );
    }
    // 4+
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: AspectRatio(aspectRatio: 1, child: tile(0))),
            const SizedBox(width: gap),
            Expanded(child: AspectRatio(aspectRatio: 1, child: tile(1))),
          ],
        ),
        const SizedBox(height: gap),
        Row(
          children: [
            Expanded(child: AspectRatio(aspectRatio: 1, child: tile(2))),
            const SizedBox(width: gap),
            Expanded(child: AspectRatio(aspectRatio: 1, child: tile(3))),
          ],
        ),
      ],
    );
  }
}

/// ---------------------------
/// ViewModel (internal)
/// ---------------------------
class _EditSPostVM extends ChangeNotifier {
  final SocialService service;
  final Post? initialPost;
  final String? postId;

  final textCtrl = TextEditingController();
  final _supa = Supabase.instance.client;

  bool isLoading = true;
  bool isSaving = false;

  List<String> images = [];
  Post? _post;

  _EditSPostVM({
    required this.service,
    required this.initialPost,
    required this.postId,
  });

  bool get canSubmit => textCtrl.text.trim().isNotEmpty || images.isNotEmpty;

  Future<void> init() async {
    try {
      isLoading = true;
      notifyListeners();

      if (initialPost != null) {
        _post = initialPost!;
      } else {
        // Fetch post by ID (non-null assertion)
        final id = postId!;
        final rows = await Supabase.instance.client
            .from('posts')
            .select('id, author_id, content, image_paths, created_at')
            .eq('id', id)
            .single();

        _post = Post(
          id: rows['id'] as String,
          authorId: rows['author_id'] as String,
          content: (rows['content'] ?? '').toString(),
          imagePaths: (rows['image_paths'] as List?)?.cast<String>() ?? const <String>[],
          createdAt: DateTime.parse(rows['created_at'] as String),
        );
      }

      textCtrl.text = _post!.content;
      images = List.from(_post!.imagePaths);

      // Only author can edit
      final me = _supa.auth.currentUser?.id;
      if (me == null || me != _post!.authorId) {
        throw 'You do not have permission to edit this post.';
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void addLocalImages(List<String> paths) {
    images.addAll(paths);
    notifyListeners();
  }

  void removeImageAt(int i) {
    if (i < 0 || i >= images.length) return;
    images.removeAt(i);
    notifyListeners();
  }

  Future<List<SocialUser>> fetchMentionSuggestions(String q) async {
    final me = _supa.auth.currentUser?.id;
    if (me == null) return [];
    final friendIds = await service.listFriendIds(me);
    final friends = await service.getUsersByIds(friendIds);
    final lower = q.toLowerCase();
    return friends.where((u) => u.displayName.toLowerCase().contains(lower)).take(10).toList();
  }

  Future<List<String>> fetchHashtagSuggestions(String q) async {
    final tags = await service.getTopHashtags(limit: 15);
    final lower = q.toLowerCase();
    return tags.where((t) => t.toLowerCase().startsWith(lower)).take(10).toList();
  }

  Future<bool> save() async {
    final me = _supa.auth.currentUser?.id;
    if (me == null || _post == null) return false;

    isSaving = true;
    notifyListeners();

    try {
      final updated = Post(
        id: _post!.id,
        authorId: _post!.authorId,
        content: textCtrl.text.trim(),
        imagePaths: List.from(images),
        createdAt: _post!.createdAt,
      );

      await service.updatePost(updated);
      return true;
    } catch (e) {
      debugPrint('Edit save failed: $e');
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    textCtrl.dispose();
    super.dispose();
  }
}
