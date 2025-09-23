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
            vertical: getProportionateScreenHeight(24.0), // daha az üst-alt padding
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // --- ÜST BLOK: birbirine yakın ---
              Center(
                child: SizedBox(
                  height: getProportionateScreenHeight(550), // önceki 500 çok büyüktü
                  child: Image.asset(
                    'assets/images/hc_beta.png', // svg ile değişecek
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              SizedBox(height: getProportionateScreenHeight(6)),

              Text(
                'by',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(15),
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF3D003E),
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

              // --- Orta alanı boş bırakma, aşağıyı tek Spacer ile it ---
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

              SizedBox(height: getProportionateScreenHeight(8)),
            ],
          ),
        ),
      ),
    );
  }
}
