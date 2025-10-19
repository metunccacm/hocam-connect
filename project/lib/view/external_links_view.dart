import 'dart:ui'; 

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalLinksView extends StatelessWidget {
  const ExternalLinksView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Links & Resources'),
        automaticallyImplyLeading: false, 
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        // CHANGE 1: Use a Column for single-row display
        child: Column( 
          crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch children to full width
          children: _linkActions(context),
        ),
      ),
    );
  }

  // New larger tile widget using a background image and blur
  Widget _imageTile({
    required BuildContext context,
    required String label,
    required String imagePath, // Path to the asset image
    required VoidCallback onTap,
  }) {
    // CHANGE 2: Set tile width to null to use the parent's full width (via Column/stretch)
    const double tileHeight = 150; // Increased height for better visual impact

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0), // Add vertical space between buttons
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            // Removed width constraint: will stretch
            height: tileHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Background Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, obj, trace) {
                      return Container(color: Theme.of(context).colorScheme.primary.withOpacity(0.8));
                    },
                  ),
                ),

                // 2. Blurred/Dark Overlay for text readability
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5), 
                    child: Container(
                      color: Colors.black.withOpacity(0.35), 
                    ),
                  ),
                ),

                // 3. Label Text
                Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22, // Slightly increased font size
                      fontWeight: FontWeight.w800, 
                      letterSpacing: 0.8,
                      shadows: [
                        Shadow(
                          blurRadius: 3.0,
                          color: Colors.black87,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper to launch URLs safely (unchanged)
  Future<void> _launchURL(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the website: $url')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening link: $e')),
      );
    }
  }

  // List of the action buttons using the new _imageTile
  List<Widget> _linkActions(BuildContext context) {
    return [
      _imageTile(
        context: context,
        label: 'ODTÜCLASS',
        imagePath: 'assets/images/odtuclass_bg.png',
        onTap: () => _launchURL(context, 'https://odtuclass2025f.metu.edu.tr/'),
      ),
      _imageTile(
        context: context,
        label: 'INTRANET',
        imagePath: 'assets/images/intranet_bg.png',
        onTap: () => _launchURL(context, 'https://intranet.ncc.metu.edu.tr/'),
      ),
      _imageTile(
        context: context,
        label: 'CET (Course Timetable)',
        imagePath: 'assets/images/cet_bg.png',
        onTap: () => _launchURL(context, 'https://cet.ncc.metu.edu.tr/'),
      ),
      _imageTile(
        context: context,
        label: 'This Week On Campus',
        imagePath: 'assets/images/twoc_bg.png',
        onTap: () => Navigator.pushNamed(context, '/twoc'),
      ),
    ];
  }
}