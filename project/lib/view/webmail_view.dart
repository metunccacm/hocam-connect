import 'package:flutter/material.dart';
import 'package:project/widgets/custom_appbar.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:project/view/chat_list_view.dart';
import '../services/webmail_credentials_service.dart';

class WebmailView extends StatefulWidget {
  const WebmailView({super.key});

  @override
  State<WebmailView> createState() => _WebmailViewState();
}

class _WebmailViewState extends State<WebmailView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasConnection = true;
  final _credentialsService = WebmailCredentialsService();
  bool _hasAttemptedAutoLogin = false;
  bool _showRememberDialog = false;
  final _usernameController = TextEditingController();
  
  // Constants for credential validation
  static const int _minUsernameLength = 3;
  static const int _minPasswordLength = 3;
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..enableZoom(true);
    
    // Add JavaScript channel FIRST, before any navigation
    _controller.addJavaScriptChannel(
      'SaveCredentials',
      onMessageReceived: (JavaScriptMessage message) {
        debugPrint('📧 Received credentials via JS channel');
        try {
          // Parse JSON message safely
          final decoded = message.message;
          // Simple JSON parsing for {"username":"...","password":"..."}
          final usernameMatch = RegExp(r'"username"\s*:\s*"([^"]*)"').firstMatch(decoded);
          final passwordMatch = RegExp(r'"password"\s*:\s*"([^"]*)"').firstMatch(decoded);
          
          if (usernameMatch != null && passwordMatch != null) {
            final username = usernameMatch.group(1) ?? '';
            final password = passwordMatch.group(1) ?? '';
            
            if (username.isNotEmpty && password.isNotEmpty) {
              debugPrint('✅ Valid credentials received');
              _usernameController.text = username;
              _passwordController.text = password;
              _showRememberCredentialsDialog();
            } else {
              debugPrint('❌ Empty credentials');
            }
          } else {
            debugPrint('❌ Invalid JSON format');
          }
        } catch (e) {
          debugPrint('❌ Error parsing credentials: $e');
        }
      },
    );
    
    // Set navigation delegate AFTER channel is added
    _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          setState(() {
            _isLoading = true;
          });
        },
        onPageFinished: (url) async {
          setState(() {
            _isLoading = false;
          });
          
          debugPrint('📄 Page finished loading: $url');
          
          if (url.contains('webmail.metu.edu.tr')) {
            // Check if we're on the login page
            final isLoginPage = await _isOnLoginPage();
            debugPrint('📄 Is login page: $isLoginPage');
            
            if (isLoginPage) {
              // Always setup login detection when on login page
              await _setupLoginDetection();
              
              // Auto-login if we have saved credentials and haven't tried yet
              if (!_hasAttemptedAutoLogin) {
                _hasAttemptedAutoLogin = true;
                await _attemptAutoLogin();
              }
            }
          }
        },
        onWebResourceError: (error) {
          setState(() {
            _isLoading = false;
            _hasConnection = false;
          });
        },
        onNavigationRequest: (NavigationRequest request) {
          // Allow all navigation within the webmail domain
          return NavigationDecision.navigate;
        },
      ),
    );

    _checkConnectionAndLoad();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectionAndLoad() async {
    final result = await Connectivity().checkConnectivity();
    if (result.contains(ConnectivityResult.none)) {
      setState(() {
        _hasConnection = false;
      });
    } else {
      setState(() {
        _hasConnection = true;
      });
      // Load METU webmail
      _controller.loadRequest(
        Uri.parse('https://webmail.metu.edu.tr/'),
      );
    }
  }

  /// Check if we're on the login page
  Future<bool> _isOnLoginPage() async {
    try {
      final result = await _controller.runJavaScriptReturningResult(
        '''
        (function() {
          var usernameField = document.querySelector('input[name="user"], input[type="text"]');
          var passwordField = document.querySelector('input[name="pass"], input[type="password"]');
          return usernameField !== null && passwordField !== null;
        })();
        '''
      );
      return result.toString() == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Attempt auto-login with saved credentials
  Future<void> _attemptAutoLogin() async {
    try {
      final credentials = await _credentialsService.getCredentials();
      if (credentials == null) {
        debugPrint('📧 No saved webmail credentials');
        return;
      }

      debugPrint('📧 Attempting webmail auto-login...');
      
      // Wait a bit for page to fully load
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Safely escape credentials for JavaScript injection
      final username = _escapeJavaScriptString(credentials['username'] ?? '');
      final password = _escapeJavaScriptString(credentials['password'] ?? '');
      
      // Fill and submit login form with properly escaped credentials
      await _controller.runJavaScript('''
        (function() {
          var usernameField = document.querySelector('input[name="user"], input[type="text"]');
          var passwordField = document.querySelector('input[name="pass"], input[type="password"]');
          var loginForm = document.querySelector('form');
          
          if (usernameField && passwordField && loginForm) {
            usernameField.value = "$username";
            passwordField.value = "$password";
            loginForm.submit();
            return true;
          }
          return false;
        })();
      ''');
      
      debugPrint('✅ Auto-login attempted');
    } catch (e) {
      debugPrint('❌ Error during auto-login: $e');
    }
  }
  
  /// Escape a string for safe injection into JavaScript
  String _escapeJavaScriptString(String input) {
    return input
        .replaceAll('\\', '\\\\')  // Escape backslashes first
        .replaceAll('"', '\\"')     // Escape double quotes
        .replaceAll("'", "\\'")     // Escape single quotes
        .replaceAll('\n', '\\n')    // Escape newlines
        .replaceAll('\r', '\\r')    // Escape carriage returns
        .replaceAll('\t', '\\t');   // Escape tabs
  }

  /// Setup login form detection to capture credentials
  Future<void> _setupLoginDetection() async {
    try {
      debugPrint('📧 Setting up login detection...');
      
      // Wait a bit for the page to fully render
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Use a more aggressive approach: poll the fields periodically
      await _controller.runJavaScript('''
        (function() {
          console.log('🔍 Setting up aggressive login capture...');
          
          var credentialsSent = false;
          var lastUsername = '';
          var lastPassword = '';
          
          // Function to capture and send credentials
          function captureCredentials() {
            if (credentialsSent) {
              console.log('⏭️ Credentials already sent, skipping');
              return false;
            }
            
            // Try multiple selectors
            var username = document.querySelector('input[name="user"]') || 
                          document.querySelector('input[id="user"]') ||
                          document.querySelector('input[name="username"]') ||
                          document.querySelector('input[id="username"]') ||
                          document.querySelector('input[type="text"]');
                          
            var password = document.querySelector('input[name="pass"]') ||
                          document.querySelector('input[id="pass"]') ||
                          document.querySelector('input[name="password"]') ||
                          document.querySelector('input[id="password"]') ||
                          document.querySelector('input[type="password"]');
            
            console.log('🔍 Checking credentials - username:', !!username, 'password:', !!password);
            
            if (username && password) {
              var usernameVal = username.value.trim();
              var passwordVal = password.value.trim();
              
              console.log('📊 Values - username length:', usernameVal.length, 'password length:', passwordVal.length);
              
              // Both fields must be filled and have reasonable lengths
              if (usernameVal.length >= $_minUsernameLength && passwordVal.length >= $_minPasswordLength) {
                console.log('✅ Valid credentials detected, sending to Flutter...');
                
                try {
                  if (typeof SaveCredentials !== 'undefined') {
                    SaveCredentials.postMessage(JSON.stringify({ username: usernameVal, password: passwordVal }));
                    console.log('✅ Credentials sent successfully!');
                    credentialsSent = true;
                    return true;
                  } else {
                    console.log('❌ SaveCredentials channel not found!');
                  }
                } catch (err) {
                  console.log('❌ Error sending credentials:', err);
                }
              } else {
                console.log('⚠️ Credentials too short, not sending');
              }
            }
            return false;
          }
          
          // Try to find and attach to button/form
          // Look for login button with various selectors
          var loginButton = document.querySelector('input[type="submit"]') ||
                           document.querySelector('button[type="submit"]') ||
                           document.querySelector('button[name="submit"]') ||
                           document.querySelector('input[name="submit"]') ||
                           document.querySelector('input[value*="Login"]') ||
                           document.querySelector('input[value*="login"]') ||
                           document.querySelector('button');
          
          var forms = document.querySelectorAll('form');
          
          console.log('Found ' + forms.length + ' forms');
          console.log('Found login button:', !!loginButton);
          
          if (loginButton) {
            console.log('🔘 Attaching to login button');
            // Attach to click event on the button (capture phase to ensure we catch it)
            loginButton.addEventListener('click', function(e) {
              console.log('🖱️ Login button clicked!');
              // Small delay to ensure form values are set
              setTimeout(captureCredentials, 100);
            }, true);
          }
          
          // Attach to form submit events (most reliable)
          forms.forEach(function(form, index) {
            console.log('📝 Attaching to form ' + index);
            form.addEventListener('submit', function(e) {
              console.log('📝 Form submitted!');
              // Capture immediately on submit
              captureCredentials();
            }, true);
          });
          
          // DON'T poll automatically - only capture on button click/form submit
          // This prevents showing the save dialog while user is still typing
          console.log('✅ Login detection setup complete - waiting for button click or form submit');
        })();
      ''');
      
      debugPrint('✅ Login detection setup complete');
    } catch (e) {
      debugPrint('❌ Error setting up login detection: $e');
    }
  }

  /// Show dialog to ask user if they want to save credentials
  void _showRememberCredentialsDialog() {
    if (!mounted || _showRememberDialog) return;
    
    setState(() {
      _showRememberDialog = true;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Login?'),
        content: const Text(
          'Would you like to save your webmail credentials for automatic login next time?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _showRememberDialog = false;
              });
              Navigator.of(context).pop();
            },
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Capture the navigator and messenger before async gap
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              
              await _credentialsService.saveCredentials(
                username: _usernameController.text,
                password: _passwordController.text,
              );
              setState(() {
                _showRememberDialog = false;
              });
              if (mounted) {
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('✅ Credentials saved securely'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Yes, Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'METU Webmail',
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'clear_credentials') {
              await _clearCredentials();
            } else if (value == 'refresh') {
              // Reload and redirect to main login page
              await _controller.loadRequest(Uri.parse('https://webmail.metu.edu.tr/'));
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh),
                  SizedBox(width: 8),
                  Text('Refresh'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'clear_credentials',
              child: FutureBuilder<bool>(
                future: _credentialsService.hasCredentials(),
                builder: (context, snapshot) {
                  final hasCredentials = snapshot.data ?? false;
                  return Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: hasCredentials ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Clear Saved Login',
                        style: TextStyle(
                          color: hasCredentials ? null : Colors.grey,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: 'Chats',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatListView()),
            );
          },
        ),
      ],
      body: !_hasConnection
          ? _buildErrorView()
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            "No internet connection.\nPlease check your network.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _checkConnectionAndLoad,
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  /// Clear saved credentials and redirect to login page
  Future<void> _clearCredentials() async {
    final hasCredentials = await _credentialsService.hasCredentials();
    if (!hasCredentials) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No saved credentials to clear'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Saved Login?'),
        content: const Text(
          'This will remove your saved webmail credentials. You will need to log in manually next time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // Close the dialog first
              Navigator.of(context).pop();
              
              await _credentialsService.clearCredentials();
              
              // Reset auto-login flag so it won't try to auto-login again
              _hasAttemptedAutoLogin = false;
              
              // Redirect to main webmail login page
              await _controller.loadRequest(Uri.parse('https://webmail.metu.edu.tr/'));
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Saved credentials cleared'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
