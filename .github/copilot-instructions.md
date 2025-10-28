# Hocam Connect AI Coding Agent Instructions

## Project Overview
Flutter mobile app (METU NCC "Super App") serving METU NCC students with dining menus, GPA calculators, marketplace, hitchhiking coordination, social features, and messaging. Backend is Supabase (PostgreSQL + Storage + Auth + Realtime).

## Critical Architecture Patterns

### State Management: Provider + ViewModel
- **Pattern**: Each feature has a `ViewModel` extending `ChangeNotifier`, provided via `ChangeNotifierProvider` in `main.dart` or view-level.
- **Example**: `LoginViewModel`, `MarketplaceViewModel`, `SocialViewModel` manage UI state and business logic.
- **Singleton Exception**: `ThemeController.instance` is a singleton shared across the app for theme persistence.
- **Usage**: Access via `Provider.of<T>(context)` or `context.watch<T>()`. Views are stateless/stateful widgets consuming ViewModels.

### Service Layer Architecture
- **Services** (`lib/services/`): Handle backend communication and business logic.
  - `AuthService`: Supabase auth operations (sign in/up/out, metadata updates).
  - `ChatService`: E2EE messaging with CEK wrapping/unwrapping via `E2EEKeyManager`.
  - `MarketplaceService`: Product CRUD with Supabase storage for images.
  - `SocialRepository`: Local-first social features using Hive (posts, comments, likes, friendships).
- **Global Supabase Client**: Access via `Supabase.instance.client` or local `final supa = Supabase.instance.client;`.
- **Supabase Init**: `main.dart` initializes Supabase with hardcoded URL/key before `runApp()`.

### E2EE Messaging Implementation
- **Key Management**: `E2EEKeyManager` (`lib/e2ee/`) handles X25519 long-term keys (stored in `flutter_secure_storage`), ephemeral keys, and CEK (Conversation Encryption Key) wrapping using ECDH + AES-GCM.
- **Message Encryption**: `ChatService` encrypts message bodies with CEK, stores ciphertext/nonce/MAC in Supabase `chat_messages` table.
- **CEK Bootstrap**: `bootstrapCekIfMissing()` generates new CEK if missing, wraps for all participants, increments version in DB.
- **Critical**: Never log decrypted keys/messages. Always use base64 encoding for wire format.

### Local Storage Strategy
- **Hive**: Used for offline-first social features (`Post`, `Comment`, `Like`, `SocialUser`, `Friendship`). Custom TypeAdapters with typeIds 40-46.
- **Box Names**: `social_users`, `social_posts`, `social_comments`, `social_likes`, `social_comment_likes`, `social_friendships`.
- **Init**: `main.dart` registers adapters and opens boxes before `runApp()`. Check `Hive.isAdapterRegistered()` to avoid re-registration errors.
- **Secure Storage**: `flutter_secure_storage` for E2EE private keys only.
- **SharedPreferences**: Theme mode persistence (`ThemeController`).

### View Routing & Navigation
- **Routes**: Defined in `MyApp` (`main.dart`) via `routes` map: `/welcome`, `/login`, `/register`, `/marketplace`, `/gpa`, `/cafeteria`, `/hitchike`, `/create-hitchike`, `/reset-password`, etc.
- **AuthGate**: Entry point widget. If `Supabase.instance.client.auth.currentSession != null`, shows `MainTabView`, else `WelcomeView`. Listens to `onAuthStateChange` for real-time auth updates.
- **MainTabView**: Bottom navigation bar (`bottombar_view.dart`) with 4 tabs: `HomeView`, `MarketplaceView`, `ChatListView`, `ThisWeekView`. Floating menu button with overlay for settings/profile/hitchhike.

### Responsive Scaling
- **SizeConfig** (`lib/config/size_config.dart`): Proportional scaling based on reference dimensions (414x896).
- **Usage**: `getProportionateScreenWidth(inputWidth)` and `getProportionateScreenHeight(inputHeight)` for all hardcoded sizes.
- **Init**: Call `SizeConfig().init(context)` in build methods before using scaling functions.

