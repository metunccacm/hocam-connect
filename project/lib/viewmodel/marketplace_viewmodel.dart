import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MarketplaceViewModel extends ChangeNotifier {
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  List<Map<String, dynamic>> _recentlyAdded = [];
  List<Map<String, dynamic>> _oldPosts = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> get recentlyAdded => _recentlyAdded;
  List<Map<String, dynamic>> get oldPosts => _oldPosts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  MarketplaceViewModel() {
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Assuming you have a 'products' table with 'title', 'price', 'created_at', and 'image_url' columns.
      final response = await _supabaseClient
          .from('products')
          .select()
          .order('created_at', ascending: false)
          .limit(20);

      _recentlyAdded = [];
      _oldPosts = [];

      if (response.isNotEmpty) {
        // Split the fetched products into 'recently added' and 'old posts'
        // For simplicity, we'll assume the first 10 items are 'recently added'
        // and the rest are 'old posts'. You can adjust this logic as needed.
        final List<Map<String, dynamic>> products =
            (response as List).cast<Map<String, dynamic>>();

        _recentlyAdded = products.take(10).toList();
        _oldPosts = products.skip(10).toList();
      }
    } on PostgrestException catch (e) {
      _errorMessage = 'Failed to load products: ${e.message}';
      if (kDebugMode) {
        print(_errorMessage);
      }
    } catch (e) {
      _errorMessage = 'An unknown error occurred: $e';
      if (kDebugMode) {
        print(_errorMessage);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
      }
    }
  }