import 'package:flutter/material.dart';
import 'package:project/view/bottombar_view.dart';
import 'package:project/view/forgot_password_view.dart';
import 'package:project/view/recovery_code_view.dart';
import 'package:project/view/reset_password_view.dart';
import 'package:project/view/this_week_view.dart';
import 'package:project/view/webmail_view.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'view/login_view.dart';
import 'view/register_view.dart';
import 'view/welcome_view.dart';
import 'view/gpa_calculator_view.dart';
import 'view/cafeteria_menu_view.dart';
import 'view/chat_view.dart';

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

// Notification Service
import 'services/notification_service.dart';
import 'services/app_lifecycle_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/social_user.dart';
import 'models/social_models.dart';
import 'services/social_repository.dart';
import 'view/social_view.dart';
import 'view/user_profile_view.dart';
import 'view/splash_view.dart';
import 'view/notification_debug_view.dart';

// NEW: connectivity wrapper
import 'widgets/connectivity_gate.dart';

//SUPA CONNECTION
const supabaseUrl = 'https://supa-api.hocamconnect.com.tr';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzM1Njg5NjAwLCJleHAiOjIwMTUyMjI0MDB9.PPxdhq14kCFj1YBSat9ZLlfcwH5_kdOD09pmXnWNr4Q';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Listen for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    // Check for pending navigation from notification tap
    _checkPendingNavigation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('📱 App lifecycle changed to: $state');
    
    // When app resumes from background, check for pending navigation
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 App resumed - checking for pending navigation...');
      _checkPendingNavigation();
    }
  }

  Future<void> _checkPendingNavigation() async {
    debugPrint('🔍 ========== CHECKING PENDING NAVIGATION ==========');
    
    // Wait a bit for the app to fully initialize
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) {
      debugPrint('❌ Widget not mounted, skipping navigation check');
      return;
    }
    
    // Check if there's a pending chat navigation
    final conversationId = NotificationService().getPendingChatNavigation();
    debugPrint('📱 Pending conversation ID: $conversationId');
    
    if (conversationId != null) {
      debugPrint('✅ Found pending navigation to: $conversationId');
      
      // Wait for authentication to complete
      final auth = Supabase.instance.client.auth;
      final session = auth.currentSession;
      debugPrint('🔐 Auth session exists: ${session != null}');
      
      if (session != null) {
        debugPrint('🚀 Starting navigation to chat...');
        // Navigate to chat view
        await _navigateToChat(conversationId);
      } else {
        debugPrint('❌ No auth session, cannot navigate');
      }
    } else {
      debugPrint('ℹ️ No pending navigation found');
    }
    debugPrint('================================================');
  }

  Future<void> _navigateToChat(String conversationId) async {
    debugPrint('🗺️ ========== NAVIGATING TO CHAT ==========');
    debugPrint('   Conversation ID: $conversationId');
    
    if (!mounted) {
      debugPrint('❌ Widget not mounted');
      return;
    }
    
    try {
      // Get conversation details to show proper title
      final supa = Supabase.instance.client;
      final currentUserId = supa.auth.currentUser!.id;
      debugPrint('   Current user ID: $currentUserId');
      
      // Get other participant's info
      debugPrint('📊 Fetching participants...');
      final participants = await supa
          .from('participants')
          .select('user_id')
          .eq('conversation_id', conversationId)
          .neq('user_id', currentUserId);
      
      debugPrint('   Found ${participants.length} other participants');
      
      if (participants.isNotEmpty) {
        final otherUserId = participants[0]['user_id'] as String;
        debugPrint('   Other user ID: $otherUserId');
        
        // Get other user's profile
        debugPrint('👤 Fetching profile...');
        final profile = await supa
            .from('profiles')
            .select('name, surname')
            .eq('id', otherUserId)
            .maybeSingle();
        
        final title = profile != null
            ? '${profile['name'] ?? ''} ${profile['surname'] ?? ''}'.trim()
            : 'Chat';
        
        debugPrint('   Chat title: $title');
        debugPrint('🚀 Pushing ChatView to navigator...');
        
        // Check if widget is still mounted before navigating
        if (!mounted) {
          debugPrint('❌ Widget no longer mounted, skipping navigation');
          return;
        }
        
        // Navigate to chat
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatView(
              conversationId: conversationId,
              title: title,
            ),
          ),
        );
        
        debugPrint('✅ Navigation complete');
      } else {
        debugPrint('❌ No other participants found');
      }
      debugPrint('==========================================');
    } catch (e, stackTrace) {
      debugPrint('❌ Error navigating to chat: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('==========================================');
    }
  }

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

  // Initialize Firebase (skip if configuration files are missing)
  try {
    await Firebase.initializeApp();

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    debugPrint('⚠️ Firebase initialization skipped: $e');
    debugPrint(
        '📝 Add google-services.json (Android) or GoogleService-Info.plist (iOS) to enable push notifications');
  }

  await Hive.initFlutter();
  // Register adapters
  try {
    if (!Hive.isAdapterRegistered(40)) {
      Hive.registerAdapter(SocialUserAdapter());
    }
    if (!Hive.isAdapterRegistered(41)) {
      Hive.registerAdapter(PostAdapter());
    }
    if (!Hive.isAdapterRegistered(42)) {
      Hive.registerAdapter(CommentAdapter());
    }
    if (!Hive.isAdapterRegistered(43)) {
      Hive.registerAdapter(LikeAdapter());
    }
    if (!Hive.isAdapterRegistered(44)) {
      Hive.registerAdapter(CommentLikeAdapter());
    }
    if (!Hive.isAdapterRegistered(45)) {
      Hive.registerAdapter(FriendshipAdapter());
    }
    if (!Hive.isAdapterRegistered(46)) {
      Hive.registerAdapter(FriendshipStatusAdapter());
    }
  } catch (e) {
    debugPrint('⚠️ Hive adapter registration error: $e');
  }
  
  // Note: Hive boxes are no longer used since migration to SupabaseSocialRepository
  // Social data is now stored in Supabase PostgreSQL database

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Initialize app lifecycle service
  AppLifecycleService().initialize();
  debugPrint('✅ App lifecycle service initialized');

  // Initialize notification service after Supabase (only if Firebase is initialized)
  try {
    await NotificationService().initialize();
    debugPrint('✅ Notification service initialized');
  } catch (e) {
    debugPrint('⚠️ Notification service initialization skipped: $e');
  }

  // Global navigatorKey (used by password recovery and notifications)
  final navigatorKey = GlobalKey<NavigatorState>();
  
  // Set navigator key for notification service
  NotificationService().setNavigatorKey(navigatorKey);

  // Listen to auth state changes for password recovery and FCM token handling
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.passwordRecovery) {
      navigatorKey.currentState?.pushNamed('/reset-password');
    }

    // Save FCM token when user signs in
    if (data.event == AuthChangeEvent.signedIn && data.session?.user != null) {
      NotificationService().saveFCMTokenForCurrentUser().then((_) {
        debugPrint('✅ FCM token saved for logged-in user');
      }).catchError((e) {
        debugPrint('⚠️ Error saving FCM token: $e');
      });
    }

    // Clean up notification token on sign out
    if (data.event == AuthChangeEvent.signedOut) {
      NotificationService().deleteTokenFromSupabase().then((_) {
        debugPrint('✅ FCM token cleared on sign out');
      }).catchError((e) {
        debugPrint('⚠️ Error clearing FCM token: $e');
      });
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
          navigatorKey: navigatorKey,
          title: 'Hocam Connect',
          debugShowCheckedModeBanner: false,
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          themeMode: c.mode,
          // Splash screen with initial connectivity check
          home: SplashView(
            funnyMessages: const [
              'Polishing the antenna…',
              'Waving at the router 👋',
              'Asking packets to hurry up…',
              'Consulting the fiber oracle…',
            ],
            child: const ConnectivityGate(
              child: AuthGate(),
            ),
          ),
          routes: {
            '/login': (_) => const LoginView(),
            '/welcome': (_) => const WelcomeView(),
            '/register': (_) => const RegistrationView(),
            '/cafeteria-menu': (_) => const CafeteriaMenuView(),
            '/gpa_calculator': (_) => const GpaCalculatorView(),
            '/forgot-password': (_) => const ForgotPasswordView(),
            '/twoc': (_) => const ThisWeekView(),
            '/webmail': (_) => const WebmailView(),
            '/chat': (ctx) {
              final args = ModalRoute.of(ctx)?.settings.arguments
                  as Map<String, dynamic>?;
              final conversationId = args?['conversationId'] as String?;
              final title = args?['title'] as String?;
              if (conversationId == null) {
                return const Scaffold(
                    body: Center(child: Text('Chat not found')));
              }
              return ChatView(
                conversationId: conversationId,
                title: title ?? 'Chat',
              );
            },
            '/home': (ctx) {
              final args = ModalRoute.of(ctx)?.settings.arguments
                  as Map<String, dynamic>?;
              final initialIndex = (args != null && args['initialIndex'] is int)
                  ? args['initialIndex'] as int
                  : 0;
              return MainTabView(initialIndex: initialIndex);
            },
            '/recovery-code': (_) => const RecoveryCodeView(),
            '/reset-password': (_) => const ResetPasswordView(),
            '/hitchike': (_) => const HitchikeView(),
            '/hitchike/create': (_) => const CreateHitchikeView(),
            '/social': (_) => const SocialView(),
            '/user-profile': (ctx) {
              final args = ModalRoute.of(ctx)?.settings.arguments
                  as Map<String, dynamic>?;
              final userId = args?['userId'] as String?;
              final repo = args?['repo'] as SocialRepository?;
              if (userId == null) {
                return const Scaffold(
                    body: Center(child: Text('Kullanıcı bulunamadı')));
              }
              final fallback = repo ?? SupabaseSocialRepository();
              return UserProfileView(userId: userId, repository: fallback);
            },
            '/notification-debug': (_) => const NotificationDebugView(),
          },
        );
      },
    );
  }
}
