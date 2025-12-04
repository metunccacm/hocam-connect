import 'package:flutter/material.dart';
import 'package:liquid_swipe/liquid_swipe.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const double _phi = 1.618; // Golden ratio for spatial rhythm
const double _baseSpacing = 16.0;

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final LiquidController _controller = LiquidController();
  int _activePage = 0;

  late final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      tag: 'Marketplace',
      title: 'Your Campus Bazaar',
      body:
          'Buy and sell textbooks, dorm gear, and essentials with fellow students. DM safely within the app to connect.',
      highlights: const ['Peer-to-peer deals', 'Secure DMs'],
      gradient: const [Color(0xFF0F4C75), Color(0xFF3282B8)],
      icon: Icons.storefront_rounded,
    ),
    OnboardingPageData(
      tag: 'Academics',
      title: 'Master Your Grades & Quick Links',
      body:
          'Calculate your CGPA using department-specific templates and access all essential school websites in one tap.',
      highlights: const ['CGPA templates', 'One-tap portals'],
      gradient: const [Color(0xFF0F3D3E), Color(0xFF145DA0)],
      icon: Icons.school_outlined,
    ),
    OnboardingPageData(
      tag: 'Mobility',
      title: 'Catch a Ride, Make a Friend',
      body:
          'Secure hitchhiking between students. Find a ride across campus or back to town easily.',
      highlights: const ['Student-only rides', 'Safety-first matching'],
      gradient: const [Color(0xFF16222A), Color(0xFF3A6073)],
      icon: Icons.directions_car_filled_outlined,
    ),
    OnboardingPageData(
      tag: 'Food & Dining',
      title: 'Fuel Up Fast',
      body:
          'Check cafeteria menus instantly or browse off-campus restaurants and order directly via WhatsApp.',
      highlights: const ['Live cafeteria menus', 'WhatsApp ordering'],
      gradient: const [Color(0xFFEE7724), Color(0xFFD8363A)],
      icon: Icons.fastfood_outlined,
    ),
    OnboardingPageData(
      tag: 'Ready?',
      title: 'Join the Community',
      body:
          'Everything you need to thrive on campus lives here. Verify once, and you are in.',
      highlights: const ['Unified student hub', 'Switch to home anytime'],
      gradient: const [Color(0xFF0B1026), Color(0xFF163F93)],
      icon: Icons.verified_user_outlined,
      ctaLabel: 'Go to Home',
    ),
  ];

  void _handlePageChange(int index) {
    setState(() => _activePage = index);
  }

  Future<void> _markOnboardingSeen() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen_$userId', true);
  }

  Future<void> _goToHome() async {
    await _markOnboardingSeen();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    final goldenSpacing = _baseSpacing * _phi;
    final isLastPage = _activePage == _pages.length - 1;
    final bottomTextStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white70,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        );

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            LiquidSwipe(
              pages: List.generate(
                _pages.length,
                (index) => _OnboardingPage(
                  data: _pages[index],
                  goldenSpacing: goldenSpacing,
                  baseSpacing: _baseSpacing,
                  isLast: index == _pages.length - 1,
                  onPrimaryAction: _goToHome,
                ),
              ),
              liquidController: _controller,
              enableLoop: false,
              fullTransitionValue: 600,
              // Enable liquid effect both directions without peeking the next page.
              enableSideReveal: false,
              waveType: WaveType.liquidReveal,
              onPageChangeCallback: _handlePageChange,
            ),
            _SkipButton(onTap: _goToHome),
            Positioned(
              bottom: goldenSpacing,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isLastPage)
                    Padding(
                      padding: EdgeInsets.only(bottom: _baseSpacing * 0.8),
                      child: Text(
                        'Swipe to continue',
                        style: bottomTextStyle,
                      ),
                    ),
                  _PageIndicator(
                    total: _pages.length,
                    active: _activePage,
                    goldenSpacing: goldenSpacing,
                    baseSpacing: _baseSpacing,
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

class _OnboardingPage extends StatelessWidget {
  final OnboardingPageData data;
  final double goldenSpacing;
  final double baseSpacing;
  final bool isLast;
  final VoidCallback onPrimaryAction;

  const _OnboardingPage({
    required this.data,
    required this.goldenSpacing,
    required this.baseSpacing,
    required this.isLast,
    required this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.headlineMedium?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      height: 1.05,
    );
    final bodyStyle = textTheme.bodyLarge?.copyWith(
      color: Colors.white.withOpacity(0.85),
      height: 1.45,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: data.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: goldenSpacing,
          vertical: goldenSpacing * 0.9,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: goldenSpacing / 1.4),
            _TagPill(label: data.tag, baseSpacing: baseSpacing),
            SizedBox(height: goldenSpacing / 1.2),
            AspectRatio(
              aspectRatio: _phi,
              child: _ImagePlaceholder(
                icon: data.icon,
                baseSpacing: baseSpacing,
              ),
            ),
            SizedBox(height: goldenSpacing),
            Text(data.title, style: titleStyle),
            SizedBox(height: baseSpacing * 0.9),
            Text(data.body, style: bodyStyle),
            SizedBox(height: goldenSpacing / 1.1),
            Wrap(
              spacing: baseSpacing * 0.7,
              runSpacing: baseSpacing * 0.6,
              children: data.highlights
                  .map((item) => _HighlightChip(
                        label: item,
                        baseSpacing: baseSpacing,
                      ))
                  .toList(),
            ),
            const Spacer(),
            if (isLast)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: data.gradient.last,
                    minimumSize: Size(double.infinity, goldenSpacing),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(baseSpacing * 1.1),
                    ),
                    elevation: 0,
                  ),
                  onPressed: onPrimaryAction,
                  child: Text(
                    data.ctaLabel ?? 'Get Started',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;
  final double baseSpacing;

  const _TagPill({required this.label, required this.baseSpacing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: baseSpacing * 0.9,
        vertical: baseSpacing * 0.45,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(baseSpacing * 1.2),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final IconData icon;
  final double baseSpacing;

  const _ImagePlaceholder({
    required this.icon,
    required this.baseSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(baseSpacing * _phi),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: baseSpacing * _phi * 2.4,
              color: Colors.white,
            ),
            SizedBox(height: baseSpacing / _phi),
            Text(
              'Add your illustration here',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white70,
                    letterSpacing: 0.2,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  final String label;
  final double baseSpacing;

  const _HighlightChip({
    required this.label,
    required this.baseSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: baseSpacing * 0.8,
        vertical: baseSpacing * 0.45,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(baseSpacing * 1.1),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.white70),
          SizedBox(width: baseSpacing * 0.4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int total;
  final int active;
  final double goldenSpacing;
  final double baseSpacing;

  const _PageIndicator({
    required this.total,
    required this.active,
    required this.goldenSpacing,
    required this.baseSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        total,
        (index) {
          final isActive = index == active;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            margin: EdgeInsets.symmetric(horizontal: baseSpacing * 0.35),
            width: isActive ? goldenSpacing / 1.3 : baseSpacing * 0.8,
            height: baseSpacing * 0.3,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(isActive ? 0.95 : 0.4),
              borderRadius: BorderRadius.circular(baseSpacing),
            ),
          );
        },
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SkipButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: _baseSpacing,
      right: _baseSpacing,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.black.withOpacity(0.15),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        onPressed: onTap,
        child: const Text(
          'Skip',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class OnboardingPageData {
  final String tag;
  final String title;
  final String body;
  final List<String> highlights;
  final List<Color> gradient;
  final IconData icon;
  final String? ctaLabel;

  const OnboardingPageData({
    required this.tag,
    required this.title,
    required this.body,
    required this.highlights,
    required this.gradient,
    required this.icon,
    this.ctaLabel,
  });
}