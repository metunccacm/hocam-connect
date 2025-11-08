// lib/view/create_spost_view.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/social_user.dart';
import '../services/social_repository.dart';
import '../services/social_service.dart';
import '../viewmodel/create_spost_viewmodel.dart';

class CreateSPostView extends StatelessWidget {
  final SocialRepository repository;

  const CreateSPostView({
    super.key,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CreateSPostViewModel>(
      create: (_) => CreateSPostViewModel(
        service: SocialService(),
        repository: repository,
      )..init(),
      child: const _CreateSPostBody(),
    );
  }
}

class _CreateSPostBody extends StatefulWidget {
  const _CreateSPostBody();

  @override
  State<_CreateSPostBody> createState() => _CreateSPostBodyState();
}

class _CreateSPostBodyState extends State<_CreateSPostBody> {
  final ImagePicker _picker = ImagePicker();
  final FocusNode _focus = FocusNode();

  // Local-only list for previews/reorder. VM handles bytes/upload.
  final List<String> _localImagePaths = [];

  // Mention / hashtag helpers
  final LayerLink _mentionLink = LayerLink();
  OverlayEntry? _mentionOverlay;
  List<SocialUser> _mentionSuggestions = const [];

  List<String> _hashtagSuggestions = const [];
  int _lastTextLength = 0;

  @override
  void dispose() {
    _hideMentionOverlay();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 85);
    if (images.isEmpty) return;
    final paths = images.map((x) => x.path).toList();
    setState(() {
      _localImagePaths.addAll(paths);
    });
    // Push to VM for upload later
    await context.read<CreateSPostViewModel>().addImagePaths(paths);
  }

  void _removeImageAt(int index) {
    if (index < 0 || index >= _localImagePaths.length) return;
    setState(() {
      _localImagePaths.removeAt(index);
    });
    context.read<CreateSPostViewModel>().removeImageAt(index);
  }

  void _reorderImages(int from, int to) {
    if (from == to) return;
    if (from < 0 || to < 0) return;
    if (from >= _localImagePaths.length || to >= _localImagePaths.length) return;
    setState(() {
      final tmp = _localImagePaths[from];
      _localImagePaths[from] = _localImagePaths[to];
      _localImagePaths[to] = tmp;
    });
    context.read<CreateSPostViewModel>().reorderImages(from, to);
  }

  void _onTextChanged(String t) async {
    final vm = context.read<CreateSPostViewModel>();

    // Mentions
    final at = t.lastIndexOf('@');
    if (at >= 0 && at < t.length - 1) {
      final q = t.substring(at + 1).split(RegExp(r'\s')).first;
      if (q.isNotEmpty) {
        _mentionSuggestions = await vm.mentionSuggestions(q);
        _showMentionOverlay();
      } else {
        _hideMentionOverlay();
      }
    } else {
      _hideMentionOverlay();
    }

    // Hashtags (most current first, then most used)
    final hash = t.lastIndexOf('#');
    if (hash >= 0 && hash < t.length - 1) {
      final q = t.substring(hash + 1).split(RegExp(r'\s')).first;
      if (q.isNotEmpty) {
        setState(() {
          _hashtagSuggestions = vm.hashtagSuggestions(q);
        });
      } else {
        setState(() {
          _hashtagSuggestions = const [];
        });
      }
    } else if (_lastTextLength > t.length) {
      // if user deleted the # part, clear suggestions
      setState(() {
        _hashtagSuggestions = const [];
      });
    }

    _lastTextLength = t.length;
  }

  void _insertHashtag(String tag) {
    final vm = context.read<CreateSPostViewModel>();
    final ctrl = vm.contentCtrl;
    final text = ctrl.text;
    final hash = text.lastIndexOf('#');
    if (hash < 0) return;
    final before = text.substring(0, hash + 1);
    final after = text.substring(hash + 1);
    final rest = after.contains(' ') ? after.substring(after.indexOf(' ')) : '';
    ctrl.text = '$before$tag$rest ';
    ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
    setState(() {
      _hashtagSuggestions = const [];
    });
  }

