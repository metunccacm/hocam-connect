// lib/view/social_view.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/social_models.dart';
import '../models/social_user.dart';
import '../services/social_repository.dart';
import '../services/social_service.dart';
import '../viewmodel/social_viewmodel.dart';
import 'bottombar_view.dart';
import 'create_spost_view.dart';
import 'spost_detail_view.dart';
import '../services/social_service.dart';

class SocialView extends StatelessWidget {
  const SocialView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SocialViewModel>(
  create: (_) => SocialViewModel(
    repository: LocalHiveSocialRepository(),
    service: SocialService(), // ✅ now properly added
  )..load(),
  child: const _SocialViewBody(),
);

  }
}

class _SocialViewBody extends StatefulWidget {
  const _SocialViewBody();

  @override
  State<_SocialViewBody> createState() => _SocialViewBodyState();
}

class _SocialViewBodyState extends State<_SocialViewBody> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();
  bool _showQuickCompose = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _scrollController.addListener(_updateQuickComposeVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateQuickComposeVisibility());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateQuickComposeVisibility);
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_animationController.isCompleted) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
  }

  void _updateQuickComposeVisibility() {
    final shouldShow = _scrollController.hasClients &&
        _scrollController.offset > 200 &&
        _animationController.isDismissed;
    if (shouldShow != _showQuickCompose) {
      setState(() => _showQuickCompose = shouldShow);
    }
  }

  Future<void> _openCreatePost() async {
    final vm = context.read<SocialViewModel>();
    final postId = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateSPostView(repository: vm.repository),
        fullscreenDialog: true,
      ),
    );
    if (postId != null) {
      await vm.load();
      // Optionally jump to detail
      // ignore: use_build_context_synchronously
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SPostDetailView(
            postId: postId,
            repository: vm.repository,
          ),
        ),
      );
      await vm.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SocialViewModel>();
    return DefaultTabController(
      length: 2,
      initialIndex: vm.currentTab == SocialTab.explore ? 0 : 1,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => vm.load(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _scrollController,
                slivers: [
                  SliverAppBar(
                    toolbarHeight: 48,
                    elevation: 0,
                    backgroundColor: Theme.of(context).colorScheme.surface.withAlpha(191),
                    leading: Navigator.canPop(context)
                        ? IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                            onPressed: () => Navigator.maybePop(context),
                          )
                        : null,
                    flexibleSpace: ClipRect(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    title: const Text('Hocam Connect',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
                    centerTitle: true,
                    actions: [
                      IconButton(
                        tooltip: 'Notifications',
                        onPressed: () => Navigator.pushNamed(context, '/notifications'),
                        icon: const Icon(Icons.notifications_none_outlined),
                      ),
                    ],
                    floating: true,
                    snap: true,
                    pinned: false,
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(44),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: TabBar(
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.black87,
                            dividerColor: Colors.transparent,
                            indicator: BoxDecoration(
                              color: const Color(0xFF007BFF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onTap: (i) => vm.switchTab(i == 0 ? SocialTab.explore : SocialTab.friends),
                            tabs: const [
                              Tab(child: Text('Explore', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                              Tab(child: Text('Friends', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Column(children: const [SizedBox(height: 8)]),
                  ),
                  if (vm.isLoading)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => const _LoadingPostShimmer(),
                        childCount: 6,
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _PostTile(post: vm.feed[i]),
                        childCount: vm.feed.length,
                      ),
                    ),
                ],
              ),
            ),
            _buildMenuOverlay(),

            // Quick compose FAB
            if (_showQuickCompose)
              Positioned(
                right: 16,
                bottom: 88,
                child: FloatingActionButton(
                  heroTag: 'quick_compose_fab',
                  backgroundColor: const Color(0xFF007BFF),
                  onPressed: _openCreatePost,
                  child: const Icon(Icons.edit, color: Colors.white),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'social_menu_fab',
          shape: const CircleBorder(),
          backgroundColor: Colors.white,
          elevation: 4.0,
          onPressed: _toggleMenu,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              if (_animationController.isCompleted) {
                return const Icon(Icons.close, color: Colors.black);
              }
              return Padding(
                padding: const EdgeInsets.all(10.0),
                child: Image.asset('assets/logo/hc_logo.png'),
              );
            },
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: _BottomBar(),
      ),
    );
  }

  Widget _buildMenuOverlay() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final animationValue =
            CurvedAnimation(parent: _animationController, curve: Curves.easeOut).value;
        if (animationValue == 0) return const SizedBox.shrink();

        return Positioned.fill(
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.hardEdge,
            children: [
              GestureDetector(
                onTap: _toggleMenu,
                child: Container(color: Colors.black.withOpacity(0.3 * animationValue)),
              ),
              _buildMenuItem(
                icon: Icons.calculate_outlined,
                heroTag: 'menu_calc',
                angle: -135,
                animationValue: animationValue,
                onPressed: () {
                  _toggleMenu();
                  Navigator.pushNamed(context, '/gpa_calculator');
                },
              ),
              _buildMenuItem(
                icon: Icons.settings,
                heroTag: 'menu_settings',
                angle: -90,
                animationValue: animationValue,
                onPressed: () {
                  _toggleMenu();
                  Navigator.pushNamed(context, '/settings');
                },
              ),
              _buildMenuItem(
                icon: Icons.directions_car_outlined,
                heroTag: 'menu_hitch',
                angle: -45,
                animationValue: animationValue,
                onPressed: () {
                  _toggleMenu();
                  Navigator.pushNamed(context, '/hitchike');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String heroTag,
    required double angle,
    required double animationValue,
    required VoidCallback onPressed,
  }) {
    final radius = 80.0;
    final x = radius * math.cos(angle * math.pi / 180);
    final y = radius * math.sin(angle * math.pi / 180);

    return Positioned(
      bottom: -y,
      left: MediaQuery.of(context).size.width / 2 - 20 + x,
      child: Transform.scale(
        scale: animationValue,
        child: FloatingActionButton(
          heroTag: heroTag,
          mini: true,
          onPressed: onPressed,
          backgroundColor: Colors.white,
          child: Icon(icon, color: Colors.grey.shade700),
        ),
      ),
    );
  }
}

class _LoadingPostShimmer extends StatelessWidget {
  const _LoadingPostShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        _ShimmerBox(width: 160, height: 16),
        SizedBox(height: 12),
        _ShimmerBox(width: double.infinity, height: 12),
        SizedBox(height: 8),
        _ShimmerBox(width: double.infinity, height: 120),
      ]),
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

/* =========================
 * Post Tile
 * ========================= */

class _PostTile extends StatefulWidget {
  final Post post;
  const _PostTile({required this.post});
  @override
  State<_PostTile> createState() => _PostTileState();
}

class _PostTileState extends State<_PostTile> {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SocialViewModel>();
    final post = widget.post;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  '/user-profile',
                  arguments: {'userId': post.authorId, 'repo': vm.repository},
                ),
                child: Row(
                  children: [
                    FutureBuilder<SocialUser?>(
                      future: vm.repository.getUser(post.authorId),
                      builder: (context, snapshot) {
                        final user = snapshot.data;
                        final avatarUrl = user?.avatarUrl;
                        return CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue.shade100,
                          backgroundImage:
                              avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                          child: (avatarUrl == null || avatarUrl.isEmpty)
                              ? Icon(Icons.person, size: 18, color: Colors.blue.shade700)
                              : null,
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    Text(
                      vm.userName(post.authorId),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(vm.timeAgo(post.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 11)),
              const Spacer(),
              Builder(
                builder: (ctx) {
                  final isMine = vm.meId == post.authorId;
                  return PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'report' && !isMine) {
                        _reportPost(ctx, post);
                      }
                      if (v == 'edit' && isMine) {
                        // Navigate to an edit screen if you have one
                        // Navigator.push(...);
                      }
                      if (v == 'delete' && isMine) {
                        await _deletePost(ctx, post);
                      }
                    },
                    itemBuilder: (_) => [
                      if (isMine) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (isMine) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                      if (!isMine) const PopupMenuItem(value: 'report', child: Text('Report')),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          _MentionText(text: post.content, vm: vm),
          if (post.imagePaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ImagesGridNet(urls: post.imagePaths),
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
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SPostDetailView(
                        postId: post.id,
                        repository: vm.repository,
                        initialPost: post,
                      ),
                    ),
                  );
                  if (mounted) context.read<SocialViewModel>().load();
                },
              ),
              Text(vm.compactCount(vm.commentCount(post.id))),
            ],
          ),
        ]),
      ),
    );
  }
}

