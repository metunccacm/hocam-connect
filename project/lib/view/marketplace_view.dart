import 'package:flutter/material.dart';
import 'package:project/widgets/custom_appbar.dart';
import 'package:project/view/additem_view.dart';
import 'package:project/view/category_view.dart';
import 'package:project/view/product_detail_view.dart';
import 'package:provider/provider.dart';
import 'package:project/viewmodel/marketplace_viewmodel.dart';
import '../models/product.dart';

// 🧩 Cache & Shimmer paketleri
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shimmer/shimmer.dart';

// 🔐 current user id
import 'package:supabase_flutter/supabase_flutter.dart';

// 👇 NEW
import 'package:flutter_slidable/flutter_slidable.dart';

class MarketplaceView extends StatefulWidget {
  const MarketplaceView({super.key});

  @override
  State<MarketplaceView> createState() => _MarketplaceViewState();
}

// 🔒 Özel Cache Manager (disk önbellek, TTL, limit)
class _MarketplaceImageCacheManager extends CacheManager {
  static const key = 'marketplace_images_cache';
  _MarketplaceImageCacheManager()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 7),
            maxNrOfCacheObjects: 300,
            repo: JsonCacheInfoRepository(databaseName: key),
            fileService: HttpFileService(),
          ),
        );
}

