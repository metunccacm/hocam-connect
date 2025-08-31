import 'package:flutter/material.dart';
import 'package:project/view/additem_view.dart';
import 'package:project/view/category_view.dart';
import 'package:project/view/productDetail_view.dart';
import 'package:project/viewmodel/marketplace_viewmodel.dart';
import 'package:provider/provider.dart';

class MarketplaceView extends StatefulWidget {
  const MarketplaceView({super.key});

  @override
  State<MarketplaceView> createState() => _MarketplaceViewState();
}

class _MarketplaceViewState extends State<MarketplaceView> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

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
        // Clear search when closing the search bar
        _searchController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 1,
        // Conditionally build the leading icon and title
        leading: _isSearching
            ? null // Hide leading icon when searching
            : IconButton(
                icon: const Icon(Icons.search, color: Colors.black),
                onPressed: _toggleSearch,
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
            : const Text('Marketplace',
                style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: [
          // Show a clear/close button when searching
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: _toggleSearch,
            )
          else
            IconButton(
              icon: const Icon(Icons.add, color: Colors.black),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AddItemView()),
                );
              },
            )
        ],
      ),
      body: Column(
        children: [
          _buildFilterAndSortControls(),
          Expanded(
            child: Consumer<MarketplaceViewModel>(
              builder: (context, viewModel, child) {
                if (viewModel.groupedProducts.isEmpty) {
                  return const Center(child: Text('No products found.'));
                }
                // Main list of categories
                return ListView.builder(
                  itemCount: viewModel.groupedProducts.keys.length,
                  itemBuilder: (context, index) {
                    String category =
                        viewModel.groupedProducts.keys.elementAt(index);
                    List<Product> products =
                        viewModel.groupedProducts[category]!;
                    return _buildCategorySection(category, products);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Builds a single category section (e.g., "Giysiler")
  Widget _buildCategorySection(String category, List<Product> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              // WRAP THE TEXT WITH INKWELL FOR TAPPING
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
                child: Text('See more',
                    style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        // Horizontal list of products for the category
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return SizedBox(
                width: 180,
                child: GestureDetector( // <-- WRAP WITH GESTUREDETECTOR
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailView(product: product),
                      ),
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
                            child: Image.network(
                              product.imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 40)),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          child: Text(product.name, style: const TextStyle(fontWeight: FontWeight.normal), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
                          child: Text('₺${product.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        // SELLER INFO ADDED HERE
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundImage: NetworkImage(product.sellerImageUrl),
                                backgroundColor: Colors.grey.shade200,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  product.sellerName,
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
              // Filter Button
              TextButton.icon(
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onPressed: () => _showFilterDialog(viewModel),
                icon: const Icon(Icons.filter_list, size: 20),
                label: const Text('Filter'),
              ),
              // Sort Button
              TextButton.icon(
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
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
                onChanged: (value) {
                  if (value != null) {
                    viewModel.sortProducts(value);
                    Navigator.pop(dialogContext);
                  }
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('Price: Low to High'),
                value: SortOption.priceAsc,
                groupValue: viewModel.currentSortOption,
                onChanged: (value) {
                  if (value != null) {
                    viewModel.sortProducts(value);
                    Navigator.pop(dialogContext);
                  }
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('Price: High to Low'),
                value: SortOption.priceDesc,
                groupValue: viewModel.currentSortOption,
                onChanged: (value) {
                  if (value != null) {
                    viewModel.sortProducts(value);
                    Navigator.pop(dialogContext);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFilterDialog(MarketplaceViewModel viewModel) {
    final Set<String> tempSelectedCategories = Set.from(viewModel.activeFilters);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filter by Category'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: ['Clothes', 'Kitchen Items', 'Electronics'].map((category) {
                  return CheckboxListTile(
                    title: Text(category),
                    value: tempSelectedCategories.contains(category),
                    onChanged: (bool? selected) {
                      setDialogState(() {
                        if (selected == true) {
                          tempSelectedCategories.add(category);
                        } else {
                          tempSelectedCategories.remove(category);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    viewModel.applyFilters(tempSelectedCategories);
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