/* =========================
 * Hashtag & Mention Rich Text
 * ========================= */

class _MentionText extends StatelessWidget {
  final String text;
  final SocialViewModel vm;
  const _MentionText({required this.text, required this.vm});

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    final combined = RegExp(r'(@|#)([A-Za-z0-9_ğüşöçıİĞÜŞÖÇ.]+)');
    int last = 0;
    for (final m in combined.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final symbol = m.group(1)!; // @ or #
      final value = m.group(2)!;
      if (symbol == '@') {
        final id = vm.friendNameToId[value] ?? '';
        final isFriend = vm.isFriendName(value);
        spans.add(TextSpan(
          text: '@$value',
          style: TextStyle(color: isFriend ? Theme.of(context).colorScheme.primary : Colors.grey),
          recognizer: (TapGestureRecognizer()
            ..onTap = () {
              Navigator.pushNamed(
                context,
                '/user-profile',
                arguments: {'userId': id.isEmpty ? value : id, 'repo': vm.repository},
              );
            }),
        ));
      } else {
        spans.add(TextSpan(
          text: '#$value',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
          recognizer: (TapGestureRecognizer()
            ..onTap = () {
              Navigator.pushNamed(context, '/search', arguments: {'q': '#$value'});
            }),
        ));
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return RichText(text: TextSpan(style: DefaultTextStyle.of(context).style, children: spans));
  }
}

/* =========================
 * Images grid (network)
 * ========================= */

class _ImagesGridNet extends StatelessWidget {
  final List<String> urls;
  const _ImagesGridNet({required this.urls});

