import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:project/widgets/custom_appbar.dart'; // Assuming you have this custom app bar

class ExternalLinksView extends StatelessWidget {
  const ExternalLinksView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HCAppBar(
        title: 'External Links',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Center(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _externalLinkActions(context),
          ),
        ),
      ),
    );
  }

  // Helper function to build the tiles, adapted from your HomeView
  Widget _tile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    const double tileSize = 96;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: tileSize,
          height: tileSize,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper function to launch URLs safely
  Future<void> _launchURL(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the website: $url')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening link: $e')),
      );
    }
  }

  // List of the action buttons
  List<Widget> _externalLinkActions(BuildContext context) {
    return [
       _tile(
        context: context,
        icon: Icons.calendar_today_rounded,
        label: 'CET',
        gradient: const [Color(0xFF614385), Color(0xFF516395)],
        onTap: () => _launchURL(context, 'https://cet.ncc.metu.edu.tr/'),
      ),
      _tile(
        context: context,
        icon: Icons.private_connectivity_outlined,
        label: 'Intranet',
        gradient: const [Color(0xFFFC5C7D), Color(0xFF6A82FB)],
        onTap: () => _launchURL(context, 'https://intranet.ncc.metu.edu.tr/'),
      ),
      _tile(
        context: context,
        icon: Icons.school,
        label: 'ODTUCLASS',
        gradient: const [Color(0xFF00C6FF), Color(0xFF0072FF)],
        onTap: () => _launchURL(context, 'https://odtuclass2025f.metu.edu.tr/'),
      ),
       _tile(
        context: context,
        icon: Icons.campaign_rounded,
        label: 'TWOC',
        gradient: const [Color(0xFFee0979), Color(0xFFff6a00)],
        onTap: () {
            // TWOC navigates to a route, not an external URL
            Navigator.pushNamed(context, '/twoc');
        },
      ),
    ];
  }
}