import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddItemViewModel extends ChangeNotifier {
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  bool _isUploading = false;
  String? _uploadError;

  bool get isUploading => _isUploading;
  String? get uploadError => _uploadError;

  // This function will be called from the AddItemView to save the new item.
  Future<void> addItem({
    required String title,
    required String description,
    required String price, // You can also use double, just parse it here
    required String size,
    required String color,
    required List<String> imageUrls,
  }) async {
    _isUploading = true;
    _uploadError = null;
    notifyListeners();

    try {
      final response = await _supabaseClient.from('products').insert({
        'title': title,
        'description': description,
        'price': price,
        'size': size,
        'color': color,
        'image_urls': imageUrls,
      });

      if (response.error != null) {
        throw response.error!;
      }
    } on PostgrestException catch (e) {
      _uploadError = 'Failed to add item: ${e.message}';
    } catch (e) {
      _uploadError = 'An unknown error occurred: $e';
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  // TODO: Add methods for handling image uploads
  // You can use a library like `image_picker` to get the image from the user's device,
  // then use the Supabase Storage client to upload the image and get the public URL.
  // The imageUrls list in the addItem function would contain these public URLs.
}
