import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mime/mime.dart';

import '../config/size_config.dart';
import '../../viewmodel/additem_viewmodel.dart';
import 'package:project/widgets/custom_appbar.dart';

/// Unified view for both adding new products and editing existing ones.
/// - If [productId] is null: "Add Product" mode
/// - If [productId] is provided: "Edit Product" mode with pre-filled data
class ProductFormView extends StatefulWidget {
  // Edit mode fields (all optional for add mode)
  final String? productId;
  final String? initialTitle;
  final String? initialDescription;
  final String? initialCategory;
  final double? initialPrice;
  final String? initialCurrency;
  final String? initialSizeValue;
  final List<String>? initialImageUrls;

  const ProductFormView({
    super.key,
    this.productId,
    this.initialTitle,
    this.initialDescription,
    this.initialCategory,
    this.initialPrice,
    this.initialCurrency,
    this.initialSizeValue,
    this.initialImageUrls,
  });

  bool get isEditMode => productId != null;

  @override
  State<ProductFormView> createState() => _ProductFormViewState();
}

class _ProductFormViewState extends State<ProductFormView> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _supa = Supabase.instance.client;

  static const Color acmBlue = Color.fromARGB(255, 1, 130, 172);

  bool _didInitMediaQuery = false;
  bool _busy = false;

  // Edit mode: existing images from DB
  final List<_ExistingImg> _existingImages = [];
  final Set<String> _removedImageIds = {};
  final Set<String> _removedImageUrls = {};

  String _norm(String s) => s.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode) {
      _loadExistingImages();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitMediaQuery) {
      SizeConfig().init(context);
      _didInitMediaQuery = true;
    }
  }

  Future<void> _loadExistingImages() async {
    if (!widget.isEditMode) return;
    try {
      final rows = await _supa
          .from('marketplace_images')
          .select('id, url, created_at')
          .eq('product_id', widget.productId!)
          .order('created_at');

      final list = (rows as List).cast<Map<String, dynamic>>();
      _existingImages
        ..clear()
        ..addAll(list.map((e) => _ExistingImg(
              id: (e['id']).toString(),
              url: (e['url'] as String?) ?? '',
            )));
      if (mounted) setState(() {});
    } catch (_) {
      // silent fail
    }
  }

  String? _extractStorageKeyFromUrl(String url) {
    const pub = '/object/public/marketplace/';
    const sig = '/object/sign/marketplace/';
    final iPub = url.indexOf(pub);
    if (iPub != -1) return url.substring(iPub + pub.length);
    final iSig = url.indexOf(sig);
    if (iSig != -1) {
      final rest = url.substring(iSig + sig.length);
      return rest.split('?').first;
    }
    return null;
  }

  Future<String> _uploadImageFile(File file) async {
    final bucket = _supa.storage.from('marketplace');
    final uid = _supa.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final path = widget.isEditMode
        ? '$uid/products/${widget.productId}/$fileName'
        : '$uid/products/temp_$fileName';

    final bytes = await file.readAsBytes();
    final mime = lookupMimeType(file.path) ?? 'application/octet-stream';

    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: mime,
        cacheControl: '3600',
      ),
    );
    return bucket.getPublicUrl(path);
  }

  void _removeExistingImageAt(int index) {
    if (!widget.isEditMode || index < 0 || index >= _existingImages.length) {
      return;
    }
    final img = _existingImages[index];
    _removedImageIds.add(img.id);
    if (img.url.isNotEmpty) _removedImageUrls.add(img.url);

    FocusScope.of(context).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _existingImages.removeAt(index));
    });
  }

  void _seedSizeOption(AddItemViewModel vm) {
    if (!widget.isEditMode) {
      vm.onSizeOptionChanged('LETTER');
      return;
    }
    final v = (widget.initialSizeValue ?? '').trim();
    if (v.isEmpty) {
      vm.onSizeOptionChanged('STANDARD');
      return;
    }
    const letters = {'XS', 'S', 'M', 'L', 'XL', '2XL', '3XL'};
    final isDigits = RegExp(r'^\d+([.,]\d+)?$').hasMatch(v);
    if (letters.contains(v.toUpperCase())) {
      vm.onSizeOptionChanged('LETTER');
    } else if (isDigits) {
      vm.onSizeOptionChanged('NUMERIC');
    } else {
      vm.onSizeOptionChanged('STANDARD');
    }
  }

  Future<void> _handleSave(AddItemViewModel vm) async {
    if (widget.isEditMode) {
      await _updateProduct(vm);
    } else {
      await vm.listProduct(context, _formKey);
    }
  }

  Future<void> _updateProduct(AddItemViewModel vm) async {
    if (_busy) return;
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final values = _formKey.currentState!.value;
      final title = (values['title'] as String).trim();
      final desc = (values['description'] as String? ?? '').trim();
      final category = values['category'] as String;
      final priceStr = (values['price'] as String).trim();
      final currency = values['currency'] as String;

      String? sizeValue;
      if (vm.selectedCategory == 'Clothes') {
        if (vm.selectedSizeOption == 'LETTER') {
          sizeValue = (values['letter_size'] as String?)?.trim();
        } else if (vm.selectedSizeOption == 'NUMERIC') {
          sizeValue = (values['numeric_size'] as String?)?.trim();
        } else {
          sizeValue = widget.initialSizeValue;
        }
        if (sizeValue != null && sizeValue.isEmpty) sizeValue = null;
      }

      final price = double.tryParse(priceStr.replaceAll(',', '.'));
      if (price == null) {
        messenger
            .showSnackBar(const SnackBar(content: Text('Enter a valid price')));
        setState(() => _busy = false);
        return;
      }

      // 1) Update product record
      await _supa.from('marketplace_products').update({
        'title': title,
        'description': desc,
        'category': category,
        'price': price,
        'currency': currency,
        'size_value': sizeValue,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.productId!);

      // 2) Upload new images
      if (vm.selectedImages.isNotEmpty) {
        for (final f in vm.selectedImages) {
          try {
            final publicUrl = await _uploadImageFile(f);
            await _supa.from('marketplace_images').insert({
              'product_id': widget.productId,
              'url': publicUrl,
            });
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(content: Text('Upload failed for an image: $e')),
            );
          }
        }
      }

      // 3) Delete removed images from storage and DB
      if (_removedImageUrls.isNotEmpty) {
        final keys = <String>[];
        for (final u in _removedImageUrls) {
          final k = _extractStorageKeyFromUrl(u);
          if (k != null && k.isNotEmpty) keys.add(k);
        }
        if (keys.isNotEmpty) {
          try {
            await _supa.storage.from('marketplace').remove(keys);
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(content: Text('Could not delete some files: $e')),
            );
          }
        }
      }
      if (_removedImageIds.isNotEmpty) {
        try {
          await _supa
              .from('marketplace_images')
              .delete()
              .inFilter('id', _removedImageIds.toList());
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text('Could not delete image rows: $e')),
          );
        }
      }

      if (!mounted) return;
      messenger.clearSnackBars();
      messenger.showSnackBar(const SnackBar(content: Text('Product updated')));

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return ChangeNotifierProvider(
      create: (_) {
        final vm = AddItemViewModel();
        if (widget.isEditMode && widget.initialCategory != null) {
          vm.onCategoryChanged(widget.initialCategory);
          _seedSizeOption(vm);
        }
        return vm;
      },
      child: Consumer<AddItemViewModel>(
        builder: (context, viewModel, child) {
          // Dropdown safe initialization for edit mode
          final cats = viewModel.categories;
          final initCat = widget.initialCategory ?? '';
          final hasInitial =
              initCat.isNotEmpty && cats.any((c) => _norm(c) == _norm(initCat));
          final safeInitialCategory = hasInitial
              ? cats.firstWhere((c) => _norm(c) == _norm(initCat))
              : null;

          final isEditMode = widget.isEditMode;
          final isBusy = isEditMode ? _busy : viewModel.isListing;

          return Scaffold(
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            appBar: isEditMode
                ? AppBar(
                    title: const Text('Edit Product',
                        style: TextStyle(color: Colors.white)),
                    centerTitle: true,
                    backgroundColor: acmBlue,
                    elevation: 0,
                  )
                : const HCAppBar(
                    title: 'List Product',
                    centerTitle: true,
                    backgroundColor: acmBlue,
                    elevation: 0,
                  ),
            body: SingleChildScrollView(
              padding: EdgeInsets.all(getProportionateScreenWidth(16)),
              child: FormBuilder(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _buildSection(
                      'Basic Information',
                      children: [
                        FormBuilderTextField(
                          name: 'title',
                          initialValue: widget.initialTitle,
                          decoration: _inputDecoration('Product Title'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '*Title field must be filled!';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: getProportionateScreenHeight(16)),
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: FormBuilderDropdown<String>(
                                key: ValueKey(
                                    'cat-${cats.length}-${hasInitial ? 1 : 0}'),
                                name: 'category',
                                initialValue: safeInitialCategory,
                                decoration: _inputDecoration('Category'),
                                isExpanded: true,
                                items:
                                    viewModel.categories.map((String category) {
                                  return DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  );
                                }).toList(),
                                onChanged: viewModel.onCategoryChanged,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '*Category must be selected!';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(width: getProportionateScreenWidth(16)),
                            Expanded(
                              flex: 1,
                              child: _buildPriceInput(viewModel),
                            ),
                          ],
                        ),
                      ],
                    ),
                    _buildSection(
                      'Description',
                      children: [
                        FormBuilderTextField(
                          name: 'description',
                          initialValue: widget.initialDescription,
                          decoration: _inputDecoration('Detailed Description'),
                          maxLines: 5,
                        ),
                      ],
                    ),
                    if (viewModel.selectedCategory == 'Clothes')
                      _buildSizeSection(viewModel),
                    _buildImageSection(viewModel),
                    SizedBox(height: getProportionateScreenHeight(24)),
                    ElevatedButton(
                      onPressed: isBusy ? null : () => _handleSave(viewModel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: acmBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                            vertical: getProportionateScreenHeight(16)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              getProportionateScreenWidth(12)),
                        ),
                        elevation: 4,
                      ),
                      child: isBusy
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Text(
                              isEditMode ? 'Save Changes' : 'List Product',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, {required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(
              top: getProportionateScreenHeight(16),
              bottom: getProportionateScreenHeight(8)),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        ...children,
        SizedBox(height: getProportionateScreenHeight(16)),
        Divider(height: 1, color: Theme.of(context).colorScheme.outline),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(getProportionateScreenWidth(8)),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      contentPadding: EdgeInsets.symmetric(
          horizontal: getProportionateScreenWidth(16),
          vertical: getProportionateScreenHeight(12)),
    );
  }

  Widget _buildPriceInput(AddItemViewModel viewModel) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: FormBuilderTextField(
            name: 'price',
            initialValue: widget.initialPrice?.toStringAsFixed(0),
            decoration: InputDecoration(
              labelText: 'Price',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(getProportionateScreenWidth(8)),
                  bottomLeft: Radius.circular(getProportionateScreenWidth(8)),
                ),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: getProportionateScreenWidth(16),
                  vertical: getProportionateScreenHeight(12)),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '*Price must be filled!';
              }
              return null;
            },
          ),
        ),
        Expanded(
          flex: 1,
          child: FormBuilderDropdown<String>(
            name: 'currency',
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(getProportionateScreenWidth(8)),
                  bottomRight: Radius.circular(getProportionateScreenWidth(8)),
                ),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: getProportionateScreenWidth(16),
                  vertical: getProportionateScreenHeight(12)),
            ),
            initialValue: widget.initialCurrency ?? 'TL',
            items: ['TL', 'USD', 'EUR'].map((String currency) {
              return DropdownMenuItem(
                value: currency,
                child: Text(currency),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSizeSection(AddItemViewModel viewModel) {
    final init = (widget.initialSizeValue ?? '').trim();
    final isDigits = RegExp(r'^\d+([.,]\d+)?$').hasMatch(init);
    final isLetter =
        {'XS', 'S', 'M', 'L', 'XL', '2XL', '3XL'}.contains(init.toUpperCase());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Size'),
        SizedBox(height: getProportionateScreenHeight(16)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildSizeButton(viewModel, 'LETTER'),
              SizedBox(width: getProportionateScreenWidth(8)),
              _buildSizeButton(viewModel, 'NUMERIC'),
              SizedBox(width: getProportionateScreenWidth(8)),
              _buildSizeButton(viewModel, 'STANDARD'),
            ],
          ),
        ),
        if (viewModel.selectedSizeOption == 'NUMERIC')
          Padding(
            padding: EdgeInsets.only(top: getProportionateScreenHeight(16)),
            child: SizedBox(
              width: getProportionateScreenWidth(150),
              child: FormBuilderTextField(
                name: 'numeric_size',
                initialValue: isDigits ? init : '',
                decoration: _inputDecoration('45,46...'),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '*Size must be filled!';
                  }
                  return null;
                },
              ),
            ),
          ),
        if (viewModel.selectedSizeOption == 'LETTER')
          Padding(
            padding: EdgeInsets.only(top: getProportionateScreenHeight(16)),
            child: SizedBox(
              width: getProportionateScreenWidth(150),
              child: FormBuilderDropdown<String>(
                name: 'letter_size',
                initialValue: isLetter ? init.toUpperCase() : null,
                decoration: _inputDecoration('Select Size'),
                isExpanded: true,
                items: ['XS', 'S', 'M', 'L', 'XL', '2XL', '3XL']
                    .map((String size) {
                  return DropdownMenuItem(
                    value: size,
                    child: Text(size),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '*Size must be selected!';
                  }
                  return null;
                },
              ),
            ),
          ),
        SizedBox(height: getProportionateScreenHeight(16)),
        Divider(height: 1, color: Theme.of(context).colorScheme.outline),
      ],
    );
  }

  Widget _buildSizeButton(AddItemViewModel viewModel, String label) {
    bool isSelected = viewModel.selectedSizeOption == label;
    return ElevatedButton(
      onPressed: () => viewModel.onSizeOptionChanged(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? acmBlue
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor:
            isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
        shape: const StadiumBorder(),
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: getProportionateScreenWidth(16),
          vertical: getProportionateScreenHeight(12),
        ),
      ),
      child: Text(label),
    );
  }

  Widget _buildImageSection(AddItemViewModel viewModel) {
    final totalImageCount =
        _existingImages.length + viewModel.selectedImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Images'),
        SizedBox(height: getProportionateScreenHeight(16)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Edit mode: Show existing images from DB
              if (widget.isEditMode)
                ..._existingImages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final img = entry.value;
                  return Padding(
                    padding:
                        EdgeInsets.only(right: getProportionateScreenWidth(16)),
                    child: Stack(
                      children: [
                        Container(
                          width: getProportionateScreenWidth(80),
                          height: getProportionateScreenWidth(80),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                getProportionateScreenWidth(8)),
                            border: Border.all(color: Colors.grey, width: 1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                                getProportionateScreenWidth(8)),
                            child: Image.network(
                              img.url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                    child: Icon(Icons.broken_image));
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          top: getProportionateScreenHeight(4),
                          right: getProportionateScreenWidth(4),
                          child: GestureDetector(
                            onTap: () => _removeExistingImageAt(index),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.8),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              // Newly selected images (both add and edit modes)
              ...viewModel.selectedImages.asMap().entries.map((entry) {
                final imageFile = entry.value;
                return Padding(
                  padding:
                      EdgeInsets.only(right: getProportionateScreenWidth(16)),
                  child: Stack(
                    children: [
                      Container(
                        width: getProportionateScreenWidth(80),
                        height: getProportionateScreenWidth(80),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                              getProportionateScreenWidth(8)),
                          border: Border.all(color: Colors.grey, width: 1),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                              getProportionateScreenWidth(8)),
                          child: Image.file(
                            imageFile,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: getProportionateScreenHeight(4),
                        right: getProportionateScreenWidth(4),
                        child: GestureDetector(
                          onTap: () => viewModel.removeImage(entry.key),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.8),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Add image button
              if (totalImageCount < 4)
                GestureDetector(
                  onTap: viewModel.isPickingImage
                      ? null
                      : () => _showImageSourceSheet(context, viewModel),
                  child: Container(
                    width: getProportionateScreenWidth(80),
                    height: getProportionateScreenWidth(80),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius:
                          BorderRadius.circular(getProportionateScreenWidth(8)),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                    child: Center(
                      child: viewModel.isPickingImage
                          ? const CircularProgressIndicator()
                          : Icon(Icons.add,
                              color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showImageSourceSheet(BuildContext context, AddItemViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                if (!viewModel.isPickingImage) {
                  viewModel.pickImageFromCamera(context);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.of(ctx).pop();
                if (!viewModel.isPickingImage) {
                  viewModel.pickImage(context);
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _ExistingImg {
  final String id;
  final String url;
  _ExistingImg({required this.id, required this.url});
}
