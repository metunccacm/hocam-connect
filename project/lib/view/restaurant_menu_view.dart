import 'package:flutter/material.dart';
import 'package:project/viewmodel/delivery_menu_viewmodel.dart';
import 'package:project/widgets/custom_appbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RestaurantMenuView extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantMenuView({super.key, required this.restaurant});

  @override
  State<RestaurantMenuView> createState() => _RestaurantMenuViewState();
}

class _RestaurantMenuViewState extends State<RestaurantMenuView> {
  late Restaurant _restaurant;
  int? _userRating;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _restaurant = widget.restaurant;
    _loadRestaurantData();
  }

  Future<void> _loadRestaurantData() async {
    try {
      final restaurant = await DeliveryMenuViewModel.fetchRestaurantWithRating(widget.restaurant.id);
      final userRating = await DeliveryMenuViewModel.getUserRating(widget.restaurant.id);
      
      if (mounted) {
        setState(() {
          _restaurant = restaurant;
          _userRating = userRating;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading restaurant data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildStarRating(double rating, int totalRatings, {bool interactive = false, int? userRating}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          final starValue = index + 1;
          IconData icon;
          Color color;

          if (interactive) {
            // Interactive mode for user rating
            icon = (userRating != null && starValue <= userRating)
                ? Icons.star
                : Icons.star_border;
            color = (userRating != null && starValue <= userRating)
                ? Colors.amber
                : Theme.of(context).colorScheme.outline;
          } else {
            // Display mode for average rating
            if (rating >= starValue) {
              icon = Icons.star;
              color = Colors.amber;
            } else if (rating >= starValue - 0.5) {
              icon = Icons.star_half;
              color = Colors.amber;
            } else {
              icon = Icons.star_border;
              color = Theme.of(context).colorScheme.outline;
            }
          }

          return Icon(icon, color: color, size: interactive ? 32 : 20);
        }),
        if (!interactive) ...[
          const SizedBox(width: 8),
          Text(
            '${rating.toStringAsFixed(1)} ($totalRatings)',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showRatingDialog() async {
    int tempRating = _userRating ?? 0;

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rate this restaurant'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tap to select your rating:'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  return IconButton(
                    icon: Icon(
                      starValue <= tempRating ? Icons.star : Icons.star_border,
                      color: starValue <= tempRating ? Colors.amber : Colors.grey,
                      size: 40,
                    ),
                    onPressed: () {
                      setState(() => tempRating = starValue);
                    },
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: tempRating == 0 ? null : () => Navigator.pop(dialogContext, tempRating),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        await DeliveryMenuViewModel.submitRating(widget.restaurant.id, result);
        await _loadRestaurantData(); // Reload to get updated average
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rating submitted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error submitting rating: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to submit rating'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

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
    // Show confirmation dialog before opening WhatsApp
    final bool? shouldLaunch = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Leave Hocam Connect?'),
          content: const Text(
              'You are about to open WhatsApp. Do you want to continue?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Cancel
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Continue
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (shouldLaunch == true) {
      // Remove any non-digit characters for the API
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
      final Uri launchUri = Uri.parse('https://wa.me/$cleanNumber');
      
      if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $launchUri');
      }
    }
  }

  Future<void> _showReportDialog(BuildContext context) async {
    final reasonController = TextEditingController();
    String? selectedReason;
    
    final reasons = [
      'Incorrect information',
      'Menu out of date',
      'Wrong phone number',
      'Restaurant closed',
      'Inappropriate content',
      'Other',
    ];

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Report Restaurant'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Please select a reason:'),
                const SizedBox(height: 16),
                ...reasons.map((reason) => RadioListTile<String>(
                  title: Text(reason),
                  value: reason,
                  // ignore: deprecated_member_use
                  groupValue: selectedReason,
                  // ignore: deprecated_member_use
                  onChanged: (value) {
                    setState(() => selectedReason = value);
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                )),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Additional details (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedReason == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedReason != null) {
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        await Supabase.instance.client.from('restaurant_reports').insert({
          'restaurant_id': _restaurant.id,
          'reporter_id': userId,
          'reason': selectedReason,
          'details': reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
          'created_at': DateTime.now().toIso8601String(),
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report submitted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error submitting report: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to submit report'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    
    reasonController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: HCAppBar(
          title: widget.restaurant.name,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: HCAppBar(
        title: _restaurant.name,
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.rate_review_outlined),
          //   onPressed: () => _showReviewDialog(context),
          //   tooltip: 'Write Review',
          // ),
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => _showReportDialog(context),
            tooltip: 'Report',
          ),
        ],
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
                  if (_restaurant.menuUrls.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.7, // Portrait aspect ratio for menus
                      ),
                      itemCount: _restaurant.menuUrls.length > 4 ? 4 : _restaurant.menuUrls.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => _showFullImage(context, _restaurant.menuUrls[index]),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _restaurant.menuUrls[index],
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: Icon(Icons.broken_image, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                    _restaurant.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 12),

                  // Rating Display
                  Row(
                    children: [
                      _buildStarRating(_restaurant.averageRating, _restaurant.totalRatings),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: _showRatingDialog,
                        icon: Icon(
                          _userRating != null ? Icons.star : Icons.star_border,
                          size: 18,
                        ),
                        label: Text(_userRating != null ? 'Update Rating' : 'Rate'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),

                  // Description
                  if (_restaurant.description != null) ...[
                    Text(
                      _restaurant.description!,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Working Hours
                  if (_restaurant.workingHours != null && _restaurant.workingHours!.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text(
                          "Çalışma Saatleri",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 28.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDayRow('Pazartesi', _restaurant.workingHours!['Pazartesi']),
                          _buildDayRow('Salı', _restaurant.workingHours!['Salı']),
                          _buildDayRow('Çarşamba', _restaurant.workingHours!['Çarşamba']),
                          _buildDayRow('Perşembe', _restaurant.workingHours!['Perşembe']),
                          _buildDayRow('Cuma', _restaurant.workingHours!['Cuma']),
                          _buildDayRow('Cumartesi', _restaurant.workingHours!['Cumartesi']),
                          _buildDayRow('Pazar', _restaurant.workingHours!['Pazar']),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          
          // Bottom Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                  offset: const Offset(0, -4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _restaurant.phoneNumber != null 
                        ? () => _makePhoneCall(_restaurant.phoneNumber!) 
                        : null,
                    icon: const Icon(Icons.call),
                    label: const Text("Call"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _restaurant.phoneNumber != null 
                        ? () async => await _openWhatsApp(_restaurant.phoneNumber!) 
                        : null,
                    icon: const Icon(Icons.message), // Ideally use a WhatsApp icon asset
                    label: const Text("WhatsApp"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366), // WhatsApp color
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
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

  Widget _buildDayRow(String day, String? hours) {
    if (hours == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              day,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            hours,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: IconThemeData(color: Theme.of(ctx).colorScheme.onSurface),
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
