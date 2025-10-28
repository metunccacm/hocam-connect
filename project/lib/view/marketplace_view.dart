import 'package:flutter/material.dart';
import 'package:project/widgets/custom_appbar.dart';
import 'package:project/view/additem_view.dart';
import 'package:project/view/category_view.dart';
import 'package:project/view/product_detail_view.dart';
import 'package:provider/provider.dart';
import 'package:project/viewmodel/marketplace_viewmodel.dart';
import '../models/product.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class MarketplaceView extends StatefulWidget {
  const MarketplaceView({super.key});

  @override
  State<MarketplaceView> createState() => _MarketplaceViewState();
}

// 🔒 Özel Cache Manager
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
      if (!_isSearching) _searchController.clear();
    });
  }

  // ——— THEME-AWARE SHIMMER HELPERS ———
  Widget _shimmerRect({double borderRadius = 0, double? width, double? height}) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.surfaceVariant.withOpacity(0.6);
    final highlight = cs.surfaceVariant.withOpacity(0.85);
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: cs.surfaceVariant,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  Widget _shimmerCircle({double size = 24}) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.surfaceVariant.withOpacity(0.6);
    final highlight = cs.surfaceVariant.withOpacity(0.85);
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.surfaceVariant,
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onSurface = cs.onSurface;

    return Scaffold(
      // ❗️Tema-tabanlı arka plan
      backgroundColor: cs.background,
      appBar: HCAppBar(
        automaticallyImplyLeading: false,
        // ❗️AppBar’ı tema ile sür
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
                  hintText: 'Search products...',
                  border: InputBorder.none,
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: onSurface.withOpacity(0.6),
                  ),
                ),
                style: theme.textTheme.bodyMedium?.copyWith(color: onSurface, fontSize: 16),
              )
            : Text('Marketplace',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.appBarTheme.foregroundColor ?? cs.onSurface,
                  fontWeight: FontWeight.w600,
                )),
        centerTitle: true,
        actions: [
          if (_isSearching)
            IconButton(
              icon: Icon(Icons.close, color: theme.appBarTheme.foregroundColor ?? cs.onSurface),
              onPressed: _toggleSearch,
            )
          else ...[
            Consumer<MarketplaceViewModel>(
              builder: (context, vm, _) {
                return IconButton(
                  tooltip: 'My Posts',
                  icon: Icon(Icons.inventory_2_outlined,
                      color: theme.appBarTheme.foregroundColor ?? cs.onSurface),
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
              icon: Icon(Icons.search, color: theme.appBarTheme.foregroundColor ?? cs.onSurface),
              onPressed: _toggleSearch,
            ),
            IconButton(
              icon: Icon(Icons.add, color: theme.appBarTheme.foregroundColor ?? cs.onSurface),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AddItemView()));
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
                    color: cs.primary,
                    backgroundColor: cs.surface,
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
                    color: cs.primary,
                    backgroundColor: cs.surface,
                    onRefresh: () => _doRefresh(context),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            'No products found.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: onSurface.withOpacity(0.8)),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: cs.primary,
                  backgroundColor: cs.surface,
                  onRefresh: () => _doRefresh(context),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: viewModel.groupedProducts.keys.length,
                    itemBuilder: (context, index) {
                      final category = viewModel.groupedProducts.keys.elementAt(index);
                      final products = viewModel.groupedProducts[category]!;
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onSurface = cs.onSurface;
    final onSurfaceVariant = cs.onSurfaceVariant;

    final coverOrPlaceholder = (List<String> urls) =>
        urls.isNotEmpty ? urls.first : 'https://via.placeholder.com/400x300?text=No+Image';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık + See more
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  )),
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Ürün kartları
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
                        // Görsel
                        Expanded(
                          child: Container(
                            color: cs.surfaceVariant, // ❗️tema uyumlu placeholder arka plan
                            child: CachedNetworkImage(
                              imageUrl: cover,
                              cacheManager: _MarketplaceViewState._cacheManager,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (context, url) => _shimmerRect(borderRadius: 0),
                              errorWidget: (_, __, ___) => Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: onSurfaceVariant,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Başlık
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          child: Text(
                            p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(color: onSurface),
                          ),
                        ),
                        // Fiyat
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
                          child: Text(
                            '${p.currency == 'TL' ? '₺' : p.currency == 'USD' ? '\$' : '€'}${p.price.toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: onSurface,
                            ),
                          ),
                        ),
                        // Satıcı satırı
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
                                    errorWidget: (_, __, ___) =>
                                        Icon(Icons.person, size: 18, color: onSurfaceVariant),
                                  ),
                                )
                              else
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: cs.surfaceVariant,
                                  child: Icon(Icons.person, size: 14, color: onSurfaceVariant),
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  p.sellerName,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: onSurfaceVariant,
                                  ),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Consumer<MarketplaceViewModel>(
      builder: (context, viewModel, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: cs.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                onPressed: () => _showFilterDialog(viewModel),
                icon: const Icon(Icons.filter_list, size: 20),
                label: const Text('Filter'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: cs.primary,
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
                onChanged: (v) {
                  if (v != null) { viewModel.sortProducts(v); Navigator.pop(dialogContext); }
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('Price: Low to High'),
                value: SortOption.priceAsc,
                groupValue: viewModel.currentSortOption,
                onChanged: (v) {
                  if (v != null) { viewModel.sortProducts(v); Navigator.pop(dialogContext); }
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('Price: High to Low'),
                value: SortOption.priceDesc,
                groupValue: viewModel.currentSortOption,
                onChanged: (v) {
                  if (v != null) { viewModel.sortProducts(v); Navigator.pop(dialogContext); }
                },
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
///                          MY ITEMS VIEW (tema uyumlu)
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

  Widget _shimmerRect(BuildContext context, {double? height}) {
    final cs = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: cs.surfaceVariant.withOpacity(0.6),
      highlightColor: cs.surfaceVariant.withOpacity(0.85),
      child: Container(height: height ?? 160, color: cs.surfaceVariant),
    );
  }

  // === Storage helpers ===
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
      builder: (_) => const AlertDialog(
        title: Text('Mark as sold?'),
        content: Text('This will remove the product and its images permanently.'),
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
      builder: (_) => const AlertDialog(
        title: Text('Delete post?'),
        content: Text('This will permanently delete the post and its images.'),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onSurface = cs.onSurface;
    final onSurfaceVariant = cs.onSurfaceVariant;

    final vm = context.read<MarketplaceViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts'),
        backgroundColor: theme.appBarTheme.backgroundColor ?? cs.surface,
        foregroundColor: theme.appBarTheme.foregroundColor ?? cs.onSurface,
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'You need to sign in to see your posts.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: onSurface),
                ),
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
              itemBuilder: (_, __) => _shimmerRect(context, height: 160),
            );
          }

          if (myItems.isEmpty) {
            return RefreshIndicator(
              color: cs.primary,
              backgroundColor: cs.surface,
              onRefresh: () => viewModel.refreshProducts(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      "You don't have any posts yet.",
                      style: theme.textTheme.bodyMedium?.copyWith(color: onSurface.withOpacity(0.8)),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: cs.primary,
            backgroundColor: cs.surface,
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
                    extentRatio: 0.52,
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
                                placeholder: (_, __) => _shimmerRect(context),
                                errorWidget: (_, __, ___) => Center(
                                  child: Icon(Icons.image_not_supported_outlined, color: onSurfaceVariant),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      price,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: onSurface,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      p.category,
                                      style: theme.textTheme.labelSmall?.copyWith(color: onSurfaceVariant),
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
