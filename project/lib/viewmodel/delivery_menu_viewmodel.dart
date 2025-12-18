import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class Restaurant {
  final String id;
  final String name;
  final String? phoneNumber;
  final String? description;
  final Map<String, String>? workingHours;
  final String? logoUrl;
  final List<String> menuUrls;
  final double averageRating;
  final int totalRatings;

  Restaurant({
    required this.id,
    required this.name,
    this.phoneNumber,
    this.description,
    this.workingHours,
    this.logoUrl,
    required this.menuUrls,
    this.averageRating = 0.0,
    this.totalRatings = 0,
  });

  factory Restaurant.fromMap(Map<String, dynamic> map) {
    Map<String, String>? workingHours;
    if (map['working_hours'] != null) {
      try {
        if (map['working_hours'] is String) {
          final decoded = json.decode(map['working_hours']);
          workingHours = Map<String, String>.from(decoded);
        } else if (map['working_hours'] is Map) {
          workingHours = Map<String, String>.from(map['working_hours']);
        }
      } catch (e) {
        debugPrint('Error parsing working hours: $e');
      }
    }

    return Restaurant(
      id: map['id'] as String,
      name: map['name'] as String,
      phoneNumber: map['phone_number'] as String?,
      description: map['description'] as String?,
      workingHours: workingHours,
      logoUrl: map['logo_url'] as String?,
      menuUrls: List<String>.from(map['menu_urls'] ?? []),
      averageRating: (map['average_rating'] ?? 0.0).toDouble(),
      totalRatings: (map['total_ratings'] ?? 0) as int,
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

  static Future<Restaurant> fetchRestaurantWithRating(String restaurantId) async {
    final supabase = Supabase.instance.client;
    
    // Fetch restaurant data
    final restaurantData = await supabase
        .from('restaurants')
        .select()
        .eq('id', restaurantId)
        .single();

    // Fetch ratings
    final ratingsData = await supabase
        .from('restaurant_reviews')
        .select('rating')
        .eq('restaurant_id', restaurantId);

    double avgRating = 0.0;
    int totalRatings = 0;

    if (ratingsData.isNotEmpty) {
      totalRatings = ratingsData.length;
      final sum = ratingsData.fold<double>(
        0.0,
        (prev, curr) => prev + (curr['rating'] as num).toDouble(),
      );
      avgRating = sum / totalRatings;
    }

    Map<String, String>? workingHours;
    if (restaurantData['working_hours'] != null) {
      try {
        if (restaurantData['working_hours'] is String) {
          final decoded = json.decode(restaurantData['working_hours']);
          workingHours = Map<String, String>.from(decoded);
        } else if (restaurantData['working_hours'] is Map) {
          workingHours = Map<String, String>.from(restaurantData['working_hours']);
        }
      } catch (e) {
        debugPrint('Error parsing working hours: $e');
      }
    }

    return Restaurant(
      id: restaurantData['id'] as String,
      name: restaurantData['name'] as String,
      phoneNumber: restaurantData['phone_number'] as String?,
      description: restaurantData['description'] as String?,
      workingHours: workingHours,
      logoUrl: restaurantData['logo_url'] as String?,
      menuUrls: List<String>.from(restaurantData['menu_urls'] ?? []),
      averageRating: avgRating,
      totalRatings: totalRatings,
    );
  }

  static Future<int?> getUserRating(String restaurantId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await Supabase.instance.client
          .from('restaurant_reviews')
          .select('rating')
          .eq('restaurant_id', restaurantId)
          .eq('user_id', userId)
          .maybeSingle();

      return response?['rating'] as int?;
    } catch (e) {
      debugPrint('Error fetching user rating: $e');
      return null;
    }
  }

  static Future<void> submitRating(String restaurantId, int rating) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await Supabase.instance.client.from('restaurant_reviews').upsert(
      {
        'restaurant_id': restaurantId,
        'user_id': userId,
        'rating': rating,
        'created_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'restaurant_id,user_id',
    );
  }
}
