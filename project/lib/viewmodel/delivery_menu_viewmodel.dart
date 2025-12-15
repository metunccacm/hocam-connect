import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Restaurant {
  final String id;
  final String name;
  final String? phoneNumber;
  final String? description;
  final String? workingHours;
  final String? logoUrl;
  final List<String> menuUrls;

  Restaurant({
    required this.id,
    required this.name,
    this.phoneNumber,
    this.description,
    this.workingHours,
    this.logoUrl,
    required this.menuUrls,
  });

  factory Restaurant.fromMap(Map<String, dynamic> map) {
    return Restaurant(
      id: map['id'] as String,
      name: map['name'] as String,
      phoneNumber: map['phone_number'] as String?,
      description: map['description'] as String?,
      workingHours: map['working_hours'] as String?,
      logoUrl: map['logo_url'] as String?,
      menuUrls: List<String>.from(map['menu_urls'] ?? []),
    );
  }
}

class DeliveryMenuViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<Restaurant> _restaurants = [];
  List<Restaurant> get restaurants => _restaurants;

  DeliveryMenuViewModel() {
    fetchRestaurants();
  }

  Future<void> fetchRestaurants() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('restaurants')
          .select()
          .order('name', ascending: true);

      final data = response as List<dynamic>;
      _restaurants = data.map((e) => Restaurant.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error fetching restaurants: $e');
      _errorMessage = 'Failed to load restaurants. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
