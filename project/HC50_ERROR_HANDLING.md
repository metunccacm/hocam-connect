# HC-50 Network Error Handling System

## Overview
The HC-50 error handling system provides centralized network error detection and user-friendly error messages throughout the Hocam Connect app.

## Error Code
**HC-50**: Network Connectivity Error - Indicates that the app cannot reach the server due to network issues.

## Components

### 1. `NetworkErrorHandler` (lib/utils/network_error_handler.dart)

#### HC50Exception
Custom exception class for network-related errors:
```dart
throw HC50Exception(
  message: 'No internet connection available',
  details: 'Please check your network settings',
);
```

#### Methods

**`handleNetworkCall<T>()`** - Wrap any network call with automatic error handling:
```dart
Future<List<Product>> fetchProducts() async {
  return NetworkErrorHandler.handleNetworkCall(
    () async {
      final rows = await supabase.from('products').select();
      return rows.map((e) => Product.fromJson(e)).toList();
    },
    context: 'Failed to load products',
  );
}
```

**`isNetworkError(error)`** - Check if an error is network-related:
```dart
try {
  await fetchData();
} catch (e) {
  if (NetworkErrorHandler.isNetworkError(e)) {
    // Handle as HC-50 error
  }
}
```

**`hasInternetConnection()`** - Check current connectivity status:
```dart
final hasInternet = await NetworkErrorHandler.hasInternetConnection();
if (!hasInternet) {
  // Show offline message
}
```

**`showErrorDialog()`** - Display HC-50 error dialog:
```dart
NetworkErrorHandler.showErrorDialog(
  context,
  title: 'Connection Error',
  message: 'Unable to load data',
  onRetry: () => fetchData(),
);
```

**`showErrorSnackBar()`** - Show HC-50 error snackbar:
```dart
NetworkErrorHandler.showErrorSnackBar(
  context,
  message: 'Unable to connect to server',
  onRetry: () => fetchData(),
);
```

### 2. `NetworkErrorView` Widget
Display HC-50 errors in your UI:

```dart
// Full page error
NetworkErrorView(
  message: 'Unable to load marketplace products',
  onRetry: () => viewModel.refresh(),
)

// Compact error (for smaller areas)
NetworkErrorView(
  message: 'Connection failed',
  onRetry: () => reload(),
  compact: true,
)
```

## Implementation Guide

### Step 1: Update Service Layer
Wrap all network calls with `handleNetworkCall()`:

```dart
// Before
Future<List<Product>> fetchProducts() async {
  final rows = await supa.from('products').select();
  return rows.map((e) => Product.fromJson(e)).toList();
}

// After
Future<List<Product>> fetchProducts() async {
  return NetworkErrorHandler.handleNetworkCall(
    () async {
      final rows = await supa.from('products').select();
      return rows.map((e) => Product.fromJson(e)).toList();
    },
    context: 'Failed to load products',
  );
}
```

### Step 2: Update ViewModel
Add error state management:

```dart
class MyViewModel extends ChangeNotifier {
  bool _loading = false;
  String? _errorMessage;
  bool _hasNetworkError = false;
  
  bool get isLoading => _loading;
  String? get errorMessage => _errorMessage;
  bool get hasNetworkError => _hasNetworkError;
  
  Future<void> loadData() async {
    _loading = true;
    _errorMessage = null;
    _hasNetworkError = false;
    notifyListeners();
    
    try {
      final data = await service.fetchData();
      // Process data
    } on HC50Exception catch (e) {
      _errorMessage = e.message;
      _hasNetworkError = true;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
```

### Step 3: Update View
Handle errors in UI:

```dart
@override
Widget build(BuildContext context) {
  return Consumer<MyViewModel>(
    builder: (context, viewModel, child) {
      if (viewModel.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      
      if (viewModel.hasNetworkError) {
        return NetworkErrorView(
          message: viewModel.errorMessage,
          onRetry: () => viewModel.loadData(),
        );
      }
      
      // Show data
      return YourDataWidget();
    },
  );
}
```

## Updated Services

The following services have been updated with HC-50 error handling:

### MarketplaceService ✅
- `fetchProducts()` - Loads marketplace products
- `fetchProductById()` - Loads single product
- `fetchCategories()` - Loads categories

### HitchikeService ✅ (create_hitchike_post_service.dart)
- `createHitchikePost()` - Creates new hitchhike post
- `fetchActivePosts()` - Loads active hitchhike posts

### CafeteriaMenuViewModel ✅
- `loadWeek()` - Loads weekly cafeteria menu

### GpaViewModel ✅
- `loadLatestForCurrentUser()` - Loads user's GPA data
- `saveSnapshot()` - Saves GPA data

## UI Examples

### Dialog Error
```dart
try {
  await service.deleteProduct(id);
} on HC50Exception {
  NetworkErrorHandler.showErrorDialog(
    context,
    title: 'Delete Failed',
    message: 'Unable to delete product due to connection error',
    onRetry: () => deleteProduct(id),
  );
}
```

### SnackBar Error
```dart
try {
  await service.updateProfile();
} on HC50Exception {
  NetworkErrorHandler.showErrorSnackBar(
    context,
    message: 'Profile update failed',
    onRetry: () => updateProfile(),
  );
}
```

### In-Page Error
```dart
if (viewModel.hasNetworkError) {
  return NetworkErrorView(
    message: 'Unable to load data',
    onRetry: () => viewModel.refresh(),
  );
}
```

## Features to Add HC-50 Handling

The following features should implement HC-50 error handling:

1. **GPA Calculator** - ✅ COMPLETED
2. **Social Media** - Loading posts, comments, likes
3. **Hitchhike** - ✅ COMPLETED
4. **Cafeteria Menu** - ✅ COMPLETED
5. **TWOC (This Week on Campus)** - Loading events
6. **Marketplace** - ✅ COMPLETED
7. **Chat** - Sending/receiving messages
8. **Profile** - Loading user data

## Best Practices

1. **Always wrap network calls**: Use `handleNetworkCall()` for all Supabase queries
2. **Provide context**: Include meaningful context messages for better debugging
3. **Show retry options**: Always provide a way for users to retry failed operations
4. **Use appropriate UI**: Choose between dialog, snackbar, or in-page error based on context
5. **Handle gracefully**: Don't crash the app on network errors

## Testing

To test HC-50 error handling:

1. **Turn off WiFi/Mobile Data** before using features
2. **Verify** that HC-50 error appears instead of generic crash
3. **Test Retry** button functionality
4. **Check** that app recovers when connection is restored

## Example Complete Implementation

See `lib/view/marketplace_example_view.dart` for a complete working example.
