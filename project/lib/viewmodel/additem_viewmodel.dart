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

  AddItemViewModel() {
    _loadCategories();
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
      if (picked == null) { isPickingImage = false; notifyListeners(); return; }

      if (selectedImages.length >= 4) {
        isPickingImage = false; notifyListeners();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can upload up to 4 images.')));
        return;
      }

      selectedImages.add(File(picked.path));
      isPickingImage = false;
      notifyListeners();
    } catch (e) {
      isPickingImage = false; notifyListeners();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image pick failed: $e')));
    }
  }

  void removeImage(int idx) {
    if (idx >= 0 && idx < selectedImages.length) {
      selectedImages.removeAt(idx);
      notifyListeners();
    }
  }

  Future<void> listProduct(BuildContext context, GlobalKey<FormBuilderState> formKey) async {
    final form = formKey.currentState!;
    if (!form.saveAndValidate()) return;

    final v = form.value;
    final title = (v['title'] as String).trim();
    final category = (v['category'] as String);
    final priceStr = (v['price'] as String).trim();
    final currency = (v['currency'] as String);
    final description = (v['description'] as String? ?? '').trim();

    final price = double.tryParse(priceStr);
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Price must be numeric.')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select/enter size.')));
        return;
      }
    }

    if (selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one image.')));
      return;
    }

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
    }
  }
}
