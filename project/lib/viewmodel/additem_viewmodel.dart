import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AddItemViewModel extends ChangeNotifier {
  // State variables
  String? _selectedCategory;
  String? _selectedSizeOption;
  final List<File> _selectedImages = [];
  bool _isPickingImage = false; // New state variable

  // Getters to expose state to the view
  String? get selectedCategory => _selectedCategory;
  String? get selectedSizeOption => _selectedSizeOption;
  List<File> get selectedImages => _selectedImages;
  bool get isPickingImage => _isPickingImage; // New getter

  // Static data
  final List<String> categories = ['Electronics', 'Clothes', 'Books'];

  // Logic to handle category change
  void onCategoryChanged(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  // Logic to handle size option change
  void onSizeOptionChanged(String label) {
    _selectedSizeOption = label;
    notifyListeners();
  }

  // Logic to handle image picking
  Future<void> pickImage(BuildContext context) async {
    // Prevent multiple calls
    if (_isPickingImage) {
      return;
    }

    _isPickingImage = true;
    notifyListeners();

    try {
      final picker = ImagePicker();
      final List<XFile>? pickedFiles = await picker.pickMultiImage();

      if (pickedFiles == null) {
        return;
      }

      if (_selectedImages.length + pickedFiles.length <= 4) {
        _selectedImages.addAll(pickedFiles.map((xfile) => File(xfile.path)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can only add up to 4 images.')),
        );
      }
    } finally {
      // Ensure this is always reset
      _isPickingImage = false;
      notifyListeners();
    }
  }

  // Logic to remove an image
  void removeImage(int index) {
    _selectedImages.removeAt(index);
    notifyListeners();
  }

  // Logic to validate form and list product
  void listProduct(BuildContext context, GlobalKey<FormBuilderState> formKey) {
    final formState = formKey.currentState;

    if (formState != null && formState.saveAndValidate()) {
      if (_selectedImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('At least one image is required!')),
        );
      } else {
        final formData = formState.value;
        // TODO: Send data to backend with formData and _selectedImages
        // For now, just show a message.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product will be listed!')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
    }
  }
}