import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mime/mime.dart';

import '../config/size_config.dart';
import '../../viewmodel/additem_viewmodel.dart';

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

          final theme = Theme.of(context);
          final cs = theme.colorScheme;
          
          return Scaffold(
            backgroundColor: cs.surface,
            appBar: AppBar(
              centerTitle: true,
              title: Text(
                isEditMode ? 'Edit Product' : 'List Product',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.appBarTheme.foregroundColor ?? cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: theme.appBarTheme.backgroundColor ?? cs.surface,
              foregroundColor: theme.appBarTheme.foregroundColor ?? cs.onSurface,
              elevation: 1,
            ),
            body: FormBuilder(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Title
                  FormBuilderTextField(
                    name: 'title',
                    initialValue: widget.initialTitle,
                    decoration: InputDecoration(
                      labelText: 'Product Title *',
                      hintText: 'e.g., iPhone 13 Pro Max 256GB',
                      prefixIcon: Icon(Icons.shopping_bag_outlined, color: cs.primary),
                      border: const OutlineInputBorder(),
                      helperText: 'Make it clear and specific',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Title is required';
                      }
                      if (value.length < 3) {
                        return 'Title must be at least 3 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Category
                  FormBuilderDropdown<String>(
                    key: ValueKey(
                        'cat-${cats.length}-${hasInitial ? 1 : 0}'),
                    name: 'category',
                    initialValue: safeInitialCategory,
                    decoration: InputDecoration(
                      labelText: 'Category *',
                      prefixIcon: Icon(Icons.category_outlined, color: cs.primary),
                      border: const OutlineInputBorder(),
                      helperText: 'Choose the best match',
                    ),
                    dropdownColor: cs.surface,
                    items: viewModel.categories.map((String category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: viewModel.onCategoryChanged,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Category is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Price and Currency
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: FormBuilderTextField(
                          name: 'price',
                          initialValue: widget.initialPrice?.toStringAsFixed(0),
                          decoration: InputDecoration(
                            labelText: 'Price *',
                            hintText: '0',
                            prefixIcon: Icon(Icons.attach_money, color: cs.primary),
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            final price = int.tryParse(value);
                            if (price == null || price <= 0) {
                              return 'Enter valid price';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: FormBuilderDropdown<String>(
                          name: 'currency',
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                            border: OutlineInputBorder(),
                          ),
                          dropdownColor: cs.surface,
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
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  FormBuilderTextField(
                    name: 'description',
                    initialValue: widget.initialDescription,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'Describe condition, features, and details...',
                      prefixIcon: Icon(Icons.description_outlined, color: cs.primary),
                      border: const OutlineInputBorder(),
                      helperText: 'Add details to attract buyers',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  
                  // Size section (only for Clothes)
                  if (viewModel.selectedCategory == 'Clothes') ..._buildSizeFields(viewModel),
                  
                  // Images section
                  ..._buildImageFields(viewModel),
                  
                  const SizedBox(height: 24),
                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isBusy ? null : () => _handleSave(viewModel),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        disabledBackgroundColor: cs.surfaceContainerHighest,
                        disabledForegroundColor: cs.onSurfaceVariant,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isBusy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              isEditMode ? 'Save Changes' : 'List Product',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Size fields for Clothes category
  List<Widget> _buildSizeFields(AddItemViewModel viewModel) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final init = (widget.initialSizeValue ?? '').trim();
    final isDigits = RegExp(r'^\d+([.,]\d+)?$').hasMatch(init);
    final isLetter =
        {'XS', 'S', 'M', 'L', 'XL', '2XL', '3XL'}.contains(init.toUpperCase());

    return [
      Text(
        'Size Option',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildSizeOptionChip(viewModel, 'LETTER'),
            const SizedBox(width: 8),
            _buildSizeOptionChip(viewModel, 'NUMERIC'),
            const SizedBox(width: 8),
            _buildSizeOptionChip(viewModel, 'STANDARD'),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (viewModel.selectedSizeOption == 'NUMERIC')
        FormBuilderTextField(
          name: 'numeric_size',
          initialValue: isDigits ? init : '',
          decoration: const InputDecoration(
            labelText: 'Size (e.g., 45, 46)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Size is required';
            }
            return null;
          },
        ),
      if (viewModel.selectedSizeOption == 'LETTER')
        FormBuilderDropdown<String>(
          name: 'letter_size',
          initialValue: isLetter ? init.toUpperCase() : null,
          decoration: const InputDecoration(
            labelText: 'Select Size',
            border: OutlineInputBorder(),
          ),
          dropdownColor: cs.surface,
          items: ['XS', 'S', 'M', 'L', 'XL', '2XL', '3XL']
              .map((String size) {
            return DropdownMenuItem(
              value: size,
              child: Text(size),
            );
          }).toList(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Size is required';
            }
            return null;
          },
        ),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildSizeOptionChip(AddItemViewModel viewModel, String label) {
    final isSelected = viewModel.selectedSizeOption == label;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => viewModel.onSizeOptionChanged(label),
      backgroundColor: cs.surfaceContainerHighest,
      selectedColor: cs.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
      ),
    );
  }

  // Image fields
  List<Widget> _buildImageFields(AddItemViewModel viewModel) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final totalImageCount =
        _existingImages.length + viewModel.selectedImages.length;

    return [
      Row(
        children: [
          Icon(Icons.photo_library_outlined, color: cs.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            'Product Photos',
            style: theme.textTheme.titleMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: totalImageCount >= 4
                  ? cs.primaryContainer
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$totalImageCount/4',
              style: theme.textTheme.bodySmall?.copyWith(
                color: totalImageCount >= 4
                    ? cs.onPrimaryContainer
                    : cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Add up to 4 photos. First photo will be the cover.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 12),
      if (totalImageCount == 0)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cs.outline.withValues(alpha: 0.5),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  size: 48, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                'No photos yet',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap the + button below to add photos',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )
      else
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Existing images (edit mode)
              if (widget.isEditMode)
                ..._existingImages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final img = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildImageThumbnail(
                      imageUrl: img.url,
                      onRemove: () => _removeExistingImageAt(index),
                      isFirst: index == 0 &&
                          viewModel.selectedImages.isEmpty,
                    ),
                  );
                }),
              // New images
              ...viewModel.selectedImages.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildImageThumbnail(
                    imageFile: entry.value,
                    onRemove: () => viewModel.removeImage(entry.key),
                    isFirst: entry.key == 0 && _existingImages.isEmpty,
                  ),
                );
              }),
            ],
          ),
        ),
      const SizedBox(height: 12),
      // Add button
      if (totalImageCount < 4)
        OutlinedButton.icon(
          onPressed: viewModel.isPickingImage
              ? null
              : () => _showImageSourceSheet(context, viewModel),
          icon: viewModel.isPickingImage
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: cs.primary),
                )
              : Icon(Icons.add_photo_alternate, color: cs.primary),
          label: Text(
            viewModel.isPickingImage ? 'Loading...' : 'Add Photo',
            style: TextStyle(color: cs.primary),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: cs.primary),
            minimumSize: const Size(double.infinity, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildImageThumbnail({
    String? imageUrl,
    File? imageFile,
    required VoidCallback onRemove,
    bool isFirst = false,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFirst ? cs.primary : cs.outline,
              width: isFirst ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: imageFile != null
                ? Image.file(imageFile, fit: BoxFit.cover)
                : imageUrl != null
                    ? Image.network(imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                              color: cs.surfaceContainerHighest,
                              child: Icon(Icons.broken_image,
                                  color: cs.onSurfaceVariant),
                            ))
                    : const SizedBox(),
          ),
        ),
        // Cover badge
        if (isFirst)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'COVER',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        // Remove button
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  void _showImageSourceSheet(BuildContext context, AddItemViewModel viewModel) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: cs.onSurface),
              title: Text('Take Photo', style: TextStyle(color: cs.onSurface)),
              onTap: () {
                Navigator.of(ctx).pop();
                if (!viewModel.isPickingImage) {
                  viewModel.pickImageFromCamera(context);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: cs.onSurface),
              title: Text('Choose from Gallery',
                  style: TextStyle(color: cs.onSurface)),
              onTap: () {
                Navigator.of(ctx).pop();
                if (!viewModel.isPickingImage) {
                  viewModel.pickImage(context);
                }
              },
            ),
            Divider(height: 1, color: cs.outline),
            ListTile(
              leading: Icon(Icons.close, color: cs.onSurface),
              title: Text('Cancel', style: TextStyle(color: cs.onSurface)),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExistingImg {
  final String id;
  final String url;
  _ExistingImg({required this.id, required this.url});
}
