import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
      darkGradient: const [Color(0xFF0F4C75), Color(0xFF3282B8)],
      lightGradient: const [Color(0xFFE3F2FD), Color(0xFF90CAF9)],
      imagePath: 'assets/onboarding1.svg',
    ),
    OnboardingPageData(
      tag: 'Academics',
      title: 'Master Your Grades & Quick Links',
      body:
          'Calculate your CGPA using department-specific templates and access all essential school websites in one tap.',
      highlights: const ['CGPA templates', 'One-tap portals'],
      darkGradient: const [Color(0xFF0F3D3E), Color(0xFF145DA0)],
      lightGradient: const [Color(0xFFE0F2F1), Color(0xFF80CBC4)],
      imagePath: 'assets/onboarding2.svg',
    ),
    OnboardingPageData(
      tag: 'Mobility',
      title: 'Catch a Ride, Make a Friend',
      body:
          'Secure hitchhiking between students. Find a ride across campus or back to town easily.',
      highlights: const ['Student-only rides', 'Safety-first matching'],
      darkGradient: const [Color(0xFF16222A), Color(0xFF3A6073)],
      lightGradient: const [Color(0xFFECEFF1), Color(0xFFB0BEC5)],
      imagePath: 'assets/onboarding3.svg',
    ),
    OnboardingPageData(
      tag: 'Food & Dining',
      title: 'Fuel Up Fast',
      body:
          'Check cafeteria menus instantly or browse off-campus restaurants and order directly via WhatsApp.',
      highlights: const ['Live cafeteria menus', 'WhatsApp ordering'],
      darkGradient: const [Color(0xFFEE7724), Color(0xFFD8363A)],
      lightGradient: const [Color(0xFFFFF3E0), Color(0xFFFFCC80)],
      imagePath: 'assets/onboarding4.svg',
    ),
    OnboardingPageData(
      tag: 'Ready?',
      title: 'Join the Community',
      body:
          'Everything you need to thrive on campus lives here. Verify once, and you are in.',
      highlights: const ['Unified student hub', 'Switch to home anytime'],
      darkGradient: const [Color(0xFF0B1026), Color(0xFF163F93)],
      lightGradient: const [Color(0xFFE8EAF6), Color(0xFF9FA8DA)],
      imagePath: 'assets/onboarding5.svg',
      ctaLabel: 'Go to Home',
    ),
  ];

  void _handlePageChange(int index) {
    setState(() => _activePage = index);
  }

  Future<void> _markOnboardingSeen() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    debugPrint('📝 Attempting to mark onboarding as seen for user: $userId');
    
    if (userId == null) {
      debugPrint('❌ Cannot mark onboarding seen: User ID is null');
      return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen_$userId', true);
    debugPrint('✅ Onboarding successfully marked as seen in SharedPreferences');
  }

  Future<void> _goToHome() async {
    await _markOnboardingSeen();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 OnboardingView build called');
    final goldenSpacing = _baseSpacing * _phi;
    final isLastPage = _activePage == _pages.length - 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomTextStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isDark ? Colors.white70 : Colors.black54,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark ? data.darkGradient : data.lightGradient;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white.withOpacity(0.85) : Colors.black54;
    final decorationColor = isDark ? Colors.white : Colors.black;

    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.headlineMedium?.copyWith(
      color: textColor,
      fontWeight: FontWeight.w700,
      height: 1.05,
    );
    final bodyStyle = textTheme.bodyLarge?.copyWith(
      color: subTextColor,
      height: 1.45,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: goldenSpacing * 0.9 + goldenSpacing / 1.4),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: goldenSpacing),
            child: _TagPill(
              label: data.tag,
              baseSpacing: baseSpacing,
              textColor: textColor,
              decorationColor: decorationColor,
            ),
          ),
          SizedBox(height: goldenSpacing / 1.2),
          AspectRatio(
            aspectRatio: 1.0,
            child: _OnboardingImage(
              data: data,
              baseSpacing: baseSpacing,
              iconColor: decorationColor,
            ),
          ),
          SizedBox(height: goldenSpacing),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: goldenSpacing),
            child: Text(data.title, style: titleStyle),
          ),
          SizedBox(height: baseSpacing * 0.9),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: goldenSpacing),
            child: Text(data.body, style: bodyStyle),
          ),
          SizedBox(height: goldenSpacing / 1.1),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: goldenSpacing),
            child: Wrap(
              spacing: baseSpacing * 0.7,
              runSpacing: baseSpacing * 0.6,
              children: data.highlights
                  .map((item) => _HighlightChip(
                        label: item,
                        baseSpacing: baseSpacing,
                        textColor: textColor,
                        decorationColor: decorationColor,
                      ))
                  .toList(),
            ),
          ),
          const Spacer(),
          if (isLast)
            Padding(
              padding: EdgeInsets.only(
                left: goldenSpacing,
                right: goldenSpacing,
                bottom: goldenSpacing * 0.9,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black87,
                    foregroundColor: isDark ? gradient.last : Colors.white,
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
              ),
            )
          else
            SizedBox(height: goldenSpacing * 0.9),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;
  final double baseSpacing;
  final Color textColor;
  final Color decorationColor;

  const _TagPill({
    required this.label,
    required this.baseSpacing,
    required this.textColor,
    required this.decorationColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: baseSpacing * 0.9,
        vertical: baseSpacing * 0.45,
      ),
      decoration: BoxDecoration(
        color: decorationColor.withOpacity(0.14),
        borderRadius: BorderRadius.circular(baseSpacing * 1.2),
        border: Border.all(color: decorationColor.withOpacity(0.24)),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
      ),
    );
  }
}

