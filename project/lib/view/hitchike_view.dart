// lib/view/hitchike_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project/widgets/custom_appbar.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'create_hitchike_view.dart';
import 'hitchike_post_detail_view.dart';
import '../viewmodel/hitchike_viewmodel.dart';

class HitchikeView extends StatefulWidget {
  const HitchikeView({super.key});

  @override
  State<HitchikeView> createState() => _HitchikeViewState();
}

class _HitchikeViewState extends State<HitchikeView> {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  bool _bootstrapped = false; // guard

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      context.read<HitchikeViewModel>().searchPosts(_searchController.text);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _bootstrapped) return;
      _bootstrapped = true;
      context.read<HitchikeViewModel>().refreshPosts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) _searchController.clear();
    });
  }

  Future<void> _doRefresh() async {
    await context.read<HitchikeViewModel>().refreshPosts();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: HCAppBar(
        automaticallyImplyLeading: false,
        backgroundColor: theme.appBarTheme.backgroundColor ?? cs.surface,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.appBarTheme.foregroundColor ?? cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleWidget: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search rides...',
                  border: InputBorder.none,
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: (theme.appBarTheme.foregroundColor ?? cs.onSurface).withOpacity(0.6),
                  ),
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.appBarTheme.foregroundColor ?? cs.onSurface,
                  fontSize: 16,
                ),
              )
            : Text(
                'Hitchhike',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.appBarTheme.foregroundColor ?? cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'My Posts',
            icon: Icon(Icons.inventory_2_outlined,
                color: theme.appBarTheme.foregroundColor ?? cs.onSurface),
            onPressed: () {
              final me = Supabase.instance.client.auth.currentUser?.id;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _MyHitchikePostsView(myUserId: me),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.search, color: theme.appBarTheme.foregroundColor ?? cs.onSurface),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: Icon(Icons.add, color: theme.appBarTheme.foregroundColor ?? cs.onSurface),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateHitchikeView()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            'Posts',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onBackground,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Consumer<HitchikeViewModel>(
              builder: (context, vm, _) {
                if (vm.isLoading) {
                  return RefreshIndicator(
                    color: cs.primary,
                    backgroundColor: cs.surface,
                    onRefresh: _doRefresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemCount: 6,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, __) => Container(
                        height: 64,
                        decoration: BoxDecoration(
                          color: cs.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  );
                }

                if (vm.posts.isEmpty) {
                  return RefreshIndicator(
                    color: cs.primary,
                    backgroundColor: cs.surface,
                    onRefresh: _doRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            'No hitchike posts yet.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: cs.primary,
                  backgroundColor: cs.surface,
                  onRefresh: _doRefresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: vm.posts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final p = vm.posts[i];
                      final fuelText = (p.fuelShared == 1)
                          ? 'Fuel will be shared'
                          : 'Fuel will not be shared';

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HitchikeDetailView(post: p),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cs.surfaceVariant, // tema-uyumlu kart arka planı
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: cs.secondaryContainer,
                                backgroundImage: (p.ownerImageUrl != null &&
                                        p.ownerImageUrl!.isNotEmpty)
                                    ? NetworkImage(p.ownerImageUrl!)
                                    : null,
                                child: (p.ownerImageUrl == null ||
                                        p.ownerImageUrl!.isEmpty)
                                    ? Icon(Icons.person, size: 20, color: cs.onSecondaryContainer)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // From - To
                                    Text(
                                      '${p.fromLocation} - ${p.toLocation}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    // Date / Time
                                    Text(
                                      '${p.dateTime.day}/${p.dateTime.month}, '
                                      '${p.dateTime.hour.toString().padLeft(2, '0')}:'
                                      '${p.dateTime.minute.toString().padLeft(2, '0')}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    // Fuel
                                    Text(
                                      fuelText,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Owner name (soluk)
                              Opacity(
                                opacity: .75,
                                child: Text(
                                  p.ownerName ?? '',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================
///       MY HITCHIKE POSTS
/// ============================
class _MyHitchikePostsView extends StatelessWidget {
  final String? myUserId;
  const _MyHitchikePostsView({required this.myUserId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final vm = context.read<HitchikeViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Posts',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.appBarTheme.foregroundColor ?? cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor ?? cs.surface,
        foregroundColor: theme.appBarTheme.foregroundColor ?? cs.onSurface,
        elevation: 1,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => vm.refreshPosts(),
          ),
        ],
      ),
      body: Consumer<HitchikeViewModel>(
        builder: (context, viewModel, _) {
          if (myUserId == null || myUserId!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'You need to sign in to see your posts.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface),
                ),
              ),
            );
          }

          final myPosts =
              viewModel.posts.where((p) => p.ownerId == myUserId).toList();

          if (viewModel.isLoading) {
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, __) => Container(
                height: 64,
                decoration: BoxDecoration(
                  color: cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }

          if (myPosts.isEmpty) {
            return RefreshIndicator(
              color: cs.primary,
              backgroundColor: cs.surface,
              onRefresh: () => viewModel.refreshPosts(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      "You don't have any posts yet.",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: cs.primary,
            backgroundColor: cs.surface,
            onRefresh: () => viewModel.refreshPosts(),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: myPosts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final p = myPosts[i];
                return Slidable(
                  key: ValueKey(p.id),
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (context) async {
                          await viewModel.deletePost(p.id);
                        },
                        backgroundColor: cs.error,
                        foregroundColor: cs.onError,
                        icon: Icons.delete,
                        label: 'Delete',
                      ),
                    ],
                  ),
                  child: ListTile(
                    tileColor: cs.surfaceVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: Text(
                      'From ${p.fromLocation} - ${p.toLocation} at ${p.dateTime}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface),
                    ),
                    subtitle: Text(
                      (p.fuelShared == 1)
                          ? 'Fuel will be shared'
                          : 'Fuel will not be shared',
                      style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HitchikeDetailView(post: p),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
