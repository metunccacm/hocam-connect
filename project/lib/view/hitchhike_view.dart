// lib/view/hitchike_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project/widgets/custom_appbar.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'create_hitchike_view.dart';
import 'hitchike_post_detail.dart';
import '../viewmodel/hitchike_viewmodel.dart';
import '../models/hitchike_post.dart';

class HitchikeView extends StatefulWidget {
  const HitchikeView({super.key});

  @override
  State<HitchikeView> createState() => _HitchikeViewState();
}

class _HitchikeViewState extends State<HitchikeView> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      context.read<HitchikeViewModel>().searchPosts(_searchController.text);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: HCAppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.search, color: Colors.black),
          onPressed: _toggleSearch,
        ),
        titleWidget: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search rides...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.black54),
                ),
                style: const TextStyle(color: Colors.black, fontSize: 16),
              )
            : const Text('Hitchike', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'My Posts',
            icon: const Icon(Icons.inventory_2_outlined, color: Colors.black),
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
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _doRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
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
          const Text('Posts',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
          const SizedBox(height: 8),
          Expanded(
            child: Consumer<HitchikeViewModel>(
              builder: (context, vm, _) {
                if (vm.isLoading) {
                  return RefreshIndicator(
                    onRefresh: _doRefresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemCount: 6,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, __) => Container(
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6E6E6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  );
                }

                if (vm.posts.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _doRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No hitchike posts yet.')),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _doRefresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: vm.posts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final p = vm.posts[i];
                      final fuelText =
                          (p.fuelShared == 1) ? 'Fuel will be shared' : 'Fuel will not be shared';
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HitchikePostDetail(post: p),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F6FF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(radius: 18), // avatar placeholder
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Going to ${p.toLocation}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16),
                                    ),
                                    Text(fuelText, style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Opacity(
                                opacity: .55,
                                child: Text(
                                  p.ownerName ?? '',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.image_outlined, size: 28),
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

/// ============================
///       MY HITCHIKE POSTS
/// ============================
class _MyHitchikePostsView extends StatelessWidget {
  final String? myUserId;
  const _MyHitchikePostsView({required this.myUserId});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<HitchikeViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('You need to sign in to see your posts.'),
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
                color: const Color(0xFFE6E6E6),
              ),
            );
          }

          if (myPosts.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => viewModel.refreshPosts(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text("You don't have any posts yet.")),
                ],
              ),
            );
          }

         