class _OnboardingImage extends StatelessWidget {
  final OnboardingPageData data;
  final double baseSpacing;
  final Color iconColor;

  const _OnboardingImage({
    required this.data,
    required this.baseSpacing,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    if (data.imagePath != null) {
      return SvgPicture.asset(
        data.imagePath!,
        fit: BoxFit.contain,
      );
    }
    return _ImagePlaceholder(
      icon: data.icon ?? Icons.error,
      baseSpacing: baseSpacing,
      iconColor: iconColor,
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final IconData? icon;
  final double baseSpacing;
  final Color iconColor;

  const _ImagePlaceholder({
    required this.icon,
    required this.baseSpacing,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(baseSpacing * _phi),
        border: Border.all(color: iconColor.withOpacity(0.18)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: baseSpacing * _phi * 2.4,
              color: iconColor,
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
  final Color textColor;
  final Color decorationColor;

  const _HighlightChip({
    required this.label,
    required this.baseSpacing,
    required this.textColor,
    required this.decorationColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: baseSpacing * 0.8,
        vertical: baseSpacing * 0.45,
      ),
      decoration: BoxDecoration(
        color: decorationColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(baseSpacing * 1.1),
        border: Border.all(color: decorationColor.withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 16, color: textColor.withOpacity(0.7)),
          SizedBox(width: baseSpacing * 0.4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: textColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final indicatorColor = isDark ? Colors.white : Colors.black87;

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
              color: indicatorColor.withOpacity(isActive ? 0.95 : 0.4),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bgColor = isDark ? Colors.black.withOpacity(0.15) : Colors.black.withOpacity(0.08);

    return Positioned(
      top: _baseSpacing,
      right: _baseSpacing,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: textColor,
          backgroundColor: bgColor,
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
  final List<Color> darkGradient;
  final List<Color> lightGradient;
  final IconData? icon;
  final String? ctaLabel;
  final String? imagePath;

  const OnboardingPageData({
    required this.tag,
    required this.title,
    required this.body,
    required this.highlights,
    required this.darkGradient,
    required this.lightGradient,
    this.icon,
    this.ctaLabel,
    this.imagePath,
  });
}