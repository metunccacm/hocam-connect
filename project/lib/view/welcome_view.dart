import 'package:flutter/material.dart';
import '../config/size_config.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: getProportionateScreenWidth(24.0),
            vertical:
                getProportionateScreenHeight(24.0), // daha az üst-alt padding
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Spacer to push logo to center between top and buttons
              const Spacer(),

              // --- Logo with proper aspect ratio (centered) ---
              Center(
                child: Builder(
                  builder: (context) {
                    final w = MediaQuery.of(context).size.width;
                    // Logo is trimmed (2619x1440 = ~1.82:1 aspect ratio)
                    final logoWidth = (w * 0.75).clamp(280.0, 500.0);
                    final logoHeight = logoWidth * 0.55;
                    return SizedBox(
                      width: logoWidth,
                      height: logoHeight,
                      child: Image.asset(
                        isDark 
                            ? 'assets/hc_logo/hc_logo_bw.png' 
                            : 'assets/hc_logo/hc_logo_color.png',
                        fit: BoxFit.contain,
                      ),
                    );
                  },
                ),
              ),

              SizedBox(height: getProportionateScreenHeight(6)),

              Text(
                'by',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(15),
                  fontWeight: FontWeight.w400,
                  color: colorScheme.onSurface,
                  height: 1.0, // satır aralığını da sıkı tut
                ),
              ),

              SizedBox(height: getProportionateScreenHeight(6)),

              Center(
                child: Image.asset(
                  'assets/logo/acm_logo.png',
                  height: getProportionateScreenHeight(48), // 60 → 48
                  fit: BoxFit.contain,
                ),
              ),

              // Spacer to push buttons to bottom
              const Spacer(),

              // --- Get Started ---
              SizedBox(
                height: getProportionateScreenHeight(60),
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0092CF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        getProportionateScreenWidth(35),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: getProportionateScreenWidth(32),
                      vertical: getProportionateScreenHeight(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(20),
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              SizedBox(height: getProportionateScreenHeight(14)),

              // --- Login link ---
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/login'),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Already have an account?',
                          style: TextStyle(
                            fontSize: getProportionateScreenWidth(15),
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        TextSpan(
                          text: ' Log in',
                          style: TextStyle(
                            fontSize: getProportionateScreenWidth(15),
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: getProportionateScreenHeight(16)),

              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/register-request'),
                  child: Text(
                    "Register request for non-metunian users",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(14),
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),

              SizedBox(height: getProportionateScreenHeight(8)),
            ],
          ),
        ),
      ),
    );
  }
}
