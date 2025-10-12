import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';

import '../models/social_models.dart';
import '../models/social_user.dart';
import '../services/social_repository.dart';
import '../viewmodel/social_viewmodel.dart';

class SocialView extends StatelessWidget {
  const SocialView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SocialViewModel>(
      create: (_) => SocialViewModel(repository: LocalHiveSocialRepository())..load(),
      child: const _SocialViewBody(),
    );
  }
}

class _SocialViewBody extends StatelessWidget {
  const _SocialViewBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SocialViewModel>();
    return DefaultTabController(
      length: 2,
      initialIndex: vm.currentTab == SocialTab.explore ? 0 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sosyal'),
          bottom: TabBar(
            onTap: (i) => vm.switchTab(i == 0 ? SocialTab.explore : SocialTab.friends),
            tabs: const [
              Tab(text: 'Keşfet'),
              Tab(text: 'Arkadaşlar'),
            ],
          ),
        ),
        body: Column(
          children: [
            _Composer(vm: vm),
            const Divider(height: 1),
            Expanded(
              child: vm.isLoading
                  ? _FeedShimmer()
                  : ListView.separated(
                      itemCount: vm.feed.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.6),
                      itemBuilder: (context, i) => _PostTile(post: vm.feed[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 6,
      separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.6),
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _ShimmerBox(width: 160, height: 16),
            SizedBox(height: 12),
            _ShimmerBox(width: double.infinity, height: 12),
            SizedBox(height: 8),
            _ShimmerBox(width: double.infinity, height: 120),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  const _ShimmerBox({required this.width, required this.height});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade800.withOpacity(0.25),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _MentionText extends StatelessWidget {
  final String text;
  final SocialViewModel vm;
  const _MentionText({required this.text, required this.vm});
  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'@([A-Za-z0-9_ğüşöçıİĞÜŞÖÇ]+)');
    int last = 0;
    for (final m in regex.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final name = m.group(1)!;
      final id = vm.friendNameToId[name] ?? ''; // profil her zaman açılabilir
      final isFriend = vm.isFriendName(name);
      spans.add(TextSpan(
        text: '@$name',
        style: TextStyle(color: isFriend ? Theme.of(context).colorScheme.primary : Colors.grey),
        recognizer: (TapGestureRecognizer()
          ..onTap = () {
            Navigator.pushNamed(context, '/user-profile', arguments: {'userId': id.isEmpty ? name : id, 'repo': vm.repository});
          }),
      ));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return RichText(text: TextSpan(style: DefaultTextStyle.of(context).style, children: spans));
  }
}

class _Composer extends StatefulWidget {
  final SocialViewModel vm;
  const _Composer({required this.vm});
  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final ImagePicker _picker = ImagePicker();
  OverlayEntry? _mentionOverlay;
  final LayerLink _layerLink = LayerLink();
  // Tracks current mention query (for future UX tweaks like highlighting)
  String _mentionQuery = '';
  List<SocialUser> _suggestions = const [];

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 85);
    if (images.isEmpty) return;
    setState(() {
      widget.vm.pendingImagePaths.addAll(images.map((x) => x.path));
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final canPost = vm.composerController.text.trim().isNotEmpty || vm.pendingImagePaths.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        children: [
          if (vm.isEditing) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text('Gönderiyi düzenliyorsun', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => vm.cancelEdit(),
                    child: Text('İptal', style: TextStyle(color: Colors.blue.shade700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          CompositedTransformTarget(
            link: _layerLink,
            child: TextField(
              controller: vm.composerController,
            minLines: 2,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: vm.isEditing ? 'Gönderiyi düzenle...' : 'Ne düşünüyorsun?',
              border: const OutlineInputBorder(),
            ),
              onChanged: (t) async {
                setState(() {});
                final at = t.lastIndexOf('@');
                if (at >= 0) {
                  final q = t.substring(at + 1).split(RegExp(r'\s')).first;
                  _mentionQuery = q;
                  if (q.isNotEmpty) {
                    _suggestions = await context.read<SocialViewModel>().mentionSuggestions(q);
                    _showMentions();
                  } else {
                    _hideMentions();
                  }
                } else {
                  _hideMentions();
                }
              },
            ),
          ),
          if (vm.pendingImagePaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ImagesGrid(paths: vm.pendingImagePaths),
          ],
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.image_outlined),
                tooltip: 'Görsel ekle',
                onPressed: _pickImages,
              ),
              const Spacer(),
              if (canPost)
                Container(
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: vm.isPosting
                        ? null
                        : () async {
                            final names = context.read<SocialViewModel>().extractMentionNames(vm.composerController.text);
                            if (!context.read<SocialViewModel>().canMentionAllNames(names)) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sadece arkadaşlarını etiketleyebilirsin.')));
                              return;
                            }
                            if (vm.isEditing) {
                              await vm.updatePost();
                            } else {
                              vm.postNow();
                            }
                          },
                    child: vm.isPosting 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                        : Text(vm.isEditing ? 'Güncelle' : 'Paylaş', style: const TextStyle(fontSize: 14)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMentions() {
    _mentionOverlay?.remove();
    if (_suggestions.isEmpty) return;
    final overlay = Overlay.of(context);
    _mentionOverlay = OverlayEntry(
      builder: (_) => Positioned(
        width: MediaQuery.of(context).size.width - 24,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 70),
          child: Material(
            elevation: 4,
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final u in _suggestions)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(u.displayName),
                    onTap: () {
                      final ctrl = widget.vm.composerController;
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
                  ),
              ],
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
}

class _ImagesGrid extends StatelessWidget {
  final List<String> paths;
  final bool enableViewer;
  const _ImagesGrid({required this.paths, this.enableViewer = false});
  @override
  Widget build(BuildContext context) {
    final display = paths.take(4).toList();
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 3,
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
      children: [
        for (int i = 0; i < display.length; i++)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GestureDetector(
              onTap: !enableViewer
                  ? null
                  : () {
                      showDialog(
                        context: context,
                        barrierColor: Colors.black87,
                        builder: (_) => _ImageViewer(paths: paths, initialIndex: i),
                      );
                    },
              child: Image.file(File(display[i]), fit: BoxFit.cover),
            ),
          ),
      ],
    );
  }
}

class _ImageViewer extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;
  const _ImageViewer({required this.paths, required this.initialIndex});
  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late PageController _pc;
  @override
  void initState() {
    super.initState();
    _pc = PageController(initialPage: widget.initialIndex);
  }
  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              PageView.builder(
                controller: _pc,
                itemCount: widget.paths.length,
                itemBuilder: (_, i) => InteractiveViewer(
                  child: Center(child: Image.file(File(widget.paths[i]))),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  final Post post;
  const _PostTile({required this.post});
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SocialViewModel>();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/user-profile',
                    arguments: {'userId': post.authorId, 'repo': context.read<SocialViewModel>().repository},
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
                      const SizedBox(width: 8),
                      Text(
                        context.read<SocialViewModel>().userName(post.authorId),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(context.read<SocialViewModel>().timeAgo(post.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const Spacer(),
                Builder(
                  builder: (ctx) {
                    final vm = ctx.watch<SocialViewModel>();
                    final isMine = vm.meId == post.authorId;
                    return PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'report') _reportPost(ctx, post);
                        if (v == 'edit' && isMine) _editPost(ctx, post);
                        if (v == 'delete' && isMine) _deletePost(ctx, post);
                      },
                      itemBuilder: (_) => [
                        if (isMine)
                          const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                        if (isMine)
                          const PopupMenuItem(value: 'delete', child: Text('Sil')),
                        if (!isMine)
                          const PopupMenuItem(value: 'report', child: Text('Bildir')),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            _MentionText(text: post.content, vm: context.read<SocialViewModel>()),
            if (post.imagePaths.isNotEmpty) ...[
              const SizedBox(height: 8),
            _ImagesGrid(paths: post.imagePaths, enableViewer: true),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    vm.isLikedByMe(post.id) ? Icons.favorite : Icons.favorite_border,
                    color: vm.isLikedByMe(post.id) ? Colors.red : null,
                  ),
                  onPressed: () => vm.toggleLike(post),
                ),
                Text(vm.compactCount(vm.likeCount(post.id))),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.mode_comment_outlined),
                  onPressed: () => _openCommentsBottomSheet(context, post, vm),
                ),
                Text(vm.compactCount(vm.commentCount(post.id))),
              ],
            ),
            const SizedBox(height: 6),
            _FirstCommentOrMore(post: post),
          ],
        ),
      ),
    );
  }
}

class _FirstCommentOrMore extends StatelessWidget {
  final Post post;
  const _FirstCommentOrMore({required this.post});
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SocialViewModel>();
    return FutureBuilder<List<Comment>>(
      future: context.read<SocialViewModel>().repository.getComments(post.id),
      builder: (context, snapshot) {
        final comments = snapshot.data ?? const <Comment>[];
        if (comments.isEmpty) {
          return Align(
            alignment: Alignment.centerLeft,
              child: TextButton(
              onPressed: () {
                final vm = context.read<SocialViewModel>();
                _openCommentsBottomSheet(context, post, vm);
              },
              child: const Text('Yorum yap'),
            ),
          );
        }
        final first = comments.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/user-profile',
                    arguments: {'userId': first.authorId, 'repo': context.read<SocialViewModel>().repository},
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)),
                      const SizedBox(width: 6),
                      Text(
                        context.read<SocialViewModel>().userName(first.authorId),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(context.read<SocialViewModel>().timeAgo(first.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 4),
            _MentionText(text: first.content, vm: context.read<SocialViewModel>()),
            if (comments.length > 1 || vm.commentCount(post.id) > 1)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    final vm = context.read<SocialViewModel>();
                    _openCommentsBottomSheet(context, post, vm);
                  },
                  child: const Text('Devamını gör'),
                ),
              )
          ],
        );
      },
    );
  }
}

