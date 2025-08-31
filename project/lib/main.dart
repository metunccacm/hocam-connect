import 'package:flutter/material.dart';
import 'package:project/view/bottombar_view.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'view/login_view.dart';
import 'view/register_view.dart';
import 'view/welcome_view.dart';

import 'viewmodel/login_viewmodel.dart';
import 'viewmodel/marketplace_viewmodel.dart'; // <-- Import the viewmodel
import 'viewmodel/register_viewmodel.dart';

// SUPA CONNECTION //
const supabaseUrl = 'https://supa-api.avarion.com.tr';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE';


class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;

    // 1) Immediate check: if already logged in, jump to MainTabView
    if (auth.currentSession != null) {
      return const MainTabView();
    }

    // 2) Otherwise, listen for future auth changes
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snap) {
        // Tiny splash while waiting the first tick
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final signedIn = auth.currentSession != null ||
            snap.data?.event == AuthChangeEvent.signedIn;

        // If you want to show a Welcome screen before Login, keep WelcomeView
        return signedIn ? const MainTabView() : const WelcomeView();
      },
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LoginViewModel>(
          create: (context) => LoginViewModel(),
        ),
        ChangeNotifierProvider<RegistrationViewModel>(
          create: (context) => RegistrationViewModel(),
        ),
        ChangeNotifierProvider<MarketplaceViewModel>(
          create: (context) => MarketplaceViewModel(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hocam Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF007BFF),
          onPrimary: Colors.white,
          secondary: Color(0xFFF0F0F0),
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: const BorderSide(color: Color(0xFFF0F0F0)),
          ),
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: Colors.black54),
          hintStyle: const TextStyle(color: Colors.black38),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007BFF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),

      // IMPORTANT: AuthGate is the root
      home: const AuthGate(),

      // ROUTES
      routes: {
        '/login': (_) => const LoginView(),
        '/welcome': (_) => const WelcomeView(),
        '/register': (_) => const RegistrationView(),
        // '/home' and '/marketplace' are now handled by MainTabView
        // and should be removed from here to avoid confusion.
      },
    );
  }
}
