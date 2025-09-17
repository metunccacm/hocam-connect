import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../models/product.dart';
import '../services/marketplace_service.dart';

enum SortOption { priceAsc, priceDesc, newest }

class MarketplaceViewModel extends ChangeNotifier {
  final _svc = MarketplaceService();

  final List<Product> _allProducts = [];
  Map<String, List<Product>> _groupedProducts = {};
  SortOption _currentSortOption = SortOption.newest;
  Set<String> _activeFilters = {};
  String _searchQuery = '';
  bool _loading = false;

  // Dinamik kategoriler
  List<String> _allCategories = [];
  List<String> get allCategories => _allCategories;

  MarketplaceViewModel() {
    refresh();
  }

  Map<String, List<Product>> get groupedProducts => _groupedProducts;
  SortOption get currentSortOption => _currentSortOption;
  Set<String> get activeFilters => _activeFilters;
  bool get isLoading => _loading;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();

    final products = await _svc.fetchProducts(limit: 200);
    _allProducts
      ..clear()
      ..addAll(products);

    _allCategories = await _svc.fetchCategories();

    _recompute();
    _loading = false;
    notifyListeners();
  }

  void _recompute() {
    Iterable<Product> items = _allProducts;

    if (_activeFilters.isNotEmpty) {
      items = items.where((p) => _activeFilters.contains(p.category));
    }

    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((p) =>
          p.title.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.sellerName.toLowerCase().contains(q));
    }

    final list = items.toList();
    switch (_currentSortOption) {
      case SortOption.priceAsc:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortOption.priceDesc:
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case SortOption.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    _groupedProducts = groupBy(list, (Product p) => p.category);
  }

  void sortProducts(SortOption option) {
    _currentSortOption = option;
    _recompute();
    notifyListeners();
  }

  void applyFilters(Set<String> selectedCategories) {
    _activeFilters = selectedCategories;
    _recompute();
    notifyListeners();
  }

  void searchProducts(String query) {
    _searchQuery = query;
    _recompute();
    notifyListeners();
  }
}
