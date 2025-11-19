import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/additem_viewmodel.dart';
import '../config/size_config.dart';
import 'package:project/widgets/custom_appbar.dart';

class AddItemView extends StatefulWidget {
  const AddItemView({super.key});

  @override
  State<AddItemView> createState() => _AddItemViewState();
}

class _AddItemViewState extends State<AddItemView> {
  final _formKey = GlobalKey<FormBuilderState>();

  // Use the specific blue color from the user's reference image
  static const Color acmBlue = Color.fromARGB(255, 1, 130, 172);

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return ChangeNotifierProvider(
      create: (_) => AddItemViewModel(),
      child: Consumer<AddItemViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: const HCAppBar(
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
                                name: 'category',
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
                      onPressed: viewModel.isListing
                          ? null
                          : () => viewModel.listProduct(context, _formKey),
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
                      child: viewModel.isListing
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text(
                              'List Product',
                              style: TextStyle(
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
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
        borderRadius: BorderRadius.circular(getProportionateScreenWidth(8)),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.white,
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
              fillColor: Colors.white,
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
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: getProportionateScreenWidth(16),
                  vertical: getProportionateScreenHeight(12)),
            ),
            initialValue: 'TL',
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
              // Corrected by wrapping in a SizedBox
              width: getProportionateScreenWidth(150), // Set the desired width
              child: FormBuilderDropdown<String>(
                name: 'letter_size',
                decoration: _inputDecoration('Select Size'),
                isExpanded:
                    true, // This is fine now because it's inside a SizedBox
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
        const Divider(height: 1, color: Colors.grey),
      ],
    );
  }

  Widget _buildSizeButton(AddItemViewModel viewModel, String label) {
    bool isSelected = viewModel.selectedSizeOption == label;
    return ElevatedButton(
      onPressed: () => viewModel.onSizeOptionChanged(label),
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

  Widget _buildImageSection(AddItemViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Images'),
        SizedBox(height: getProportionateScreenHeight(16)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
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
                              color: Colors.red.withOpacity(0.8),
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
              }).toList(),
              if (viewModel.selectedImages.length < 4)
                GestureDetector(
                  onTap: viewModel.isPickingImage
                      ? null
                      : () => viewModel.pickImage(context),
                  child: Container(
                    width: getProportionateScreenWidth(80),
                    height: getProportionateScreenWidth(80),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC5C5C5),
                      borderRadius:
                          BorderRadius.circular(getProportionateScreenWidth(8)),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: Center(
                      child: viewModel.isPickingImage
                          ? const CircularProgressIndicator()
                          : const Icon(Icons.add, color: Colors.black),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
}
