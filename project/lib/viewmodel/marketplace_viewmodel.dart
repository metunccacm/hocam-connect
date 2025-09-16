import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

// A simple model for a product for demonstration purposes.
class Product {
  final String id;
  final String name;
  final double price;
  final List<String> imageUrls;
  final DateTime dateAdded;
  final String category;
  final String sellerName;
  final String sellerImageUrl;
  final String sellerId;
  final String description;
  final List<String>? sizes;
  final String? selectedSize;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrls,
    required this.dateAdded,
    required this.category,
    required this.sellerName,
    required this.sellerImageUrl,
    required this.sellerId,
    required this.description,
    this.sizes,
    this.selectedSize,
  });
}

// Enum for sorting options.
enum SortOption { priceAsc, priceDesc, newest }

class MarketplaceViewModel extends ChangeNotifier {
  // Dummy data for demonstration.
  final List<Product> _allProducts = [
  Product(
    id: '1',
    name: 'Cool Shirt',
    price: 29.99,
    imageUrls: [
      'https://images.unsplash.com/photo-1512436991641-6745cdb1723f',
      'https://images.unsplash.com/photo-1512436991641-6745cdb1723f?fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1512436991641-6745cdb1723f?fit=crop&w=600&q=80',
      'https://images.unsplash.com/photo-1512436991641-6745cdb1723f?fit=crop&w=800&q=80',
    ],
    dateAdded: DateTime.now().subtract(const Duration(days: 1)),
    category: 'Clothes',
    sellerName: 'Alice',
    sellerImageUrl: 'https://randomuser.me/api/portraits/women/1.jpg',
    sellerId: 'user_alice', // Added sellerId
    description: 'A very cool shirt for summer.',
    sizes: ['S', 'M', 'L', 'XL'],
    selectedSize: 'M',
  ),
  Product(
    id: '2',
    name: 'Modern Toaster',
    price: 49.99,
    imageUrls: [
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836',
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?fit=crop&w=400&q=80',
    ],
    dateAdded: DateTime.now().subtract(const Duration(days: 2)),
    category: 'Kitchen Items',
    sellerName: 'Bob',
    sellerImageUrl: 'https://randomuser.me/api/portraits/men/2.jpg',
    sellerId: 'user_bob', // Added sellerId
    description: 'A modern toaster for your kitchen.',
    sizes: null,
    selectedSize: null,
  ),
  Product(
    id: '3',
    name: 'Wireless Headphones',
    price: 99.99,
    imageUrls: [
      'https://images.unsplash.com/photo-1511367461989-f85a21fda167',
      'https://images.unsplash.com/photo-1511367461989-f85a21fda167?fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1511367461989-f85a21fda167?fit=crop&w=600&q=80',
    ],
    dateAdded: DateTime.now().subtract(const Duration(hours: 10)),
    category: 'Electronics',
    sellerName: 'Charlie',
    sellerImageUrl: 'https://randomuser.me/api/portraits/men/3.jpg',
    sellerId: 'user_charlie', // Added sellerId
    description: 'Noise-cancelling wireless headphones.',
    sizes: null,
    selectedSize: null,
  ),
  Product(
    id: '4',
    name: 'Elegant Dress',
    price: 59.99,
    imageUrls: [
      'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e',
      'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?fit=crop&w=400&q=80',
    ],
    dateAdded: DateTime.now().subtract(const Duration(days: 3)),
    category: 'Clothes',
    sellerName: 'Diana',
    sellerImageUrl: 'https://randomuser.me/api/portraits/women/4.jpg',
    sellerId: 'user_diana', // Added sellerId
    description: 'An elegant dress for special occasions.',
    sizes: ['S', 'M', 'L'],
    selectedSize: 'S',
  ),
];

  Map<String, List<Product>> _groupedProducts = {};
  SortOption _currentSortOption = SortOption.newest;
  Set<String> _activeFilters = {};
  String _searchQuery = ''; // For search functionality

  MarketplaceViewModel() {
    _updateProducts();
  }

  Map<String, List<Product>> get groupedProducts => _groupedProducts;
  SortOption get currentSortOption => _currentSortOption;
  Set<String> get activeFilters => _activeFilters;

  void _updateProducts() {
    List<Product> products;

    // 1. Filter by category
    if (_activeFilters.isEmpty) {
      products = List.from(_allProducts);
    } else {
      products = _allProducts
          .where((product) => _activeFilters.contains(product.category))
          .toList();
    }

    // 2. Filter by search query
    if (_searchQuery.isNotEmpty) {
      products = products
          .where((product) =>
              product.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // 3. Sort
    switch (_currentSortOption) {
      case SortOption.priceAsc:
        products.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortOption.priceDesc:
        products.sort((a, b) => b.price.compareTo(a.price));
        break;
      case SortOption.newest:
        products.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
    }

    // 4. Group
    _groupedProducts = groupBy(products, (Product p) => p.category);
    notifyListeners();
  }

  void sortProducts(SortOption option) {
    _currentSortOption = option;
    _updateProducts();
  }

  void applyFilters(Set<String> selectedCategories) {
    _activeFilters = selectedCategories;
    _updateProducts();
  }

  // Search
  void searchProducts(String query) {
    _searchQuery = query;
    _updateProducts();
  }
}