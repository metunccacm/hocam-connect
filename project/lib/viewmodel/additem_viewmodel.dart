import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../services/marketplace_service.dart';

class AddItemViewModel extends ChangeNotifier {
  final _svc = MarketplaceService();

  final List<File> selectedImages = [];
  bool isPickingImage = false;

  List<String> _categories = [];
  List<String> get categories => _categories;

  String? selectedCategory;
  String selectedSizeOption = 'LETTER'; // LETTER | NUMERIC | STANDARD

  bool _isListing = false;
  bool get isListing => _isListing;

  AddItemViewModel() {
    _loadCategories();
  }

  void setListingStatus(bool status) {
    _isListing = status;
    notifyListeners();
  }

  Future<void> _loadCategories() async {
    _categories = await _svc.fetchCategories();
    if (_categories.isEmpty) {
      // Güvenlik ağı: tablo boşsa UI ölmesin
      _categories = ['Clothes', 'Kitchen Items', 'Electronics'];
    }
    notifyListeners();
  }

  void onCategoryChanged(String? val) {
    selectedCategory = val;
    notifyListeners();
  }

  void onSizeOptionChanged(String label) {
    selectedSizeOption = label;
    notifyListeners();
  }

  Future<void> pickImage(BuildContext context) async {
    try {
      isPickingImage = true;
      notifyListeners();

      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) {
        isPickingImage = false;
        notifyListeners();
        return;
      }

      if (selectedImages.length >= 4) {
        isPickingImage = false;
        notifyListeners();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can upload up to 4 images.')));
        }
        return;
      }

      selectedImages.add(File(picked.path));
      isPickingImage = false;
      notifyListeners();
    } catch (e) {
      isPickingImage = false;
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image pick failed: $e')));
      }
    }
  }

  Future<void> pickImageFromCamera(BuildContext context) async {
    try {
      isPickingImage = true;
      notifyListeners();

      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (picked == null) {
        isPickingImage = false;
        notifyListeners();
        return;
      }

      if (selectedImages.length >= 4) {
        isPickingImage = false;
        notifyListeners();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can upload up to 4 images.')));
        }
        return;
      }

      selectedImages.add(File(picked.path));
      isPickingImage = false;
      notifyListeners();
    } catch (e) {
      isPickingImage = false;
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Camera capture failed: $e')));
      }
    }
  }

  void removeImage(int idx) {
    if (idx >= 0 && idx < selectedImages.length) {
      selectedImages.removeAt(idx);
      notifyListeners();
    }
  }

  Future<void> listProduct(BuildContext context, GlobalKey<FormBuilderState> formKey) async {
    if (isListing) return;
    setListingStatus(true);

    final form = formKey.currentState!;
    if (!form.saveAndValidate()) {
      setListingStatus(false);
      return;
    }

    final v = form.value;
    final title = (v['title'] as String).trim();
    final category = (v['category'] as String);
    final priceStr = (v['price'] as String).trim();
    final currency = (v['currency'] as String);
    final description = (v['description'] as String? ?? '').trim();

    final price = double.tryParse(priceStr);
    if (price == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Price must be numeric.')));
      }
      setListingStatus(false);
      return;
    }

    String? sizeType;
    String? sizeValue;
    if (category == 'Clothes') {
      sizeType = selectedSizeOption;
      if (selectedSizeOption == 'LETTER') {
        sizeValue = (v['letter_size'] as String? ?? '').trim();
      } else if (selectedSizeOption == 'NUMERIC') {
        sizeValue = (v['numeric_size'] as String? ?? '').trim();
      }
      if (sizeType != null && (sizeValue == null || sizeValue.isEmpty) && selectedSizeOption != 'STANDARD') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select/enter size.')));
        }
        setListingStatus(false);
        return;
      }
    }

    if (selectedImages.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one image.')));
      }
      setListingStatus(false);
      return;
    }

    //Simulate loading for a consistent user experience
    await Future.delayed(const Duration(seconds: 2));

    try {
      final files = <({Uint8List bytes, String ext})>[];
      for (final f in selectedImages) {
        final bytes = await f.readAsBytes();
        final ext = p.extension(f.path).replaceAll('.', '');
        files.add((bytes: bytes, ext: ext));
      }

      await _svc.addProduct(
        title: title,
        description: description,
        category: category,
        price: price,
        currency: currency,
        sizeType: sizeType,
        sizeValue: sizeValue,
        files: files,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product listed successfully.')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Listing failed: $e')));
      }
    } finally {
      // Ensure the state is reset regardless of success or failure
      setListingStatus(false);
    }
  }
}