  @override
  Widget build(BuildContext context) {
    final show = urls.take(4).toList();
    const radius = 8.0;

    Widget tile(int i, {BorderRadius? br}) {
      return ClipRRect(
        borderRadius: br ?? BorderRadius.circular(radius),
        child: AspectRatio(
          aspectRatio: 1,
          child: Image.network(show[i], fit: BoxFit.cover),
        ),
      );
    }

    if (show.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AspectRatio(aspectRatio: 4 / 3, child: Image.network(show[0], fit: BoxFit.cover)),
      );
    }
    if (show.length == 2) {
      return Row(
        children: [
          Expanded(child: tile(0)),
          const SizedBox(width: 6),
          Expanded(child: tile(1)),
        ],
      );
    }
    if (show.length == 3) {
      return Row(
        children: [
          Expanded(flex: 2, child: tile(0)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              children: [
                Expanded(child: tile(1)),
                const SizedBox(height: 6),
                Expanded(child: tile(2)),
              ],
            ),
          ),
        ],
      );
    }
    final extra = urls.length - 4;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tile(0)),
            const SizedBox(width: 6),
            Expanded(child: tile(1)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: tile(2)),
            const SizedBox(width: 6),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  tile(3),
                  if (extra > 0)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(radius),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '+$extra',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/* =========================
 * Bottom Bar
 * ========================= */

class _BottomBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8.0, offset: const Offset(0, -2))],
      ),
      child: BottomAppBar(
        color: Colors.grey.shade50,
        elevation: 0,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                _SocialBottomItem(
                  icon: Icons.home,
                  label: 'Home',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MainTabView(initialIndex: 0)),
                  ),
                ),
                _SocialBottomItem(
                  icon: Icons.storefront,
                  label: 'Marketplace',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MainTabView(initialIndex: 1)),
                  ),
                ),
              ]),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                _SocialBottomItem(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chats',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MainTabView(initialIndex: 2)),
                  ),
                ),
                _SocialBottomItem(
                  icon: Icons.star_border,
                  label: 'TWOC',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MainTabView(initialIndex: 3)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialBottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SocialBottomItem({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final color = Colors.grey;
    return MaterialButton(
      minWidth: 40,
      onPressed: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, color: color),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

/* =========================
 * Helpers (dialogs)
 * ========================= */

Future<void> _reportPost(BuildContext context, Post post) async {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for the report.')));
}

Future<void> _deletePost(BuildContext context, Post post) async {
  final vm = context.read<SocialViewModel>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete post'),
      content: const Text('This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ),
  );
  if (ok != true) return;

  try {
    await vm.deletePostById(post.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post deleted.')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error while deleting: $e')));
    }
  }
}
