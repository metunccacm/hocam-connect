import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:project/viewmodel/marketplace_viewmodel.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:project/view/additem_view.dart'; // Make sure this is imported

class MarketplaceView extends StatelessWidget {
  const MarketplaceView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MarketplaceViewModel(),
      child: Consumer<MarketplaceViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("Marketplace"),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.favorite_border),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    // Navigate to the new AddItemView page
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AddItemView(),
                      ),
                    );
                  },
                ),
              ],
            ),
            body: viewModel.isLoading
                ? const Center(child: CircularProgressIndicator())
                : viewModel.errorMessage != null
                    ? Center(child: Text(viewModel.errorMessage!))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Recently Added
                            _buildSection(
                              title: "Recently added",
                              items: viewModel.recentlyAdded,
                              onSeeMore: () {
                                // Navigate to a full list page
                              },
                            ),
                            const SizedBox(height: 20),
                            // Old Posts
                            _buildSection(
                              title: "Old posts",
                              items: viewModel.oldPosts,
                              onSeeMore: () {},
                            ),
                          ],
                        ),
                      ),
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Map<String, dynamic>> items,
    required VoidCallback onSeeMore,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(onPressed: onSeeMore, child: const Text("See more")),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                width: 140,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: item['image_url'] != null
                          ? CachedNetworkImage(
                              imageUrl: item['image_url'],
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  const Center(child: CircularProgressIndicator()),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                            )
                          : const Icon(Icons.image, size: 60, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(item["title"],
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    Text("₺${item["price"]}",
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
