import 'package:flutter/material.dart';
import 'package:project/view/bottombar_view.dart';
import 'package:project/view/forgot_password_view.dart';
import 'package:project/view/recovery_code_view.dart';
import 'package:project/view/reset_password_view.dart';
import 'package:project/view/this_week_view.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'view/login_view.dart';
import 'view/register_view.dart';
import 'view/welcome_view.dart';
import 'view/gpa_calculator_view.dart';
import 'view/cafeteria_menu_view.dart';

import 'viewmodel/login_viewmodel.dart';
import 'viewmodel/marketplace_viewmodel.dart';
import 'viewmodel/register_viewmodel.dart';

import 'view/hitchike_view.dart';
import 'view/create_hitchike_view.dart';
import 'viewmodel/hitchike_viewmodel.dart';
import 'viewmodel/create_hitchikepost_viewmodel.dart';

// Theme Controller
import 'theme_controller.dart';

// New import for the scaling utility
import 'config/size_config.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/social_user.dart';
import 'models/social_models.dart';
import 'services/social_repository.dart';
import 'view/social_view.dart';
import 'view/user_profile_view.dart';

// NEW: connectivity wrapper
import 'widgets/connectivity_gate.dart';

//SUPA CONNECTION
const supabaseUrl = 'https://supa-api.hocamconnect.com.tr';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzM1Njg5NjAwLCJleHAiOjIwMTUyMjI0MDB9.PPxdhq14kCFj1YBSat9ZLlfcwH5_kdOD09pmXnWNr4Q';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;

    if (auth.currentSession != null) {
      return const MainTabView();
    }

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

        return signedIn ? const MainTabView() : const WelcomeView();
      },
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  // Register adapters
  try {
    if (!Hive.isAdapterRegistered(40)) Hive.registerAdapter(SocialUserAdapter());
    if (!Hive.isAdapterRegistered(41)) Hive.registerAdapter(PostAdapter());
    if (!Hive.isAdapterRegistered(42)) Hive.registerAdapter(CommentAdapter());
    if (!Hive.isAdapterRegistered(43)) Hive.registerAdapter(LikeAdapter());
    if (!Hive.isAdapterRegistered(44)) Hive.registerAdapter(CommentLikeAdapter());
    if (!Hive.isAdapterRegistered(45)) Hive.registerAdapter(FriendshipAdapter());
    if (!Hive.isAdapterRegistered(46)) Hive.registerAdapter(FriendshipStatusAdapter());
  } catch (e) {
    print('Hive adapter registration error: $e');
  }
  // Open boxes
  try {
    await Hive.openBox<SocialUser>(LocalHiveSocialRepository.usersBox);
    await Hive.openBox<Post>(LocalHiveSocialRepository.postsBox);
    await Hive.openBox<Comment>(LocalHiveSocialRepository.commentsBox);
    await Hive.openBox<Like>(LocalHiveSocialRepository.likesBox);
    await Hive.openBox<CommentLike>(LocalHiveSocialRepository.commentLikesBox);
    await Hive.openBox<Friendship>(LocalHiveSocialRepository.friendshipsBox);
  } catch (e) {
    print('Hive box opening error: $e');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Global navigatorKey (used by password recovery)
  final navigatorKey = GlobalKey<NavigatorState>();

  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.passwordRecovery) {
      navigatorKey.currentState?.pushNamed('/reset-password');
    }
  });

  await ThemeController.instance.load();

  Supabase.instance.client.auth.onAuthStateChange.listen((s) =>
      debugPrint('Auth event: ${s.event}, session: ${s.session != null}'));

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
        ChangeNotifierProvider<ThemeController>.value(
          value: ThemeController.instance,
        ),
        ChangeNotifierProvider<ThemeController>.value(
          value: ThemeController.instance,
        ),
        ChangeNotifierProvider<HitchikeViewModel>(
          create: (context) => HitchikeViewModel(),
        ),
        ChangeNotifierProvider<CreateHitchikeViewModel>(
          create: (context) => CreateHitchikeViewModel(),
        ),
      ],
      child: MyApp(navigatorKey: navigatorKey),
    ),
  );
}

class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const MyApp({super.key, required this.navigatorKey});

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
    SizeConfig().init(context);

    return Consumer<ThemeController>(
      builder: (_, c, __) {
        return MaterialApp(
          navigatorKey: navigatorKey, // keep your password recovery flow working
          title: 'Hocam Connect',
          debugShowCheckedModeBanner: false,
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          themeMode: c.mode,
          // <<< Wrap everything with connectivity gate
          builder: (context, child) => ConnectivityGate(
            funnyMessages: const [
              'Polishing the antenna…',
              'Waving at the router 👋',
              'Asking packets to hurry up…',
              'Consulting the fiber oracle…',
            ],
            child: child ?? const SizedBox.shrink(),
          ),
          home: const AuthGate(),
          routes: {
            '/login': (_) => const LoginView(),
            '/welcome': (_) => const WelcomeView(),
            '/register': (_) => const RegistrationView(),
            '/cafeteria-menu': (_) => const CafeteriaMenuView(),
            '/gpa_calculator': (_) => const GpaCalculatorView(),
            '/forgot-password': (_) => const ForgotPasswordView(),
            '/twoc': (_) => const ThisWeekView(),
            '/home': (_) => const MainTabView(),
            '/recovery-code': (_) => const RecoveryCodeView(),
            '/reset-password': (_) => const ResetPasswordView(),
            '/hitchike': (_) => const HitchikeView(),
            '/hitchike/create': (_) => const CreateHitchikeView(),
            '/social': (_) => const SocialView(),
            '/user-profile': (ctx) {
              final args = ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?;
              final userId = args?['userId'] as String?;
              final repo = args?['repo'] as SocialRepository?;
              if (userId == null) {
                return const Scaffold(body: Center(child: Text('Kullanıcı bulunamadı')));
              }
              final fallback = repo ?? LocalHiveSocialRepository();
              return UserProfileView(userId: userId, repository: fallback);
            },
          },
        );
      },
    );
  }
}
