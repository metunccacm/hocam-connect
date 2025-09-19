import 'package:flutter/material.dart';
import 'package:project/viewmodel/marketplace_viewmodel.dart';
import 'package:project/widgets/custom_appbar.dart';

class ProductDetailView extends StatelessWidget {
  final Product product;

  const ProductDetailView({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HCAppBar(
        title: product.name,
        // backgroundColor: Colors.white, // Adjust if HCAppBar has different properties
        // foregroundColor: Colors.black,
        // elevation: 1,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Details for ${product.name}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            const Text('UI and functionality will be added here.'),
          ],
        ),
      ),
    );
  }
}