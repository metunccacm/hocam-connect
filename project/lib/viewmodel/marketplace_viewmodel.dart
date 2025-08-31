import 'package:flutter/material.dart';
import 'package:collection/collection.dart'; // Add this import

// A simple model for a product for demonstration purposes.
class Product {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final DateTime dateAdded;
  final String category;
  final String sellerName;
  final String sellerImageUrl;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.dateAdded,
    required this.category,
    required this.sellerName,
    required this.sellerImageUrl,
  });
}

// Enum for sorting options.
enum SortOption { priceAsc, priceDesc, newest }

class MarketplaceViewModel extends ChangeNotifier {
  // Dummy data for demonstration.
  final List<Product> _allProducts = [
    Product(id: '1', name: 'Vintage T-Shirt', price: 25.0, imageUrl: 'https://via.placeholder.com/150', dateAdded: DateTime(2025, 8, 28), category: 'Giysiler', sellerName: 'Fethi Başata', sellerImageUrl: 'https://i.pravatar.cc/150?u=fethi'),
    Product(id: '2', name: 'Used Textbook', price: 50.0, imageUrl: 'https://via.placeholder.com/150', dateAdded: DateTime(2025, 8, 29), category: 'Mutfak Eşyaları', sellerName: 'Mert Yıldırım', sellerImageUrl: 'https://i.pravatar.cc/150?u=mert'),
    Product(id: '3', name: 'Desk Lamp', price: 15.0, imageUrl: 'https://via.placeholder.com/150', dateAdded: DateTime(2025, 8, 25), category: 'Elektronik', sellerName: 'Karpaz', sellerImageUrl: 'https://i.pravatar.cc/150?u=karpaz'),
    Product(id: '4', name: 'Classic Jeans', price: 75.0, imageUrl: 'https://via.placeholder.com/150', dateAdded: DateTime(2025, 8, 30), category: 'Giysiler', sellerName: 'Barış', sellerImageUrl: 'https://i.pravatar.cc/150?u=baris'),
    Product(id: '5', name: 'Amazing T-shirt', price: 12.0, imageUrl: 'https://via.placeholder.com/150', dateAdded: DateTime(2025, 8, 27), category: 'Giysiler', sellerName: 'Buğra', sellerImageUrl: 'https://i.pravatar.cc/150?u=bugra'),
    Product(id: '6', name: 'Faboulous Pants', price: 15.0, imageUrl: 'https://via.placeholder.com/150', dateAdded: DateTime(2025, 8, 26), category: 'Giysiler', sellerName: 'İrem', sellerImageUrl: 'https://i.pravatar.cc/150?u=irem'),
    Product(id: '7', name: 'White Shirt', price: 120.0, imageUrl: 'https://via.placeholder.com/150', dateAdded: DateTime(2025, 8, 24), category: 'Giysiler', sellerName: 'Eser', sellerImageUrl: 'https://i.pravatar.cc/150?u=eser'),
    Product(id: '8', name: 'Heater', price: 500.0, imageUrl: 'https://via.placeholder.com/150', dateAdded: DateTime(2025, 8, 23), category: 'Elektronik', sellerName: 'Eren Başata', sellerImageUrl: 'https://i.pravatar.cc/150?u=eren'),
  ];

  Map<String, List<Product>> _groupedProducts = {};
  SortOption _currentSortOption = SortOption.newest;
  Set<String> _activeFilters = {};
  String _searchQuery = ''; // Add search query state

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