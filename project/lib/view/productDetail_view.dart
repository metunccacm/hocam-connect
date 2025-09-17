import 'package:flutter/material.dart';
import '../models/product.dart';

class ProductDetailView extends StatelessWidget {
  final Product product;
  const ProductDetailView({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final cover = product.imageUrls.isNotEmpty
        ? product.imageUrls.first
        : 'https://via.placeholder.com/800x600?text=No+Image';

    return Scaffold(
      appBar: AppBar(
        title: Text(product.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 4/3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(cover, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          Text(product.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            '${product.currency == 'TL' ? '₺' : product.currency == 'USD' ? '\$' : '€'}${product.price.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(product.description.isEmpty ? 'No description.' : product.description),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                backgroundImage: product.sellerImageUrl.isNotEmpty ? NetworkImage(product.sellerImageUrl) : null,
                child: product.sellerImageUrl.isEmpty ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 8),
              Text(product.sellerName),
            ],
          ),
          if (product.sizeType != null && product.sizeValue != null) ...[
            const SizedBox(height: 16),
            Text('Size: ${product.sizeType} - ${product.sizeValue}',
                style: const TextStyle(color: Colors.black54)),
          ],
        ],
      ),
    );
  }
}
