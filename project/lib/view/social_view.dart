import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;

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
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
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
    // Show when scrolled some distance and menu is closed
    final shouldShow = _scrollController.hasClients &&
        _scrollController.offset > 200 &&
        _animationController.isDismissed;
    if (shouldShow != _showQuickCompose) {
      setState(() {
        _showQuickCompose = shouldShow;
      });
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
              title: const Text('Hocam Connect', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
              centerTitle: true,
              actions: [
                IconButton(
                  tooltip: 'Bildirimler',
                  onPressed: () {
                    Navigator.pushNamed(context, '/notifications');
                  },
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
              child: Column(
                children: const [
                  SizedBox(height: 8),
                ],
              ),
            ),
            if (vm.isLoading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
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
                  childCount: 6,
                ),
              )
            else ...[
              // Inline composer removed; posts start immediately
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _PostTile(post: vm.feed[i]),
                  childCount: vm.feed.length,
                ),
              ),
            ],
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
                      _SocialBottomItem(icon: Icons.home, label: 'Home', onTap: () => Navigator.pushReplacementNamed(context, '/home')),
                      _SocialBottomItem(icon: Icons.storefront, label: 'Marketplace', onTap: () => Navigator.pushReplacementNamed(context, '/home')),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _SocialBottomItem(icon: Icons.chat_bubble_outline, label: 'Chats', onTap: () => Navigator.pushReplacementNamed(context, '/home')),
                      _SocialBottomItem(icon: Icons.star_border, label: 'TWOC', onTap: () => Navigator.pushReplacementNamed(context, '/home')),
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

  // This widget builds the arc menu.
  Widget _buildMenuOverlay() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final animationValue =
            CurvedAnimation(parent: _animationController, curve: Curves.easeOut)
                .value;
        // The menu is only visible when the animation is running or completed
        if (animationValue == 0) return const SizedBox.shrink();

        return Positioned.fill(
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.hardEdge,
            children: [
              // Full-screen GestureDetector to close the menu
              GestureDetector(
                onTap: _toggleMenu,
                child: Container(
                  color: Colors.black.withOpacity(0.3 * animationValue),
                ),
              ),
              // GPA Calculator
              _buildMenuItem(
                icon: Icons.calculate_outlined,
                heroTag: 'menu_calc',
                angle: -135, // Top-left
                animationValue: animationValue,
                onPressed: () {
                  _toggleMenu();
                  Navigator.pushNamed(context, '/gpa_calculator');
                },
              ),
              // Settings
              _buildMenuItem(
                icon: Icons.settings,
                heroTag: 'menu_settings',
                angle: -90, // Top-center
                animationValue: animationValue,
                onPressed: () {
                  _toggleMenu();
                  Navigator.pushNamed(context, '/settings');
                },
              ),
              // Hitchhike
              _buildMenuItem(
                icon: Icons.directions_car_outlined,
                heroTag: 'menu_hitch',
                angle: -45, // Top-right
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

  // Helper to build and position each individual menu button
  Widget _buildMenuItem({
    required IconData icon,
    required String heroTag,
    required double angle,
    required double animationValue,
    required VoidCallback onPressed,
  }) {
    final radius = 80.0; // Same radius as bottombar_view.dart
    final x = radius * math.cos(angle * math.pi / 180);
    final y = radius * math.sin(angle * math.pi / 180);

    return Positioned(
      bottom: - y, // Position above the FAB - same as bottombar_view.dart
      left: MediaQuery.of(context).size.width / 2 - 20 + x, // Center horizontally - same as bottombar_view.dart
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

// _FeedShimmer removed (unused)

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
    final combined = RegExp(r'(@|#)([A-Za-z0-9_ğüşöçıİĞÜŞÖÇ]+)');
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
              Navigator.pushNamed(context, '/user-profile', arguments: {'userId': id.isEmpty ? value : id, 'repo': vm.repository});
            }),
        ));
      } else {
        // hashtag
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
  List<SocialUser> _suggestions = const [];
  List<String> _hashtagSuggestions = const [];
  String? _linkPreviewUrl;

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
          Card(
            elevation: 3,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: CompositedTransformTarget(
                link: _layerLink,
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    Builder(
                      builder: (context) {
                        final displayName = vm.userName(vm.meId);
                        final hint = vm.isEditing
                            ? 'Gönderiyi düzenle...'
                            : (displayName == 'Kullanıcı' || displayName.isEmpty
                                ? 'Ne düşünüyorsun?'
                                : 'Ne düşünüyorsun, $displayName...');
                        return TextField(
                          controller: vm.composerController,
                          minLines: 3,
                          maxLines: 8,
                          decoration: InputDecoration(
                            hintText: hint,
                            hintStyle: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: (t) async {
                            setState(() {});
                            final at = t.lastIndexOf('@');
                            if (at >= 0) {
                              final q = t.substring(at + 1).split(RegExp(r'\s')).first;
                              if (q.isNotEmpty) {
                                _suggestions = await context.read<SocialViewModel>().mentionSuggestions(q);
                                _showMentions();
                              } else {
                                _hideMentions();
                              }
                            } else {
                              _hideMentions();
                            }

                            // hashtag suggestions
                            final hash = t.lastIndexOf('#');
                            if (hash >= 0) {
                              final q = t.substring(hash + 1).split(RegExp(r'\s')).first;
                              if (q.isNotEmpty) {
                                _hashtagSuggestions = context.read<SocialViewModel>().hashtagSuggestions(q);
                              } else {
                                _hashtagSuggestions = const [];
                              }
                            } else {
                              _hashtagSuggestions = const [];
                            }

                            // link preview detection (simple)
                            final urlMatch = RegExp(r'(https?:\/\/[^\s]+)').firstMatch(t);
                            _linkPreviewUrl = urlMatch?.group(0);
                          },
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: vm.isPosting || !canPost ? Colors.grey.shade300 : Colors.blue.shade100,
                        child: IconButton(
                          icon: Icon(
                            Icons.send,
                            color: vm.isPosting || !canPost ? Colors.grey.shade500 : Colors.blue.shade700,
                            size: 20,
                          ),
                          onPressed: vm.isPosting || !canPost
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
                        ),
                      ),
                    ),
                    if (vm.isPosting)
                      const Positioned(
                        right: 12,
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (vm.pendingImagePaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ImagesGrid(paths: vm.pendingImagePaths),
          ],
          if (_linkPreviewUrl != null) ...[
            const SizedBox(height: 8),
            _LinkPreviewCard(url: _linkPreviewUrl!),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, right: 4),
              child: Text('${vm.composerController.text.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ),
          Row(
            children: [
              _MediaAction(icon: Icons.photo_outlined, label: 'Gallery', onTap: _pickImages),
              // Only the inline send icon is kept; removed duplicate bottom share button
            ],
          ),

          if (_hashtagSuggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                children: [
                  for (final tag in _hashtagSuggestions)
                    ActionChip(
                      label: Text('#$tag'),
                      onPressed: () {
                        final ctrl = widget.vm.composerController;
                        final text = ctrl.text;
                        final hash = text.lastIndexOf('#');
                        final before = text.substring(0, hash + 1);
                        final after = text.substring(hash + 1);
                        final rest = after.contains(' ')
                            ? after.substring(after.indexOf(' '))
                            : '';
                        ctrl.text = '$before$tag$rest ';
                        ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
                        setState(() { _hashtagSuggestions = const []; });
                      },
                    )
                ],
              ),
            ),
          ],
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
    final total = paths.length;
    final show = paths.take(4).toList();
    const double radius = 8;
    final double screenWidth = MediaQuery.of(context).size.width;
    // best-effort estimate for available width inside cards/padding
    final double availableWidth = screenWidth - 24; // outer padding approx
    final double dpr = MediaQuery.of(context).devicePixelRatio;

    void openViewer(int index) {
      if (!enableViewer) return;
      showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder: (_) => _ImageViewer(paths: paths, initialIndex: index),
      );
    }

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
      final tile = GestureDetector(onTap: () => openViewer(index), child: child);
      final reorderable = LongPressDraggable<int>(
        data: index,
        feedback: Material(color: Colors.transparent, child: SizedBox(width: targetWidth, height: targetHeight, child: child)),
        childWhenDragging: Opacity(opacity: 0.6, child: tile),
        child: DragTarget<int>(
          builder: (context, candidate, rejected) => tile,
          onAccept: (from) {
            // Reorder within composer list if enabled via vm
            final vm = context.read<SocialViewModel>();
            if (!enableViewer && vm.pendingImagePaths.length >= index + 1 && vm.pendingImagePaths.length >= from + 1) {
              vm.reorderPendingImages(from, index);
            }
          },
        ),
      );
      return enableViewer ? tile : reorderable;
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
                  Expanded(child: buildThumb(1, br: BorderRadius.circular(radius), targetWidth: rightW, targetHeight: h / 2 - 3)),
                  const SizedBox(height: 6),
                  Expanded(child: buildThumb(2, br: BorderRadius.circular(radius), targetWidth: rightW, targetHeight: h / 2 - 3)),
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

class _LinkPreviewCard extends StatelessWidget {
  final String url;
  const _LinkPreviewCard({required this.url});
  @override
  Widget build(BuildContext context) {
    // Placeholder UI; integrate real metadata fetch later
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.link, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(url, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Bağlantı önizlemesi', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MediaAction({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.grey.shade700, size: 20),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
            ],
          ),
        ),
      ),
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
                      FutureBuilder<SocialUser?>(
                        future: vm.repository.getUser(post.authorId),
                        builder: (context, snapshot) {
                          final user = snapshot.data;
                          final avatarUrl = user?.avatarUrl;
                          return CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.blue.shade100,
                            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: (avatarUrl == null || avatarUrl.isEmpty)
                                ? Icon(Icons.person, size: 18, color: Colors.blue.shade700)
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.read<SocialViewModel>().userName(post.authorId),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(context.read<SocialViewModel>().timeAgo(post.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 11)),
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
                      FutureBuilder<SocialUser?>(
                        future: context.read<SocialViewModel>().repository.getUser(first.authorId),
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
            bottom: MediaQuery.of(context).viewInsets.bottom + 4,
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
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue.shade100,
                                      backgroundImage: u.avatarUrl != null && u.avatarUrl!.isNotEmpty
                                          ? NetworkImage(u.avatarUrl!)
                                          : null,
                                      child: (u.avatarUrl == null || u.avatarUrl!.isEmpty)
                                          ? Icon(Icons.person, color: Colors.blue.shade700)
                                          : null,
                                    ),
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
                                    title: Text(vm.userName(c.authorId), style: const TextStyle(fontWeight: FontWeight.w600)),
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
                                  // Otomatik mention ekle
                                  final authorName = vm.userName(c.authorId);
                                  _replyCtrl.text = '@$authorName ';
                                  _replyCtrl.text = '@$authorName ';
                                  setState(() { _replyToCommentId = c.id; });
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
                                                title: Text(vm.userName(r.authorId), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
                                                Builder(
                                                  builder: (ctx) {
                                                    final isMine = vm.meId == r.authorId;
                                                    return PopupMenuButton<String>(
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
                                            // Yanıt butonu - yanıtların altına da yanıt yazılabilmesi için
                                            Padding(
                                              padding: const EdgeInsets.only(left: 16, bottom: 8),
                                              child: TextButton(
                                                onPressed: () async {
                                                  // Otomatik mention ekle
                                                  final authorName = vm.userName(r.authorId);
                                                  _replyCtrl.text = '@$authorName ';
                                                  setState(() { _replyToCommentId = r.id; });
                                                },
                                                child: const Text('Yanıtla'),
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
                              decoration: InputDecoration(
                                hintText: 'Yanıt yaz',
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setState(() { _replyToCommentId = null; _replyCtrl.clear(); }),
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
                          // Yanıtlanacak yorumu bul ve yanıt ekle
                          final parentComment = Comment(id: _replyToCommentId!, postId: widget.post.id, authorId: vm.meId, content: '', createdAt: DateTime.now());
                          await vm.addReply(parentComment, text);
                          _replyCtrl.clear();
                          _replyToCommentId = null;
                        }
                        setState(() {}); // refresh list
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
  final vm = context.read<SocialViewModel>();
  vm.startEditPost(post);
  
  // Open the full-screen composer for editing
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
  await context.read<SocialViewModel>().deletePostById(post.id);
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gönderi silindi.')));
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
  final vm = context.read<SocialViewModel>();
  final me = vm.meId;
  if (me == comment.authorId) return; // güvenlik

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
      title: const Text('Yorumu bildir'),
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
  // Backend hazır olduğunda Supabase tablosuna insert edeceğiz (comments_abuse_reports).
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Bildiriminiz alındı. Teşekkürler.')),
  );
}