class _MarketplaceViewState extends State<MarketplaceView> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  static final _cacheManager = _MarketplaceImageCacheManager();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      Provider.of<MarketplaceViewModel>(context, listen: false)
          .searchProducts(_searchController.text);
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
      if (!_isSearching) {
        _searchController.clear();
      }
    });
  }

  Widget _shimmerRect({double borderRadius = 0, double? width, double? height}) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE6E6E6),
      highlightColor: const Color(0xFFF5F5F5),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  Widget _shimmerCircle({double size = 24}) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE6E6E6),
      highlightColor: const Color(0xFFF5F5F5),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFFE0E0E0),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Future<void> _doRefresh(BuildContext context) async {
    await Provider.of<MarketplaceViewModel>(context, listen: false)
        .refreshProducts();
  }

  List<Product> _flattenAll(Map<String, List<Product>> grouped) {
    final out = <Product>[];
    for (final kv in grouped.entries) {
      out.addAll(kv.value);
    }
    return out;
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        titleWidget: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search products...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.black54),
                ),
                style: const TextStyle(color: Colors.black, fontSize: 16),
              )
            : const Text('Marketplace', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: _toggleSearch,
            )
          else ...[
            Consumer<MarketplaceViewModel>(
              builder: (context, vm, _) {
                return IconButton(
                  tooltip: 'My Posts',
                  icon: const Icon(Icons.inventory_2_outlined, color: Colors.black),
                  onPressed: () {
                    final me = Supabase.instance.client.auth.currentUser?.id;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MyItemsView(
                          myUserId: me,
                          allProducts: _flattenAll(vm.groupedProducts),
                          cacheManager: _cacheManager,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.search, color: Colors.black),
              onPressed: _toggleSearch,
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh, color: Colors.black),
              onPressed: () => _doRefresh(context),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.black),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddItemView()),
                );
              },
            ),
          ]
        ],
      ),
      body: Column(
        children: [
          _buildFilterAndSortControls(),
          Expanded(
            child: Consumer<MarketplaceViewModel>(
              builder: (context, viewModel, child) {
                if (viewModel.isLoading) {
                  return RefreshIndicator(
                    onRefresh: () => _doRefresh(context),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemCount: 3,
                      itemBuilder: (_, __) =>
                          _shimmerRect(height: 220, borderRadius: 12),
                    ),
                  );
                }

                if (viewModel.groupedProducts.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => _doRefresh(context),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No products found.')),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => _doRefresh(context),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: viewModel.groupedProducts.keys.length,
                    itemBuilder: (context, index) {
                      final category =
                          viewModel.groupedProducts.keys.elementAt(index);
                      final products =
                          viewModel.groupedProducts[category]!;
                      return _buildCategorySection(category, products);
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

  Widget _buildCategorySection(String category, List<Product> products) {
    final coverOrPlaceholder = (List<String> urls) =>
        urls.isNotEmpty ? urls.first : 'https://via.placeholder.com/400x300?text=No+Image';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoryView(
                        categoryName: category,
                        products: products,
                      ),
                    ),
                  );
                },
                child: Text(
                  'See more',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final p = products[index];
              final cover = coverOrPlaceholder(p.imageUrls);
              return SizedBox(
                width: 180,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProductDetailView(product: p)),
                    );
                  },
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    margin: const EdgeInsets.all(4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            color: const Color(0xFFEAF2FF),
                            child: CachedNetworkImage(
                              imageUrl: cover,
                              cacheManager: _MarketplaceViewState._cacheManager,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (context, url) =>
                                  _shimmerRect(borderRadius: 0),
                              errorWidget: (_, __, ___) =>
                                  const Center(
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Colors.grey,
                                      size: 40,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          child: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
                          child: Text(
                            '${p.currency == 'TL' ? '₺' : p.currency == 'USD' ? '\$' : '€'}${p.price.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: Row(
                            children: [
                              if (p.sellerImageUrl.isNotEmpty)
                                ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: p.sellerImageUrl,
                                    cacheManager: _MarketplaceViewState._cacheManager,
                                    width: 24,
                                    height: 24,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => _shimmerCircle(size: 24),
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.person,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              else
                                const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Color(0xFFE0E0E0),
                                  child: Icon(Icons.person, size: 14, color: Colors.grey),
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  p.sellerName,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterAndSortControls() {
    return Consumer<MarketplaceViewModel>(
      builder: (context, viewModel, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                onPressed: () => _showFilterDialog(viewModel),
                icon: const Icon(Icons.filter_list, size: 20),
                label: const Text('Filter'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                onPressed: () => _showSortDialog(viewModel),
                icon: const Icon(Icons.sort, size: 20),
                label: const Text('Sort'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSortDialog(MarketplaceViewModel viewModel) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sort'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<SortOption>(
                title: const Text('Newest'),
                value: SortOption.newest,
                groupValue: viewModel.currentSortOption,
                onChanged: (v) { if (v != null) { viewModel.sortProducts(v); Navigator.pop(dialogContext); } },
              ),
              RadioListTile<SortOption>(
                title: const Text('Price: Low to High'),
                value: SortOption.priceAsc,
                groupValue: viewModel.currentSortOption,
                onChanged: (v) { if (v != null) { viewModel.sortProducts(v); Navigator.pop(dialogContext); } },
              ),
              RadioListTile<SortOption>(
                title: const Text('Price: High to Low'),
                value: SortOption.priceDesc,
                groupValue: viewModel.currentSortOption,
                onChanged: (v) { if (v != null) { viewModel.sortProducts(v); Navigator.pop(dialogContext); } },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFilterDialog(MarketplaceViewModel viewModel) {
    final Set<String> tempSelected = Set.from(viewModel.activeFilters);
    final options = viewModel.allCategories;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filter by Category'),
              content: options.isEmpty
                  ? const Text('No categories.')
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: options.map((category) {
                          return CheckboxListTile(
                            title: Text(category),
                            value: tempSelected.contains(category),
                            onChanged: (bool? selected) {
                              setDialogState(() {
                                if (selected == true) {
                                  tempSelected.add(category);
                                } else {
                                  tempSelected.remove(category);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    viewModel.applyFilters(tempSelected);
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// ====================================================================
///                          MY ITEMS VIEW
/// ====================================================================

class MyItemsView extends StatelessWidget {
  final String? myUserId;
  final List<Product> allProducts;
  final BaseCacheManager cacheManager;

  const MyItemsView({
    super.key,
    required this.myUserId,
    required this.allProducts,
    required this.cacheManager,
  });

  Widget _shimmerRect({double? height}) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE6E6E6),
      highlightColor: const Color(0xFFF5F5F5),
      child: Container(height: height ?? 160, color: const Color(0xFFE0E0E0)),
    );
  }

  // === Helpers for deleting product + storage ===

  String? _extractStorageKey(String url) {
    const pub = '/object/public/marketplace/';
    const sig = '/object/sign/marketplace/';
    final iPub = url.indexOf(pub);
    if (iPub != -1) return url.substring(iPub + pub.length);
    final iSig = url.indexOf(sig);
    if (iSig != -1) {
      final rest = url.substring(iSig + sig.length);
      return rest.split('?').first;
    }
    return null;
  }

  Future<void> _tryDeleteFromUrls(List<String> urls) async {
    final keys = <String>[];
    for (final u in urls) {
      final k = _extractStorageKey(u);
      if (k != null && k.isNotEmpty) keys.add(k);
    }
    if (keys.isEmpty) return;
    try {
      await Supabase.instance.client.storage.from('marketplace').remove(keys);
    } catch (_) {/* not critical */}
  }

  Future<void> _deleteProductEverywhere(Product p) async {
    final supa = Supabase.instance.client;

    // Always fetch current image URLs from DB
    final rows = await supa
        .from('marketplace_images')
        .select('url')
        .eq('product_id', p.id);

    final urls = <String>[];
    if (rows is List) {
      for (final r in rows) {
        final u = (r as Map<String, dynamic>)['url']?.toString();
        if (u != null && u.isNotEmpty) urls.add(u);
      }
    } else {
      urls.addAll(p.imageUrls);
    }

    await _tryDeleteFromUrls(urls);
    await supa.from('marketplace_images').delete().eq('product_id', p.id);
    await supa.from('marketplace_products').delete().eq('id', p.id);
  }

  Future<void> _confirmAndMarkAsSold(BuildContext context, Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark as sold?'),
        content: const Text('This will remove the product and its images permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Mark as sold')),
        ],
      ),
    );
    if (ok != true) return;

    final vm = context.read<MarketplaceViewModel>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _deleteProductEverywhere(p);
      await vm.refreshProducts();
      messenger.showSnackBar(const SnackBar(content: Text('Listing marked as sold.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _confirmAndDelete(BuildContext context, Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This will permanently delete the post and its images.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    final vm = context.read<MarketplaceViewModel>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _deleteProductEverywhere(p);
      await vm.refreshProducts();
      messenger.showSnackBar(const SnackBar(content: Text('Post deleted.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<MarketplaceViewModel>();

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
            onPressed: () => vm.refreshProducts(),
          ),
        ],
      ),
      body: Consumer<MarketplaceViewModel>(
        builder: (context, viewModel, _) {
          if (myUserId == null || myUserId!.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('You need to sign in to see your posts.'),
              ),
            );
          }

          final all = <Product>[];
          viewModel.groupedProducts.forEach((_, list) => all.addAll(list));
          final myItems = all.where((p) => p.sellerId == myUserId).toList();

          if (viewModel.isLoading) {
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: 6,
              itemBuilder: (_, __) => _shimmerRect(height: 160),
            );
          }

          if (myItems.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => viewModel.refreshProducts(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text("You don't have any posts yet.")),
                ],
              ),
            );
          }

          // 👇 Slidable list with actions
          return RefreshIndicator(
            onRefresh: () => viewModel.refreshProducts(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              itemCount: myItems.length,
              itemBuilder: (context, i) {
                final p = myItems[i];
                final cover = p.imageUrls.isNotEmpty
                    ? p.imageUrls.first
                    : 'https://via.placeholder.com/400x300?text=No+Image';
                final price = '${p.currency == 'TL' ? '₺' : p.currency == 'USD' ? '\$' : '€'}${p.price.toStringAsFixed(2)}';

                return Slidable(
                  key: ValueKey('myitem_${p.id}'),
                  closeOnScroll: true,
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.52, // two actions, ~26% each
                    children: [
                      SlidableAction(
                        onPressed: (_) => _confirmAndMarkAsSold(context, p),
                        icon: Icons.check_circle_outline,
                        label: 'Sold',
                        backgroundColor: const Color(0xFF2ECC71),
                        foregroundColor: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      SlidableAction(
                        onPressed: (_) => _confirmAndDelete(context, p),
                        icon: Icons.delete_outline,
                        label: 'Delete',
                        backgroundColor: const Color(0xFFE74C3C),
                        foregroundColor: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ],
                  ),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    elevation: 2,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ProductDetailView(product: p)),
                        );
                      },
                      child: SizedBox(
                        height: 100,
                        child: Row(
                          children: [
                            AspectRatio(
                              aspectRatio: 1,
                              child: CachedNetworkImage(
                                imageUrl: cover,
                                cacheManager: cacheManager,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _shimmerRect(),
                                errorWidget: (_, __, ___) =>
                                    const Center(child: Icon(Icons.image_not_supported_outlined)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(price, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const Spacer(),
                                    Text(
                                      p.category,
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
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
