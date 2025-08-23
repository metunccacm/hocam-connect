import 'package:flutter/material.dart';
import '../config/size_config.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: getProportionateScreenWidth(24.0),
            vertical: getProportionateScreenHeight(48.0),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(flex: 2),

              // Use a SizedBox to set a proportional size for the logo
              SizedBox(
                height: getProportionateScreenHeight(150),
                child: Center(
                  child: Image.asset(
                    'assets/logo/hc_logo.png',
                  ),
                ),
              ),

              SizedBox(height: getProportionateScreenHeight(30)),

              // "Welcome to Hocam Connect" text
              Text(
                'Welcome to Hocam Connect',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(15),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF3D003E),
                ),
              ),

              // "by" text
              Text(
                'by',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(15),
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF3D003E),
                ),
              ),

              SizedBox(height: getProportionateScreenHeight(10)),

              // ACM logo
              Center(
                child: Image.asset(
                  'assets/logo/acm_logo.png',
                  height: getProportionateScreenHeight(77),
                ),
              ),

              const Spacer(flex: 3),

              // "Get Started" button
              SizedBox(
                height: getProportionateScreenHeight(70),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0092CF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(getProportionateScreenWidth(35)),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: getProportionateScreenWidth(32),
                      vertical: getProportionateScreenHeight(16),
                    ),
                  ),
                  child: Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(21),
                      color: const Color(0xFFFFFFFF),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),

              SizedBox(height: getProportionateScreenHeight(20)),

              // "Already have an account? Log in" text
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Already have an account?',
                          style: TextStyle(
                            fontSize: getProportionateScreenWidth(15),
                            color: const Color(0xFF3D003E),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        TextSpan(
                          text: ' Log in',
                          style: TextStyle(
                            fontSize: getProportionateScreenWidth(15),
                            color: const Color(0xFF3D003E),
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}