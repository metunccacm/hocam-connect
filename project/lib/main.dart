import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'view/home_view.dart';
import 'view/login_view.dart';
import 'viewmodel/login_viewmodel.dart';

// IMPORTANT: Replace with your actual Supabase credentials
const supabaseUrl = 'YOUR_SUPABASE_URL';
const supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(
    ChangeNotifierProvider<LoginViewModel>(
      create: (context) => LoginViewModel(),
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
      theme: ThemeData(
        // Setting a light theme for the Figma design
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white, // White background
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF007BFF), // A vibrant blue for primary elements
          onPrimary: Colors.white,
          secondary: Color(0xFFF0F0F0),
        ),
        useMaterial3: true,
        // Define the text field theme
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0), // Rounded corners for fields
            borderSide: const BorderSide(color: Color(0xFFF0F0F0)),
          ),
          filled: true,
          fillColor: Colors.white, // White background for text fields
          labelStyle: const TextStyle(color: Colors.black54),
          hintStyle: const TextStyle(color: Colors.black38),
        ),
        // Define the button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007BFF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginView(),
        '/home': (context) => const HomeView(),
      },
    );
  }
}
