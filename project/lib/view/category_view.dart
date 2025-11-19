import 'package:flutter/material.dart';
import 'package:project/widgets/custom_appbar.dart';
import 'package:project/view/product_detail_view.dart';
import '../models/product.dart';

class CategoryView extends StatelessWidget {
  final String categoryName;
  final List<Product> products;

  const CategoryView({
    super.key,
    required this.categoryName,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HCAppBar(
        titleWidget:
            Text(categoryName, style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: 0.8,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          final cover = product.imageUrls.isNotEmpty
              ? product.imageUrls.first
              : 'https://via.placeholder.com/400x300?text=No+Image';
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ProductDetailView(product: product)),
              );
            },
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      color: const Color(0xFFEAF2FF),
                      child: Image.network(
                        cover,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              color: Colors.grey, size: 40),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Text(product.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
                    child: Text(
                      '${product.currency == 'TL' ? '₺' : product.currency == 'USD' ? '\$' : '€'}${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: product.sellerImageUrl.isNotEmpty
                              ? NetworkImage(product.sellerImageUrl)
                              : null,
                          backgroundColor: Colors.grey.shade200,
                          child: product.sellerImageUrl.isEmpty
                              ? const Icon(Icons.person,
                                  size: 14, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            product.sellerName,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
}