### Model Conventions
- **Supabase Models**: Parse from JSON via `fromRow()` or `fromJson()` (e.g., `Product.fromRow()`). Use Supabase's generated types when possible.
- **Hive Models**: Annotated with `@HiveType(typeId: X)` and `@HiveField(Y)`. Manual TypeAdapters handle serialization. Extend `HiveObject` for automatic save.
- **Social Models**: `Post`, `Comment`, `Like` track relationships via IDs (`postId`, `authorId`, `parentCommentId`). `SocialViewModel` caches counts and states in-memory for UI performance.

## Development Workflows

### Running the App
```bash
cd project
flutter pub get                # Install dependencies
flutter run                    # Run on connected device/simulator
flutter run -d macos          # Target macOS (if supported)
flutter run --release         # Production build
```

### Code Quality
```bash
flutter analyze                # Static analysis (uses analysis_options.yaml)
dart format lib/ --set-exit-if-changed  # Format check
dart fix --apply               # Auto-fix lints
```

### Build for Production
```bash
flutter build apk --release    # Android APK
flutter build ios --release    # iOS (requires Xcode/macOS)
flutter build web              # Web build (limited support)
```

### Supabase Schema Changes
- Migrations are managed server-side. Update local models to match schema.
- Storage buckets: `marketplace-images`, `profile-avatars`, `chat-media` (check Supabase dashboard for policies).

## CI/CD Workflows

### GitHub Actions
Two workflows are configured in `.github/workflows/`:

1. **Flutter CI** (`flutter.yml`) - Runs on push/PR to master/main/develop:
   - Analyzes code with `flutter analyze`
   - Builds Android APK (release)
   - Uploads APK as artifact (30-day retention)

2. **iOS Build** (`ios-build.yml`) - Runs on push/PR to master:
   - Builds unsigned iOS app (`--no-codesign`)
   - Uploads iOS build artifacts (30-day retention)

Both use Flutter 3.24.0 stable. The project has no test files, so workflows skip testing.

## Common Pitfalls

1. **Provider Context Issues**: Don't use `context` from parent widget tree in async callbacks. Pass `context` explicitly or use `BuildContext` from builder.
2. **Hive Adapter Conflicts**: Always check `Hive.isAdapterRegistered(typeId)` before calling `registerAdapter()` to avoid crashes.
3. **Supabase Auth State**: Auth stream (`onAuthStateChange`) emits multiple events. Handle `AuthChangeEvent.signedIn/signedOut/passwordRecovery` explicitly.
4. **E2EE Key Timing**: Call `ChatService.ensureMyLongTermKey()` before any chat operations to avoid key-not-found errors.
5. **Image Paths**: Marketplace uses Supabase storage URLs. Social posts use local file paths (Hive strings). Don't mix formats.
6. **SizeConfig Init**: Must call `SizeConfig().init(context)` in each screen's build before using scaling functions.

## Key Files Reference
- **Entry Point**: `project/lib/main.dart` (Supabase init, Hive setup, MultiProvider config, route definitions)
- **Auth Flow**: `lib/services/auth_gate.dart` (session detection, auth stream)
- **E2EE Core**: `lib/e2ee/e2ee_key_manager.dart` (X25519, CEK wrapping, HKDF)
- **Social Logic**: `lib/viewmodel/social_viewmodel.dart` + `lib/services/social_repository.dart` (Hive-based social graph)
- **Theme**: `lib/theme_controller.dart` (singleton, persisted to SharedPreferences)
- **Scaling**: `lib/config/size_config.dart` (proportional dimensions for multi-device support)
- **Models**: `lib/models/social_models.dart`, `lib/models/product.dart`, `lib/models/hitchike_post.dart`

## Team Context
Student team project (ACM METU NCC). Contributions from 7 developers. Code may have inconsistencies (e.g., duplicate `lib/model/auth_service.dart` and `lib/services/auth_service.dart`). Prefer `lib/services/` versions for new work.
