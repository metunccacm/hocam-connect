import 'package:flutter/material.dart';
import 'package:project/viewmodel/delivery_menu_viewmodel.dart';
import 'package:project/widgets/custom_appbar.dart';
import 'package:url_launcher/url_launcher.dart';

class RestaurantMenuView extends StatelessWidget {
  final Restaurant restaurant;

  const RestaurantMenuView({super.key, required this.restaurant});

  Future<void> _makePhoneCall(String phoneNumber) async {
    // Remove spaces and special characters to ensure the URI is valid
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: cleanNumber,
    );
    // Use externalApplication mode to ensure it opens the dialer
    if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $launchUri');
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    // Remove any non-digit characters for the API
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final Uri launchUri = Uri.parse('https://wa.me/$cleanNumber');
    
    if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $launchUri');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HCAppBar(
        title: restaurant.name,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 4 Clickable Menu Images
                  if (restaurant.menuUrls.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.7, // Portrait aspect ratio for menus
                      ),
                      itemCount: restaurant.menuUrls.length > 4 ? 4 : restaurant.menuUrls.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => _showFullImage(context, restaurant.menuUrls[index]),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              restaurant.menuUrls[index],
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  else
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text("No menu images available"),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Restaurant Name
                  Text(
                    restaurant.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),

                  // Description
                  if (restaurant.description != null) ...[
                    Text(
                      restaurant.description!,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Working Hours
                  if (restaurant.workingHours != null) ...[
                    const Row(
                      children: [
                        Icon(Icons.access_time, size: 20, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          "Working Hours",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 28.0),
                      child: Text(
                        restaurant.workingHours!,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Bottom Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: restaurant.phoneNumber != null 
                        ? () => _makePhoneCall(restaurant.phoneNumber!) 
                        : null,
                    icon: const Icon(Icons.call),
                    label: const Text("Call"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: restaurant.phoneNumber != null 
                        ? () => _openWhatsApp(restaurant.phoneNumber!) 
                        : null,
                    icon: const Icon(Icons.message), // Ideally use a WhatsApp icon asset
                    label: const Text("WhatsApp"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366), // WhatsApp color
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(imageUrl),
            ),
          ),
        ),
      ),
    );
  }
}
