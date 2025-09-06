import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'view/home_view.dart';
import 'view/login_view.dart';
import 'view/register_view.dart';
import 'view/welcome_view.dart';
import 'view/gpa_calculator_view.dart';
import 'viewmodel/login_viewmodel.dart';
import 'viewmodel/register_viewmodel.dart';

// Theme Controller
import 'theme_controller.dart';

// SUPA CONNECTION //
const supabaseUrl = 'https://supa-api.avarion.com.tr';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;

    // 1) Already signed in → Home
    if (auth.currentSession != null) {
      return const HomeView();
    }

    // 2) Otherwise, listen future auth changes
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final signedIn = auth.currentSession != null ||
            snap.data?.event == AuthChangeEvent.signedIn;

        return signedIn ? const HomeView() : const WelcomeView();
      },
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    debug: true,
  );

  // Theme tercihlerini yükle (kalıcı)
  await ThemeController.instance.load();

  // Debug: auth transitions
  Supabase.instance.client.auth.onAuthStateChange
      .listen((s) => debugPrint('Auth event: ${s.event}, session: ${s.session != null}'));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LoginViewModel>(
          create: (_) => LoginViewModel(),
        ),
        ChangeNotifierProvider<RegistrationViewModel>(
          create: (_) => RegistrationViewModel(),
        ),
        // ThemeController tekil instance'ı sağlayalım
        ChangeNotifierProvider<ThemeController>.value(
          value: ThemeController.instance,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF007BFF),
        onPrimary: Colors.white,
        secondary: Color(0xFFF0F0F0),
      ),
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
    );
  }

  ThemeData _darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      // Dark color scheme aynı primary ile
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF007BFF),
        secondary: Color(0xFF1F1F1F),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        filled: true,
        fillColor: Colors.black12,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white54),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // Provider üzerinden tema modunu dinle
    final themeController = context.watch<ThemeController>();

    return MaterialApp(
      title: 'Hocam Connect',
      debugShowCheckedModeBanner: false,

      // ← En kritik satır
      themeMode: themeController.mode,

      theme: _lightTheme(),
      darkTheme: _darkTheme(),

      // IMPORTANT: AuthGate is the root; don’t use initialRoute to flip pages.
      home: const AuthGate(),

      // ROUTES
      routes: {
        '/login': (_) => const LoginView(),
        '/welcome': (_) => const WelcomeView(),
        '/home': (_) => const HomeView(),
        '/register': (_) => const RegistrationView(),
        '/gpa_calculator': (_) =>  const GpaCalculatorView(),
      },
    );
  }
}
