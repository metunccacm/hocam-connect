import 'package:flutter/material.dart';
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
            stalePeriod: const Duration(days: 7), // 7 gün sakla
            maxNrOfCacheObjects: 300, // en fazla 300 görsel
            repo: JsonCacheInfoRepository(databaseName: key),
            fileService: HttpFileService(),
          ),
        );
}

class _MarketplaceViewState extends State<MarketplaceView> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  // 🔁 Tekil cache manager
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

  // 🟦 Ortak shimmer dikdörtgen
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

  // 🟦 Ortak shimmer daire (avatar için)
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
    // ViewModel’de refreshProducts() yoksa: loadProducts(force: true) veya eşdeğeri yap.
    await Provider.of<MarketplaceViewModel>(context, listen: false)
        .refreshProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
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
                // 📌 Pull-to-refresh her durumda çalışsın diye AlwaysScrollable
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

                // ✅ Asıl liste: RefreshIndicator ile sarmaladık
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
                        // 🔄 Resim: Cached + Shimmer
                        Expanded(
                          child: Container(
                            color: const Color(0xFFEAF2FF),
                            child: CachedNetworkImage(
                              imageUrl: cover,
                              cacheManager: _cacheManager,
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
                              // 👤 Satıcı avatarı: Cached + Shimmer
                              if (p.sellerImageUrl.isNotEmpty)
                                ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: p.sellerImageUrl,
                                    cacheManager: _cacheManager,
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

  // 🔽 DİNAMİK KATEGORİ FİLTRESİ
  void _showFilterDialog(MarketplaceViewModel viewModel) {
    final Set<String> tempSelected = Set.from(viewModel.activeFilters);
    final options = viewModel.allCategories; // DB’den

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
