import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/size_config.dart';
import '../../viewmodel/additem_viewmodel.dart';

class EditProductView extends StatefulWidget {
  final String productId;

  // Mevcut ürün alanları
  final String initialTitle;
  final String initialDescription;
  final String initialCategory;
  final double initialPrice;
  final String initialCurrency; // 'TL' | 'USD' | 'EUR'
  final String? initialSizeValue; // örn: 'M', '42', 'One Size' veya null
  final List<String> initialImageUrls;

  const EditProductView({
    super.key,
    required this.productId,
    required this.initialTitle,
    required this.initialDescription,
    required this.initialCategory,
    required this.initialPrice,
    required this.initialCurrency,
    required this.initialSizeValue,
    required this.initialImageUrls,
  });

  @override
  State<EditProductView> createState() => _EditProductViewState();
}

class _EditProductViewState extends State<EditProductView> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _supa = Supabase.instance.client;

  static const Color acmBlue = Color.fromARGB(255, 1, 130, 172);
  final List<String> _currencies = const ['TL', 'USD', 'EUR'];

  bool _didInitMediaQuery = false;
  bool _busy = false;

  // ---- Görsel state ----
  // DB'den gelen mevcut görseller
  final List<_ExistingImg> _existing = [];
  // Kullanıcının "sildiğim" diye işaretlediği mevcut görsellerin id/path’leri
  final Set<String> _removedImageIds = {};
  final List<String> _removedStoragePaths = [];

  // Yeni eklenecek dosyalar
  final List<File> _newFiles = [];

  @override
  void initState() {
    super.initState();
    _loadExistingImages();
    
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitMediaQuery) {
      SizeConfig().init(context);
      _didInitMediaQuery = true;
    }
  }

  // -------------------- IMAGE IO --------------------

  Future<void> _loadExistingImages() async {
    try {
      final rows = await _supa
          .from('marketplace_images')
          .select('id, url, storage_path, created_at')
          .eq('product_id', widget.productId)
          .order('created_at');

      final list = (rows as List).cast<Map<String, dynamic>>();
      _existing
        ..clear()
        ..addAll(list.map((e) => _ExistingImg(
              id: (e['id']).toString(),
              url: (e['url'] as String?) ?? '',
              storagePath: (e['storage_path'] as String?) ??
                  _extractStoragePath((e['url'] as String?) ?? ''),
            )));
      if (mounted) setState(() {});
    } catch (e) {
      // Sessizce geçelim; ekran yine açılır ama görseller olmayabilir
    }
  }

  Future<void> _pickImage(AddItemViewModel vm) async {
    if (vm.isPickingImage) return;
    await vm.pickImage(context);
    if (vm.selectedImages.isNotEmpty) {
      setState(() {
        _newFiles.addAll(vm.selectedImages);
        if (vm.selectedImages.isNotEmpty) {
          setState(() {
            _newFiles.addAll(vm.selectedImages);
            vm.selectedImages.clear(); // listeyi doğrudan temizle
          });
        }

      });
    }
  }

  void _removeExistingAt(int ix) {
    final img = _existing[ix];
    _removedImageIds.add(img.id);
    if (img.storagePath.isNotEmpty) _removedStoragePaths.add(img.storagePath);
    setState(() => _existing.removeAt(ix));
  }

  void _removeNewFileAt(int ix) {
    setState(() => _newFiles.removeAt(ix));
  }

  String _extractStoragePath(String publicUrl) {
    const marker = '/storage/v1/object/public/';
    final idx = publicUrl.indexOf(marker);
    if (idx == -1) return publicUrl; // fallback
    final after = publicUrl.substring(idx + marker.length); // "bucket/..."
    if (after.startsWith('marketplace/')) {
      return after.replaceFirst('marketplace/', '');
    }
    return after;
  }

  Future<String> _uploadOne(File file) async {
    final bucket = _supa.storage.from('marketplace');
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final path = 'products/${widget.productId}/$fileName';
    await bucket.upload(path, file);
    final publicUrl = bucket.getPublicUrl(path);
    return publicUrl;
  }

  // -------------------- SAVE --------------------

  Future<void> _save(AddItemViewModel vm) async {
    if (_busy) return;
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);

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
    } else {
      sizeValue = null;
    }

    final price = double.tryParse(priceStr.replaceAll(',', '.'));
    if (price == null) {
      setState(() => _busy = false);
      messenger.showSnackBar(
          const SnackBar(content: Text('Enter a valid price')));
      return;
    }

    try {
      // 1) Ürünü güncelle
      await _supa
          .from('marketplace_products')
          .update({
            'title': title,
            'description': desc,
            'category': category,
            'price': price,
            'currency': currency,
            'size_value': sizeValue,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.productId);

      // 2) Silinen mevcut görseller -> önce storage, sonra tablo
      if (_removedStoragePaths.isNotEmpty) {
        try {
          await _supa.storage
              .from('marketplace')
              .remove(_removedStoragePaths.toList());
        } catch (_) {
          // storage silme hatası kritik değil; devam
        }
      }
      if (_removedImageIds.isNotEmpty) {
        await _supa
            .from('marketplace_images')
            .delete()
            .inFilter('id', _removedImageIds.toList());
      }

      // 3) Yeni seçilen dosyaları upload et ve tabloya ekle
      for (final f in _newFiles) {
        final publicUrl = await _uploadOne(f);
        final storagePath = _extractStoragePath(publicUrl);
        await _supa.from('marketplace_images').insert({
          'product_id': widget.productId,
          'url': publicUrl,
          'storage_path': storagePath,
        });
      }

      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('Product updated')));
      Navigator.of(context).pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Update failed: $e')));
      setState(() => _busy = false);
    }
  }

  // -------------------- SIZE & CATEGORY HELPERS --------------------

  void _seedSizeOption(AddItemViewModel vm) {
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

  @override
  Widget build(BuildContext context) {
    final coverUrl = _existing.isNotEmpty ? _existing.first.url : null;

    return ChangeNotifierProvider(
      create: (_) {
        final vm = AddItemViewModel();
        vm.onCategoryChanged(widget.initialCategory); // dinamik kategori
        _seedSizeOption(vm);
        return vm;
      },
      child: Consumer<AddItemViewModel>(
        builder: (context, vm, _) {
          return Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: AppBar(
              title:
                  const Text('Edit Product', style: TextStyle(color: Colors.white)),
              centerTitle: true,
              backgroundColor: acmBlue,
              elevation: 0,
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy ? null : () => _save(vm),
                    style: ElevatedButton.styleFrom(
                      alignment: Alignment.center,
                      backgroundColor: acmBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save Changes'),
                  ),
                ),
              ),
            ),
            body: SingleChildScrollView(
              padding: EdgeInsets.all(getProportionateScreenWidth(16)),
              child: FormBuilder(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: coverUrl == null || coverUrl.isEmpty
                            ? Container(
                                color: const Color(0xFFEFF3F7),
                                child: const Center(
                                  child: Icon(Icons.image, size: 40),
                                ),
                              )
                            : Image.network(coverUrl, fit: BoxFit.cover),
                      ),
                    ),
                    SizedBox(height: getProportionateScreenHeight(16)),

                    _buildSection('Basic Information', children: [
                      FormBuilderTextField(
                        name: 'title',
                        initialValue: widget.initialTitle,
                        decoration: _inputDecoration('Product Title'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? '*Title field must be filled!'
                                : null,
                      ),
                      SizedBox(height: getProportionateScreenHeight(16)),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: FormBuilderDropdown<String>(
                              name: 'category',
                              initialValue: widget.initialCategory,
                              decoration: _inputDecoration('Category'),
                              items: vm.categories
                                  .map((c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      ))
                                  .toList(),
                              onChanged: vm.onCategoryChanged,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '*Category must be selected!';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: getProportionateScreenWidth(16)),
                          Expanded(flex: 2, child: _buildPriceInputs()),
                        ],
                      ),
                    ]),

                    _buildSection('Description', children: [
                      FormBuilderTextField(
                        name: 'description',
                        initialValue: widget.initialDescription,
                        decoration: _inputDecoration('Detailed Description'),
                        maxLines: 5,
                      ),
                    ]),

                    if (vm.selectedCategory == 'Clothes') _buildSizeSection(vm),

                    _buildSection('Images', children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Mevcut (DB) görseller
                            ..._existing.asMap().entries.map((e) {
                              final ix = e.key;
                              final it = e.value;
                              return Padding(
                                padding: EdgeInsets.only(
                                    right: getProportionateScreenWidth(12)),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                          getProportionateScreenWidth(8)),
                                      child: Image.network(
                                        it.url,
                                        width: getProportionateScreenWidth(100),
                                        height: getProportionateScreenWidth(100),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => _removeExistingAt(ix),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.85),
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: const Icon(Icons.close,
                                              size: 16, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                            // Yeni seçilen dosyalar
                            ..._newFiles.asMap().entries.map((e) {
                              final ix = e.key;
                              final file = e.value;
                              return Padding(
                                padding: EdgeInsets.only(
                                    right: getProportionateScreenWidth(12)),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                          getProportionateScreenWidth(8)),
                                      child: Image.file(
                                        file,
                                        width: getProportionateScreenWidth(100),
                                        height: getProportionateScreenWidth(100),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => _removeNewFileAt(ix),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.85),
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: const Icon(Icons.close,
                                              size: 16, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                            // Ekle
                            GestureDetector(
                              onTap: () => _pickImage(vm),
                              child: Container(
                                width: getProportionateScreenWidth(100),
                                height: getProportionateScreenWidth(100),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC5C5C5),
                                  borderRadius: BorderRadius.circular(
                                      getProportionateScreenWidth(8)),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Center(
                                  child: vm.isPickingImage
                                      ? const CircularProgressIndicator()
                                      : const Icon(Icons.add,
                                          color: Colors.black),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
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
            bottom: getProportionateScreenHeight(8),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),
        ...children,
        SizedBox(height: getProportionateScreenHeight(16)),
        const Divider(height: 1, color: Colors.grey),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(getProportionateScreenWidth(8)),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(16),
        vertical: getProportionateScreenHeight(12),
      ),
    );
  }

  Widget _buildPriceInputs() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: FormBuilderTextField(
            name: 'price',
            initialValue: widget.initialPrice.toStringAsFixed(0),
            decoration: InputDecoration(
              labelText: 'Price',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.only(
                  topLeft:
                      Radius.circular(getProportionateScreenWidth(8)),
                  bottomLeft:
                      Radius.circular(getProportionateScreenWidth(8)),
                ),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: getProportionateScreenWidth(16),
                vertical: getProportionateScreenHeight(12),
              ),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '*Price must be filled!';
              }
              final v = double.tryParse(value.replaceAll(',', '.'));
              if (v == null) return 'Enter a valid number';
              return null;
            },
          ),
        ),
        Expanded(
          flex: 1,
          child: FormBuilderDropdown<String>(
            name: 'currency',
            initialValue: _currencies.contains(widget.initialCurrency)
                ? widget.initialCurrency
                : 'TL',
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.only(
                  topRight:
                      Radius.circular(getProportionateScreenWidth(8)),
                  bottomRight:
                      Radius.circular(getProportionateScreenWidth(8)),
                ),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: getProportionateScreenWidth(16),
                vertical: getProportionateScreenHeight(12),
              ),
            ),
            items: _currencies
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSizeSection(AddItemViewModel vm) {
    final init = (widget.initialSizeValue ?? '').trim();
    final isDigits = RegExp(r'^\d+([.,]\d+)?$').hasMatch(init);
    final isLetter =
        {'XS', 'S', 'M', 'L', 'XL', '2XL', '3XL'}.contains(init.toUpperCase());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection('Size', children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSizeButton(vm, 'LETTER'),
                SizedBox(width: getProportionateScreenWidth(8)),
                _buildSizeButton(vm, 'NUMERIC'),
                SizedBox(width: getProportionateScreenWidth(8)),
                _buildSizeButton(vm, 'STANDARD'),
              ],
            ),
          ),
          if (vm.selectedSizeOption == 'NUMERIC')
            Padding(
              padding: EdgeInsets.only(
                  top: getProportionateScreenHeight(16)),
              child: SizedBox(
                width: getProportionateScreenWidth(150),
                child: FormBuilderTextField(
                  name: 'numeric_size',
                  initialValue: isDigits ? init : '',
                  decoration: _inputDecoration('45,46...'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (vm.selectedSizeOption == 'NUMERIC') {
                      if (value == null || value.isEmpty) {
                        return '*Size must be filled!';
                      }
                    }
                    return null;
                  },
                ),
              ),
            ),
          if (vm.selectedSizeOption == 'LETTER')
            Padding(
              padding: EdgeInsets.only(
                  top: getProportionateScreenHeight(16)),
              child: SizedBox(
                width: getProportionateScreenWidth(100),
                child: FormBuilderDropdown<String>(
                  name: 'letter_size',
                  initialValue: isLetter ? init.toUpperCase() : null,
                  decoration: _inputDecoration('Select Size'),
                  items: const ['XS', 'S', 'M', 'L', 'XL', '2XL', '3XL']
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  validator: (value) {
                    if (vm.selectedSizeOption == 'LETTER') {
                      if (value == null || value.isEmpty) {
                        return '*Size must be selected!';
                      }
                    }
                    return null;
                  },
                ),
              ),
            ),
        ]),
      ],
    );
  }

  Widget _buildSizeButton(AddItemViewModel vm, String label) {
    final isSelected = vm.selectedSizeOption == label;
    return ElevatedButton(
      onPressed: () => vm.onSizeOptionChanged(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? acmBlue : const Color(0xFFC5C5C5),
        foregroundColor: isSelected ? Colors.white : Colors.black,
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
}

class _ExistingImg {
  final String id;
  final String url;
  final String storagePath;

  _ExistingImg({
    required this.id,
    required this.url,
    required this.storagePath,
  });
}