  void _insertMention(SocialUser u) {
    final vm = context.read<CreateSPostViewModel>();
    final ctrl = vm.contentCtrl;
    final text = ctrl.text;
    final at = text.lastIndexOf('@');
    if (at < 0) return;
    final before = text.substring(0, at + 1);
    final after = text.substring(at + 1);
    final rest = after.contains(' ') ? after.substring(after.indexOf(' ')) : '';
    ctrl.text = '$before${u.displayName}$rest ';
    ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
    _hideMentionOverlay();
  }

  void _showMentionOverlay() {
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
            borderRadius: BorderRadius.circular(8),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final u in _mentionSuggestions)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(u.displayName),
                    onTap: () => _insertMention(u),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(_mentionOverlay!);
  }

  void _hideMentionOverlay() {
    _mentionOverlay?.remove();
    _mentionOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CreateSPostViewModel>();
    final canSubmit = vm.canSubmit && !vm.isSubmitting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: canSubmit
                ? () async {
                    // Validate mentions against friends
                    final names = vm.extractMentionNames(vm.contentCtrl.text);
                    if (!vm.canMentionAllNames(names)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('You can only mention your friends.')),
                      );
                      return;
                    }
                    final postId = await vm.submit();
                    if (postId != null && context.mounted) {
                      Navigator.pop(context, postId);
                    }
                  }
                : null,
            child: vm.isSubmitting
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Post'),
          ),
        ],
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CompositedTransformTarget(
                      link: _mentionLink,
                      child: TextField(
                        controller: vm.contentCtrl,
                        focusNode: _focus,
                        minLines: 5,
                        maxLines: null,
                        decoration: const InputDecoration(
                          hintText: "What's happening?",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: _onTextChanged,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (_localImagePaths.isNotEmpty) _ImagesGridLocal(
                      paths: _localImagePaths,
                      onRemove: _removeImageAt,
                      onReorder: _reorderImages,
                    ),

                    const SizedBox(height: 10),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(Icons.photo_outlined),
                          label: const Text('Gallery'),
                        ),
                      ],
                    ),

                    if (_hashtagSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in _hashtagSuggestions)
                            ActionChip(
                              label: Text('#$tag'),
                              onPressed: () => _insertHashtag(tag),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

/* =========================
 * Local Images Grid (preview)
 * ========================= */
class _ImagesGridLocal extends StatelessWidget {
  final List<String> paths;
  final void Function(int index) onRemove;
  final void Function(int from, int to) onReorder;

  const _ImagesGridLocal({
    required this.paths,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();

    Widget buildThumb(int index) {
      final file = File(paths[index]);
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(file, fit: BoxFit.cover),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: InkWell(
              onTap: () => onRemove(index),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    return ReorderableWrap(
      spacing: 8,
      runSpacing: 8,
      onReorder: onReorder,
      children: [
        for (int i = 0; i < paths.length; i++)
          SizedBox(
            key: ValueKey(paths[i]),
            width: 110,
            height: 110,
            child: buildThumb(i),
          ),
      ],
    );
  }
}

/* =========================
 * ReorderableWrap (minimal)
 * ========================= */
class ReorderableWrap extends StatefulWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final void Function(int from, int to) onReorder;

  const ReorderableWrap({
    super.key,
    required this.children,
    required this.onReorder,
    this.spacing = 8,
    this.runSpacing = 8,
  });

  @override
  State<ReorderableWrap> createState() => _ReorderableWrapState();
}

class _ReorderableWrapState extends State<ReorderableWrap> {
  @override
  Widget build(BuildContext context) {
    // Very lightweight: uses Wrap + LongPressDraggable + DragTarget.
    final items = <Widget>[];
    for (var i = 0; i < widget.children.length; i++) {
      final child = widget.children[i];
      items.add(
        LongPressDraggable<int>(
          data: i,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(opacity: 0.8, child: child),
          ),
          childWhenDragging: Opacity(opacity: 0.4, child: child),
          child: DragTarget<int>(
            builder: (context, candidate, rejected) => child,
            onAcceptWithDetails: (details) => widget.onReorder(details.data, i),
          ),
        ),
      );
    }
    return Wrap(
      spacing: widget.spacing,
      runSpacing: widget.runSpacing,
      children: items,
    );
  }
}