void _openCommentsBottomSheet(BuildContext context, Post post, SocialViewModel vm) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _CommentsSheet(post: post, vm: vm),
  );
}

class _CommentsSheet extends StatefulWidget {
  final Post post;
  final SocialViewModel vm;
  const _CommentsSheet({required this.post, required this.vm});
  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _replyToCommentId;
  final TextEditingController _replyCtrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 12, right: 12),
                child: Row(
                  children: [
                    Text('${vm.likeCount(widget.post.id)} beğeni', style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextButton(
                      onPressed: () async {
                        final users = await vm.likers(widget.post.id);
                        if (!mounted) return;
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => ListView(
                            children: [
                              const ListTile(title: Text('Beğenenler')),
                              for (final u in users)
                                ListTile(
                                  leading: const CircleAvatar(child: Icon(Icons.person)),
                                  title: Text(u.displayName),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.pushNamed(
                                      context,
                                      '/user-profile',
                                      arguments: {'userId': u.id, 'repo': context.read<SocialViewModel>().repository},
                                    );
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                      child: const Text('Görüntüle'),
                    ),
                    const Spacer(),
                    Text('${vm.commentCount(widget.post.id)} yorum'),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Comment>>(
                  future: vm.repository.getComments(widget.post.id),
                  builder: (context, snapshot) {
                    final comments = snapshot.data ?? const <Comment>[];
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: comments.length,
                      itemBuilder: (_, i) {
                        final c = comments[i];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ListTile(
                                    leading: const CircleAvatar(child: Icon(Icons.person)),
                                    title: Text(vm.userName(c.authorId), style: const TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: _MentionText(text: c.content, vm: vm),
                                    trailing: Text(vm.timeAgo(c.createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ),
                                ),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () async {
                                    print('Comment like tapped: ${c.id}');
                                    await vm.toggleCommentLike(c.id);
                                    setState(() {}); // Force UI update
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          vm.isCommentLikedByMe(c.id) ? Icons.favorite : Icons.favorite_border,
                                          size: 16,
                                          color: vm.isCommentLikedByMe(c.id) ? Colors.red : Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          vm.compactCount(vm.commentLikeCount(c.id)),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: vm.isCommentLikedByMe(c.id) ? Colors.red : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 16, bottom: 8),
                              child: TextButton(
                                onPressed: () => setState(() { _replyToCommentId = c.id; }),
                                child: const Text('Yanıtla'),
                              ),
                            ),
                            FutureBuilder<List<Comment>>(
                              future: vm.repository.getReplies(c.id),
                              builder: (context, snap) {
                                final repl = snap.data ?? const <Comment>[];
                                return Padding(
                                  padding: const EdgeInsets.only(left: 32),
                                  child: Column(
                                    children: [
                                      for (final r in repl)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ListTile(
                                                leading: const CircleAvatar(child: Icon(Icons.person, size: 16)),
                                                title: Text(vm.userName(r.authorId), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                                subtitle: _MentionText(text: r.content, vm: vm),
                                                dense: true,
                                                trailing: Text(vm.timeAgo(r.createdAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                              ),
                                            ),
                                            GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () async {
                                                print('Reply like tapped: ${r.id}');
                                                await vm.toggleCommentLike(r.id);
                                                setState(() {}); // Force UI update
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      vm.isCommentLikedByMe(r.id) ? Icons.favorite : Icons.favorite_border,
                                                      size: 14,
                                                      color: vm.isCommentLikedByMe(r.id) ? Colors.red : Colors.grey,
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      vm.compactCount(vm.commentLikeCount(r.id)),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: vm.isCommentLikedByMe(r.id) ? Colors.red : Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: (_replyToCommentId == null)
                          ? TextField(
                              controller: _controller,
                              decoration: const InputDecoration(
                                hintText: 'Yorum yaz',
                                border: OutlineInputBorder(),
                              ),
                            )
                          : TextField(
                              controller: _replyCtrl,
                              decoration: InputDecoration(
                                hintText: 'Yanıt yaz',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setState(() { _replyToCommentId = null; _replyCtrl.clear(); }),
                                ),
                              ),
                            ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () async {
                      if (_replyToCommentId == null) {
                        final text = _controller.text.trim();
                        if (text.isEmpty) return;
                        final names = vm.extractMentionNames(text);
                        if (!vm.canMentionAllNames(names)) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sadece arkadaşlarını etiketleyebilirsin.')));
                          return;
                        }
                        await vm.addComment(widget.post, text);
                        _controller.clear();
                      } else {
                        final text = _replyCtrl.text.trim();
                        if (text.isEmpty) return;
                        final names = vm.extractMentionNames(text);
                        if (!vm.canMentionAllNames(names)) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sadece arkadaşlarını etiketleyebilirsin.')));
                          return;
                        }
                        await vm.addReply(Comment(id: _replyToCommentId!, postId: widget.post.id, authorId: vm.meId, content: '', createdAt: DateTime.now()), text);
                        _replyCtrl.clear();
                        _replyToCommentId = null;
                      }
                      setState(() {}); // refresh list
                    },
                  )
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _reportPost(BuildContext context, Post post) async {
  final vm = context.read<SocialViewModel>();
  final me = vm.meId;
  if (me == post.authorId) return; // güvenlik

  const reasons = [
    'Spam',
    'Taciz / Hakaret',
    'Yanıltıcı içerik',
    'Uygunsuz içerik',
    'Diğer',
  ];
  String selected = reasons.first;
  final detailsCtrl = TextEditingController();

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Gönderiyi bildir'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: selected,
            items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) => selected = v ?? selected,
            decoration: const InputDecoration(labelText: 'Sebep'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: detailsCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Detay (opsiyonel)',
              hintText: 'Ek bilgi varsa yazın…',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Gönder')),
      ],
    ),
  );

  if (ok != true) return;

  // Şimdilik local: sadece teşekkür mesajı gösterelim.
  // Backend hazır olduğunda Supabase tablosuna insert edeceğiz (posts_abuse_reports).
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Bildiriminiz alındı. Teşekkürler.')),
  );
}

Future<void> _editPost(BuildContext context, Post post) async {
  context.read<SocialViewModel>().startEditPost(post);
}

Future<void> _deletePost(BuildContext context, Post post) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Gönderiyi sil'),
      content: const Text('Bu gönderiyi silmek istediğine emin misin?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
      ],
    ),
  );
  if (ok != true) return;
  // Local stub: Şimdilik sadece Snackbar; repo'ya delete eklendiğinde listeden kaldıracağız.
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silme yakında eklenecek.')));
}


