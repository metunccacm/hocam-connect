import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:project/viewmodel/delivery_menu_viewmodel.dart';
import 'package:project/view/restaurant_menu_view.dart';
import 'package:project/widgets/custom_appbar.dart';

class DeliveryMenuView extends StatelessWidget {
  const DeliveryMenuView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DeliveryMenuViewModel(),
      child: Scaffold(
        appBar: const HCAppBar(
          title: 'Restaurants',
        ),
        body: Consumer<DeliveryMenuViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (viewModel.errorMessage != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(viewModel.errorMessage!),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: viewModel.fetchRestaurants,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (viewModel.restaurants.isEmpty) {
              return const Center(child: Text('No restaurants found.'));
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0, // Square elements
              ),
              itemCount: viewModel.restaurants.length,
              itemBuilder: (context, index) {
                final restaurant = viewModel.restaurants[index];
                return _buildRestaurantCard(context, restaurant);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildRestaurantCard(BuildContext context, Restaurant restaurant) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RestaurantMenuView(restaurant: restaurant),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image or Icon
              if (restaurant.logoUrl != null)
                Image.network(
                  restaurant.logoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.restaurant,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.restaurant,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              
              // Gradient overlay for text readability
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    restaurant.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
