// lib/view/social_view.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 🔔 NEW

import '../models/social_models.dart';
import '../models/social_user.dart';
import '../services/social_repository.dart';
import '../services/social_service.dart';
import '../viewmodel/social_viewmodel.dart';
import 'bottombar_view.dart';
import 'create_spost_view.dart';
import 'spost_detail_view.dart';
import 'social_notifications_view.dart';
import 'edit_spost_view.dart';

class SocialView extends StatefulWidget {
  const SocialView({super.key});

  @override
  State<SocialView> createState() => _SocialViewState();
}

class _SocialViewState extends State<SocialView> {
  late final SocialViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = SocialViewModel(
      repository: SupabaseSocialRepository(),
      service: SocialService(),
    );
    // Load data after first frame to ensure widget is fully mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    try {
      debugPrint('🚀 SocialView: Starting initial load...');
      await _viewModel.load();
      debugPrint('✅ SocialView: Initial load completed');
    } catch (e) {
      debugPrint('❌ SocialView: Failed to load social feed: $e');
      // ViewModel already handles the error and sets isLoading = false
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SocialViewModel>.value(
      value: _viewModel,
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

  // 🔔 NEW: unread notifications
  int _unreadCount = 0;
  RealtimeChannel? _notifChannel;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _scrollController.addListener(_updateQuickComposeVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateQuickComposeVisibility();
      _loadUnreadNotifications();   // initial unread fetch
      _subscribeNotifications();    // realtime
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateQuickComposeVisibility);
    _scrollController.dispose();
    _animationController.dispose();

    // 🔔 cleanup
    if (_notifChannel != null) {
      Supabase.instance.client.removeChannel(_notifChannel!);
      _notifChannel = null;
    }
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

  void _openFullCompose() {
    final vm = context.read<SocialViewModel>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _FullScreenComposer(vm: vm);
      },
    );
  }

  // ignore: unused_element
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

  // ================================
  // 🔔 Notifications plumbing
  // ================================
  Future<void> _loadUnreadNotifications() async {
  final supa = Supabase.instance.client;
  final meId = supa.auth.currentUser?.id;
  if (meId == null) return;

  final rows = await supa
      .from('notifications_social')
      .select('id')                // ← simple select
      .eq('receiver_id', meId)
      .eq('is_read', false);

  final int cnt = (rows as List).length;  // ← count locally
  if (!mounted) return;
  setState(() => _unreadCount = cnt);
}


  void _subscribeNotifications() {
    final supa = Supabase.instance.client;
    final meId = supa.auth.currentUser?.id;
    if (meId == null) return;

    _notifChannel = supa.channel('rt_notifications_$meId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications_social',
        callback: (payload) {
          if (payload.newRecord['receiver_id'] == meId &&
              payload.newRecord['is_read'] == false) {
            setState(() => _unreadCount = _unreadCount + 1);
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'notifications_social',
        callback: (payload) {
          if (payload.newRecord['receiver_id'] == meId) {
            _loadUnreadNotifications();
          }
        },
      )
      ..subscribe();
  }

  // When user taps the bell: mark all as read, zero the badge, then open the screen
  Future<void> _openNotifications() async {
    final supa = Supabase.instance.client;
    final meId = supa.auth.currentUser?.id;
    if (meId == null) return;

    // Mark all unread as read
    await supa
        .from('notifications_social')
        .update({'is_read': true})
        .eq('receiver_id', meId)
        .eq('is_read', false);

    if (mounted) setState(() => _unreadCount = 0);

    final vm = context.read<SocialViewModel>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SocialNotificationsView(repository: vm.repository),
      ),
    );

    // After returning, re-sync (in case something arrived while inside)
    if (mounted) {
      await _loadUnreadNotifications();
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
                      // 🔔 Bell with badge
                      Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              tooltip: 'Bildirimler',
                              onPressed: _openNotifications,
                              icon: const Icon(Icons.notifications_none_outlined),
                            ),
                            if (_unreadCount > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(minWidth: 18),
                                  child: Text(
                                    _unreadCount > 99 ? '99+' : '$_unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
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
                    child: Column(children: [SizedBox(height: 8)]),
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

            // Quick compose button (bottom-right), always visible above bottom bar
            Positioned(
              right: 16,
              bottom: 88, // above BottomAppBar (~60) with margin
              child: FloatingActionButton(
                heroTag: 'quick_compose_fab',
                backgroundColor: const Color(0xFF007BFF),
                onPressed: _openFullCompose,
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
              // When menu is open, show a close icon
              if (_animationController.isCompleted) {
                return const Icon(Icons.close, color: Colors.black);
              }
              // Otherwise, show the logo
              return Padding(
                padding: const EdgeInsets.all(10.0),
                child: Image.asset('assets/logo/hc_logo.png'),
              );
            },
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50, // Light grey background
            border: Border(
              top: BorderSide(
                color: Colors.grey.shade200, // Subtle top border
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05), // Very subtle shadow
                blurRadius: 8.0,
                offset: const Offset(0, -2), // Shadow above the bar
                spreadRadius: 0,
              ),
            ],
          ),
          child: BottomAppBar(
            color: Colors.grey.shade50, // Match container color
            elevation: 0, // Remove default elevation
            shape: const CircularNotchedRectangle(),
            notchMargin: 8.0,
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _SocialBottomItem(
                        icon: Icons.home,
                        label: 'Home',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MainTabView(initialIndex: 0),
                          ),
                        ),
                      ),
                      _SocialBottomItem(
                        icon: Icons.storefront,
                        label: 'Marketplace',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MainTabView(initialIndex: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _SocialBottomItem(
                        icon: Icons.chat_bubble_outline,
                        label: 'Chats',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MainTabView(initialIndex: 2),
                          ),
                        ),
                      ),
                      _SocialBottomItem(
                        icon: Icons.star_border,
                        label: 'TWOC',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MainTabView(initialIndex: 3),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
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
                    FutureBuilder<SocialUser?>(
                      future: vm.repository.getUser(post.authorId),
                      builder: (context, snapshot) {
                        final user = snapshot.data;
                        // Önce name + surname kullan, yoksa displayName
                        String displayName = 'User';
                        if (user != null) {
                          // repository.getUser zaten _bestDisplayName kullanıyor
                          // ama önce name+surname görmek istiyoruz
                          displayName = user.displayName;
                        }
                        return Text(
                          displayName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        );
                      },
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
                      if (v == 'edit' && vm.meId == post.authorId) {
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditSPostView(
                              postId: post.id,
                              repository: vm.repository,
                              initialPost: post,
                            ),
                          ),
                        );
                        if (changed == true && context.mounted) {
                          await context.read<SocialViewModel>().load();
                        }
                      } else if (v == 'delete' && vm.meId == post.authorId) {
                        await _deletePost(context, post);
                      } else if (v == 'report' && vm.meId != post.authorId) {
                        _reportPost(context, post);
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
          const SizedBox(height: 6),
          _FirstCommentOrMore(post: post),
        ]),
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
      future: vm.repository.getComments(post.id),
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
                    arguments: {'userId': first.authorId, 'repo': vm.repository},
                  ),
                  child: Row(
                    children: [
                      FutureBuilder<SocialUser?>(
                        future: vm.repository.getUser(first.authorId),
                        builder: (context, snapshot) {
                          final user = snapshot.data;
                          final avatarUrl = user?.avatarUrl;
                          return CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.blue.shade100,
                            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: (avatarUrl == null || avatarUrl.isEmpty)
                                ? Icon(Icons.person, size: 14, color: Colors.blue.shade700)
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                      FutureBuilder<SocialUser?>(
                        future: vm.repository.getUser(first.authorId),
                        builder: (context, snapshot) {
                          final displayName = snapshot.data?.displayName ?? vm.userName(first.authorId);
                          return Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(vm.timeAgo(first.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 4),
            _MentionText(text: first.content, vm: vm),
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
  final TextEditingController _replyCtrl = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  String? _replyToCommentId;

  @override
  void dispose() {
    _controller.dispose();
    _replyCtrl.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

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
            bottom: MediaQuery.of(context).viewInsets.bottom + 4,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 12, right: 12),
                child: Row(
                  children: [
                    Text('${vm.likeCount(widget.post.id)} beğeni', style: const TextStyle(fontWeight: FontWeight.w600)),
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
                                    leading: FutureBuilder<SocialUser?>(
                                      future: vm.repository.getUser(c.authorId),
                                      builder: (context, snapshot) {
                                        final user = snapshot.data;
                                        final avatarUrl = user?.avatarUrl;
                                        return CircleAvatar(
                                          backgroundColor: Colors.blue.shade100,
                                          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                              ? NetworkImage(avatarUrl)
                                              : null,
                                          child: (avatarUrl == null || avatarUrl.isEmpty)
                                              ? Icon(Icons.person, color: Colors.blue.shade700)
                                              : null,
                                        );
                                      },
                                    ),
                                    title: FutureBuilder<SocialUser?>(
                                      future: vm.repository.getUser(c.authorId),
                                      builder: (context, snapshot) {
                                        final displayName = snapshot.data?.displayName ?? vm.userName(c.authorId);
                                        return Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600));
                                      },
                                    ),
                                    subtitle: _MentionText(text: c.content, vm: vm),
                                    trailing: Text(vm.timeAgo(c.createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () async {
                                        await vm.toggleCommentLike(c.id);
                                        setState(() {});
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              vm.isCommentLikedByMeLocal(c.id) ? Icons.favorite : Icons.favorite_border,
                                              size: 16,
                                              color: vm.isCommentLikedByMeLocal(c.id) ? Colors.red : Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              vm.compactCount(vm.commentLikeCountLocal(c.id)),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: vm.isCommentLikedByMeLocal(c.id) ? Colors.red : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Builder(
                                      builder: (ctx) {
                                        final isMine = vm.meId == c.authorId;
                                        return PopupMenuButton<String>(
                                          onSelected: (v) {
                                            if (v == 'report' && !isMine) _reportComment(ctx, c);
                                            if (v == 'delete' && isMine) _deleteComment(ctx, c);
                                            if (v == 'edit' && isMine) _editComment(ctx, c);
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
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 16, bottom: 8),
                              child: TextButton(
                                onPressed: () async {
                                  // Get the author's display name for mention
                                  final user = await vm.repository.getUser(c.authorId);
                                  String mentionName;
                                  if (user != null && user.displayName.isNotEmpty && user.displayName != 'User') {
                                    mentionName = user.displayName;
                                  } else {
                                    // Fallback: try to get from profiles table directly
                                    final supa = Supabase.instance.client;
                                    try {
                                      final prof = await supa
                                          .from('profiles')
                                          .select('name, surname, display_name')
                                          .eq('id', c.authorId)
                                          .maybeSingle();
                                      if (prof != null) {
                                        final name = (prof['name'] ?? '').toString().trim();
                                        final surname = (prof['surname'] ?? '').toString().trim();
                                        final full = [name, surname].where((s) => s.isNotEmpty).join(' ').trim();
                                        mentionName = full.isNotEmpty ? full : (user?.displayName ?? vm.userName(c.authorId));
                                      } else {
                                        mentionName = user?.displayName ?? vm.userName(c.authorId);
                                      }
                                    } catch (_) {
                                      mentionName = user?.displayName ?? vm.userName(c.authorId);
                                    }
                                  }
                                  setState(() { 
                                    _replyToCommentId = c.id;
                                    _replyCtrl.text = '@$mentionName ';
                                  });
                                  // Wait for widget rebuild, then set cursor position and focus
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _replyCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _replyCtrl.text.length));
                                    _replyFocusNode.requestFocus();
                                  });
                                },
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
                                                leading: FutureBuilder<SocialUser?>(
                                                  future: vm.repository.getUser(r.authorId),
                                                  builder: (context, snapshot) {
                                                    final user = snapshot.data;
                                                    final avatarUrl = user?.avatarUrl;
                                                    return CircleAvatar(
                                                      radius: 12,
                                                      backgroundColor: Colors.blue.shade100,
                                                      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                                          ? NetworkImage(avatarUrl)
                                                          : null,
                                                      child: (avatarUrl == null || avatarUrl.isEmpty)
                                                          ? Icon(Icons.person, size: 16, color: Colors.blue.shade700)
                                                          : null,
                                                    );
                                                  },
                                                ),
                                                title: FutureBuilder<SocialUser?>(
                                                  future: vm.repository.getUser(r.authorId),
                                                  builder: (context, snapshot) {
                                                    final displayName = snapshot.data?.displayName ?? vm.userName(r.authorId);
                                                    return Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14));
                                                  },
                                                ),
                                                subtitle: _MentionText(text: r.content, vm: vm),
                                                dense: true,
                                                trailing: Text(vm.timeAgo(r.createdAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                GestureDetector(
                                                  behavior: HitTestBehavior.opaque,
                                                  onTap: () async {
                                                    await vm.toggleCommentLike(r.id);
                                                    setState(() {});
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          vm.isCommentLikedByMeLocal(r.id) ? Icons.favorite : Icons.favorite_border,
                                                          size: 14,
                                                          color: vm.isCommentLikedByMeLocal(r.id) ? Colors.red : Colors.grey,
                                                        ),
                                                        const SizedBox(width: 2),
                                                        Text(
                                                          vm.compactCount(vm.commentLikeCountLocal(r.id)),
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: vm.isCommentLikedByMeLocal(r.id) ? Colors.red : Colors.grey,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                TextButton(
                                                  style: TextButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                                    minimumSize: const Size(0, 0),
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                  onPressed: () async {
                                                    // Get the reply author's display name for mention
                                                    final user = await vm.repository.getUser(r.authorId);
                                                    String mentionName;
                                                    if (user != null && user.displayName.isNotEmpty && user.displayName != 'User') {
                                                      mentionName = user.displayName;
                                                    } else {
                                                      // Fallback: try to get from profiles table directly
                                                      final supa = Supabase.instance.client;
                                                      try {
                                                        final prof = await supa
                                                            .from('profiles')
                                                            .select('name, surname, display_name')
                                                            .eq('id', r.authorId)
                                                            .maybeSingle();
                                                        if (prof != null) {
                                                          final name = (prof['name'] ?? '').toString().trim();
                                                          final surname = (prof['surname'] ?? '').toString().trim();
                                                          final full = [name, surname].where((s) => s.isNotEmpty).join(' ').trim();
                                                          mentionName = full.isNotEmpty ? full : (user?.displayName ?? vm.userName(r.authorId));
                                                        } else {
                                                          mentionName = user?.displayName ?? vm.userName(r.authorId);
                                                        }
                                                      } catch (_) {
                                                        mentionName = user?.displayName ?? vm.userName(r.authorId);
                                                      }
                                                    }
                                                    setState(() { 
                                                      _replyToCommentId = r.parentCommentId ?? r.id;
                                                      _replyCtrl.text = '@$mentionName ';
                                                    });
                                                    // Wait for widget rebuild, then set cursor position and focus
                                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                                      _replyCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _replyCtrl.text.length));
                                                      _replyFocusNode.requestFocus();
                                                    });
                                                  },
                                                  child: const Text('Yanıtla', style: TextStyle(fontSize: 11)),
                                                ),
                                                Builder(
                                                  builder: (ctx) {
                                                    final isMine = vm.meId == r.authorId;
                                                    return PopupMenuButton<String>(
                                                      padding: EdgeInsets.zero,
                                                      splashRadius: 16,
                                                      onSelected: (v) {
                                                        if (v == 'report' && !isMine) _reportComment(ctx, r);
                                                        if (v == 'delete' && isMine) _deleteComment(ctx, r);
                                                        if (v == 'edit' && isMine) _editComment(ctx, r);
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: (_replyToCommentId == null)
                          ? TextField(
                              controller: _controller,
                              decoration: const InputDecoration(
                                hintText: 'Yorum yaz',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            )
                          : TextField(
                              controller: _replyCtrl,
                              focusNode: _replyFocusNode,
                              decoration: InputDecoration(
                                hintText: 'Yanıt yaz',
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setState(() { 
                                    _replyToCommentId = null; 
                                    _replyCtrl.clear(); 
                                    _replyFocusNode.unfocus();
                                  }),
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
                          final parentComment = Comment(id: _replyToCommentId!, postId: widget.post.id, authorId: vm.meId, content: '', createdAt: DateTime.now());
                          await vm.addReply(parentComment, text);
                          _replyCtrl.clear();
                          _replyToCommentId = null;
                        }
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

// ignore: unused_element
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

Future<void> _deleteComment(BuildContext context, Comment comment) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Yorumu sil'),
      content: const Text('Bu yorumu silmek istediğine emin misin?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
      ],
    ),
  );
  if (ok != true) return;
  await context.read<SocialViewModel>().deleteCommentById(comment.id);
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yorum silindi.')));
}

Future<void> _editComment(BuildContext context, Comment comment) async {
  final vm = context.read<SocialViewModel>();
  final controller = TextEditingController(text: comment.content);
  
  final updatedContent = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Yorumu düzenle'),
      content: TextField(
        controller: controller,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'Yorumunuzu düzenleyin...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Kaydet'),
        ),
      ],
    ),
  );

  if (updatedContent != null && updatedContent.isNotEmpty && updatedContent != comment.content) {
    final updatedComment = Comment(
      id: comment.id,
      postId: comment.postId,
      authorId: comment.authorId,
      content: updatedContent,
      createdAt: comment.createdAt,
      parentCommentId: comment.parentCommentId,
    );
    await vm.updateComment(updatedComment);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yorum güncellendi.')));
  }
}

Future<void> _reportComment(BuildContext context, Comment comment) async {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bildiriminiz alındı. Teşekkürler.')));
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

/* =========================
 * Full Screen Composer
 * ========================= */

class _FullScreenComposer extends StatefulWidget {
  final SocialViewModel vm;
  const _FullScreenComposer({required this.vm});

  @override
  State<_FullScreenComposer> createState() => _FullScreenComposerState();
}

class _FullScreenComposerState extends State<_FullScreenComposer> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _images = [];

  @override
  void initState() {
    super.initState();
    // Seed from existing vm state if any (for edit continuity in future)
    _controller.text = widget.vm.composerController.text;
    _images = List.from(widget.vm.pendingImagePaths);
    // Autofocus after open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 85);
    if (images.isEmpty) return;
    setState(() {
      _images.addAll(images.map((x) => x.path));
    });
  }

  Future<void> _submit() async {
    final vm = widget.vm;
    final text = _controller.text.trim();
    if (text.isEmpty && _images.isEmpty) {
      Navigator.pop(context);
      return;
    }
    vm.composerController.text = _controller.text;
    vm.pendingImagePaths
      ..clear()
      ..addAll(_images);
    if (vm.isEditing) {
      await vm.updatePost();
    } else {
      await vm.postNow();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final canPost = _controller.text.trim().isNotEmpty || _images.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.98,
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        if (vm.isEditing) {
                          vm.cancelEdit();
                        }
                        Navigator.pop(context);
                      },
                      child: const Text('İptal et'),
                    ),
                  ],
                ),
                const Divider(height: 1),
                // Composer content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          minLines: 5,
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: vm.isEditing ? 'Gönderinizi düzenleyin...' : 'Ne oluyor?',
                            border: InputBorder.none,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        if (_images.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _ImagesGrid(paths: _images),
                        ],
                      ],
                    ),
                  ),
                ),
                // Actions bar
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.photo_outlined),
                          onPressed: _pickImages,
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: canPost && !vm.isPosting ? _submit : null,
                          child: vm.isPosting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(vm.isEditing ? 'Güncelle' : 'Paylaş'),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* =========================
 * Images Grid (local file paths)
 * ========================= */

class _ImagesGrid extends StatelessWidget {
  final List<String> paths;

  const _ImagesGrid({required this.paths});

  @override
  Widget build(BuildContext context) {
    final total = paths.length;
    final show = paths.take(4).toList();
    const double radius = 8;
    final double screenWidth = MediaQuery.of(context).size.width;
    // best-effort estimate for available width inside cards/padding
    final double availableWidth = screenWidth - 24; // outer padding approx
    final double dpr = MediaQuery.of(context).devicePixelRatio;


    Widget buildThumb(int index, {BorderRadius? br, required double targetWidth, required double targetHeight}) {
      final cacheWidth = (targetWidth * dpr).clamp(256, 2048).round();
      final image = Image.file(
        File(show[index]),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        cacheWidth: cacheWidth,
      );
      final child = ClipRRect(
        borderRadius: br ?? BorderRadius.circular(radius),
        child: RepaintBoundary(child: image),
      );
      final tile = child;
      return LongPressDraggable<int>(
        data: index,
        feedback: Material(
            color: Colors.transparent,
            child: SizedBox(width: targetWidth, height: targetHeight, child: child)),
        childWhenDragging: Opacity(opacity: 0.6, child: tile),
        child: DragTarget<int>(
          builder: (context, candidate, rejected) => tile,
          onAcceptWithDetails: (details) {
            // Reorder within composer list
            final vm = context.read<SocialViewModel>();
            final from = details.data;
            if (vm.pendingImagePaths.length >= index + 1 && vm.pendingImagePaths.length >= from + 1) {
              vm.reorderPendingImages(from, index);
            }
          },
        ),
      );
    }

    if (show.length == 1) {
      final w = availableWidth;
      final h = w * 3 / 4;
      return SizedBox(
        width: w,
        height: h,
        child: buildThumb(0, targetWidth: w, targetHeight: h),
      );
    }

    if (show.length == 2) {
      final h = 200.0;
      final w = (availableWidth - 6) / 2;
      return SizedBox(
        height: h,
        child: Row(
          children: [
            Expanded(child: buildThumb(0, br: BorderRadius.circular(radius), targetWidth: w, targetHeight: h)),
            const SizedBox(width: 6),
            Expanded(child: buildThumb(1, br: BorderRadius.circular(radius), targetWidth: w, targetHeight: h)),
          ],
        ),
      );
    }

    if (show.length == 3) {
      final h = 220.0;
      final leftW = (availableWidth - 6) * 2 / 3;
      final rightW = (availableWidth - 6) / 3;
      return SizedBox(
        height: h,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: buildThumb(0, br: BorderRadius.circular(radius), targetWidth: leftW, targetHeight: h),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Expanded(
                      child: buildThumb(1, br: BorderRadius.circular(radius), targetWidth: rightW, targetHeight: h / 2 - 3)),
                  const SizedBox(height: 6),
                  Expanded(
                      child: buildThumb(2, br: BorderRadius.circular(radius), targetWidth: rightW, targetHeight: h / 2 - 3)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 4 or more => 2x2 grid with +N overlay on last tile
    final extra = total - 4;
    final h = 240.0;
    final cellW = (availableWidth - 6) / 2;
    final cellH = (h - 6) / 2;
    return SizedBox(
      height: h,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: buildThumb(0, br: BorderRadius.circular(radius), targetWidth: cellW, targetHeight: cellH)),
                const SizedBox(width: 6),
                Expanded(child: buildThumb(1, br: BorderRadius.circular(radius), targetWidth: cellW, targetHeight: cellH)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              children: [
                Expanded(child: buildThumb(2, br: BorderRadius.circular(radius), targetWidth: cellW, targetHeight: cellH)),
                const SizedBox(width: 6),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      buildThumb(3, br: BorderRadius.circular(radius), targetWidth: cellW, targetHeight: cellH),
                      if (extra > 0)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(radius),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '+$extra',
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* =========================
 * Image Viewer
 * ========================= */

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
