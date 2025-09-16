import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:project/services/chat_service.dart';
import 'package:project/viewmodel/marketplace_viewmodel.dart';
import 'package:project/view/chat_view.dart'; // Import your Product model

class ProductDetailView extends StatefulWidget {
  final Product product; // <-- Use Product model

  const ProductDetailView({Key? key, required this.product}) : super(key: key);

  @override
  State<ProductDetailView> createState() => _ProductViewState();
}

class _ProductViewState extends State<ProductDetailView> {
  int _current = 0;

  void _openFullScreen(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenGallery(
          images: widget.product.imageUrls, // <-- Use imageUrls
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.product.imageUrls; // <-- Use imageUrls
    final title = widget.product.name;
    final price = widget.product.price;
    final description = widget.product.description;
    final isClothing = widget.product.category == 'Clothes';
    final sizing = widget.product.sizes?.join(', ') ?? '';

    return Scaffold(
      appBar: AppBar(title: Text('Product Details')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Replace CarouselSlider with this:
            SizedBox(
              height: 250,
              child: PageView.builder(
                itemCount: images.length > 4 ? 4 : images.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _openFullScreen(index),
                    child: Image.network(images[index], fit: BoxFit.cover, width: double.infinity),
                  );
                 },
                ),
              ),
              Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length > 4 ? 4 : images.length,
                (index) => Container(
                  width: 8.0,
                  height: 8.0,
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _current == index ? Colors.black : Colors.grey,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('₺${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, color: Colors.green)),
                  const SizedBox(height: 12),
                  Text(description, style: const TextStyle(fontSize: 16)),
                  if (isClothing && sizing.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Sizing: $sizing', style: const TextStyle(fontSize: 16)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async{
                        // Navigate to messaging screen with seller
                        final sellerId = widget.product.sellerId; // <-- Use sellerId
                        final chatService = ChatService();
                        final chatId = await chatService.createOrGetDm(sellerId);

                        //Use seller's display name if available, otherwise fallback to "Seller"
                        final chatTitle = widget.product.sellerName;

                        if (!mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatView(conversationId: chatId, title: chatTitle),
                          ),
                        );
                      },
                      child: const Text('Message Seller'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FullScreenGallery extends StatelessWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenGallery({Key? key, required this.images, required this.initialIndex}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            itemCount: images.length > 4 ? 4 : images.length,
            pageController: PageController(initialPage: initialIndex),
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: NetworkImage(images[index]),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              );
            },
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}