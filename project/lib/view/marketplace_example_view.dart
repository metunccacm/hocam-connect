import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodel/marketplace_viewmodel.dart';
import '../utils/network_error_handler.dart';

/// Example widget showing how to handle HC-50 errors in the UI
class MarketplaceViewExample extends StatefulWidget {
  const MarketplaceViewExample({super.key});

  @override
  State<MarketplaceViewExample> createState() => _MarketplaceViewExampleState();
}

class _MarketplaceViewExampleState extends State<MarketplaceViewExample> {
  @override
  void initState() {
    super.initState();
    // Load data on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketplaceViewModel>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
      ),
      body: Consumer<MarketplaceViewModel>(
        builder: (context, viewModel, child) {
          // Show loading indicator
          if (viewModel.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Show HC-50 error if network error occurred
          if (viewModel.hasNetworkError) {
            return NetworkErrorView(
              message: viewModel.errorMessage,
              onRetry: () => viewModel.refresh(),
            );
          }

          // Show generic error
          if (viewModel.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(viewModel.errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => viewModel.refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Show products
          final products = viewModel.groupedProducts;
          if (products.isEmpty) {
            return const Center(
              child: Text('No products available'),
            );
          }

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final category = products.keys.elementAt(index);
              final categoryProducts = products[category]!;
              
              return ExpansionTile(
                title: Text(category),
                children: categoryProducts.map((product) {
                  return ListTile(
                    title: Text(product.title),
                    subtitle: Text('${product.price} ${product.currency}'),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}
