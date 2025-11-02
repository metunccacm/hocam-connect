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
        print('📧 Received credentials via JS channel: ${message.message}');
        // Parse username and password from message
        final parts = message.message.split('|||');
        if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
          print('✅ Valid credentials received: ${parts[0]}');
          _usernameController.text = parts[0];
          _passwordController.text = parts[1];
          _showRememberCredentialsDialog();
        } else {
          print('❌ Invalid message format: ${message.message}');
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
          
          print('📄 Page finished loading: $url');
          
          if (url.contains('webmail.metu.edu.tr')) {
            // Check if we're on the login page
            final isLoginPage = await _isOnLoginPage();
            print('📄 Is login page: $isLoginPage');
            
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
    if (result == ConnectivityResult.none) {
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
        print('📧 No saved webmail credentials');
        return;
      }

      print('📧 Attempting webmail auto-login...');
      
      // Wait a bit for page to fully load
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Fill and submit login form
      await _controller.runJavaScript('''
        (function() {
          var usernameField = document.querySelector('input[name="user"], input[type="text"]');
          var passwordField = document.querySelector('input[name="pass"], input[type="password"]');
          var loginForm = document.querySelector('form');
          
          if (usernameField && passwordField && loginForm) {
            usernameField.value = "${credentials['username']}";
            passwordField.value = "${credentials['password']}";
            loginForm.submit();
            return true;
          }
          return false;
        })();
      ''');
      
      print('✅ Auto-login attempted');
    } catch (e) {
      print('❌ Error during auto-login: $e');
    }
  }

  /// Test credential capture by manually extracting form values
  Future<void> _testCredentialCapture() async {
    try {
      print('🧪 Testing credential capture...');
      
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          console.log('🧪 Manual test capture triggered');
          
          // Find all input fields
          var allInputs = document.querySelectorAll('input');
          var result = {
            inputs: allInputs.length,
            types: []
          };
          
          allInputs.forEach(function(input) {
            result.types.push(input.type + ':' + input.name + ':' + input.id);
          });
          
          // Try to find username and password
          var username = document.querySelector('input[name="user"]') || 
                        document.querySelector('input[id="user"]') ||
                        document.querySelector('input[type="text"]');
                        
          var password = document.querySelector('input[name="pass"]') ||
                        document.querySelector('input[id="pass"]') ||
                        document.querySelector('input[type="password"]');
          
          if (username && password && username.value && password.value) {
            console.log('✅ Found credentials, sending to Flutter...');
            if (typeof SaveCredentials !== 'undefined') {
              SaveCredentials.postMessage(username.value + '|||' + password.value);
              return 'success';
            } else {
              return 'channel_not_found';
            }
          } else {
            return 'fields_empty_or_not_found: username=' + (username ? 'found' : 'not_found') + ', password=' + (password ? 'found' : 'not_found');
          }
        })();
      ''');
      
      print('🧪 Test result: $result');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test result: $result'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Test error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test error: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Setup login form detection to capture credentials
  Future<void> _setupLoginDetection() async {
    try {
      print('📧 Setting up login detection...');
      
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
              return false;
            }
            
            // Try multiple selectors
            var username = document.querySelector('input[name="user"]') || 
                          document.querySelector('input[id="user"]') ||
                          document.querySelector('input[type="text"]') ||
                          document.querySelector('input[name="username"]') ||
                          document.querySelector('input[id="username"]');
                          
            var password = document.querySelector('input[name="pass"]') ||
                          document.querySelector('input[id="pass"]') ||
                          document.querySelector('input[type="password"]') ||
                          document.querySelector('input[name="password"]') ||
                          document.querySelector('input[id="password"]');
            
            if (username && password && username.value && password.value) {
              // Check if values have changed (to avoid sending same credentials multiple times)
              if (username.value !== lastUsername || password.value !== lastPassword) {
                console.log('✅ New credentials detected, sending to Flutter...');
                lastUsername = username.value;
                lastPassword = password.value;
                
                try {
                  if (typeof SaveCredentials !== 'undefined') {
                    SaveCredentials.postMessage(username.value + '|||' + password.value);
                    console.log('✅ Credentials sent successfully!');
                    credentialsSent = true;
                    return true;
                  } else {
                    console.log('❌ SaveCredentials channel not found!');
                  }
                } catch (err) {
                  console.log('❌ Error sending credentials:', err);
                }
              }
            }
            return false;
          }
          
          // Try to find and attach to button/form
          var loginButton = document.querySelector('input[type="submit"], button[type="submit"]');
          var forms = document.querySelectorAll('form');
          
          console.log('Found ' + forms.length + ' forms');
          console.log('Found login button:', loginButton);
          
          if (loginButton) {
            // Attach to all mouse events on the button
            ['mousedown', 'mouseup', 'click', 'touchstart'].forEach(function(eventType) {
              loginButton.addEventListener(eventType, function(e) {
                console.log('🖱️ Login button ' + eventType + '!');
                setTimeout(captureCredentials, 50);
              }, true);
            });
          }
          
          // Attach to forms
          forms.forEach(function(form) {
            ['submit', 'click'].forEach(function(eventType) {
              form.addEventListener(eventType, function(e) {
                console.log('📝 Form ' + eventType + '!');
                setTimeout(captureCredentials, 50);
              }, true);
            });
          });
          
          // Poll every 500ms to check if both fields are filled
          // This will catch the credentials shortly after the user fills them in
          var pollCount = 0;
          var maxPolls = 120; // Poll for 60 seconds max
          
          var pollInterval = setInterval(function() {
            pollCount++;
            
            if (credentialsSent || pollCount > maxPolls) {
              console.log('Stopping polling (sent=' + credentialsSent + ', count=' + pollCount + ')');
              clearInterval(pollInterval);
              return;
            }
            
            if (captureCredentials()) {
              clearInterval(pollInterval);
            }
          }, 500);
          
          console.log('✅ Login capture setup complete with polling');
        })();
      ''');
      
      print('✅ Login detection setup complete');
    } catch (e) {
      print('❌ Error setting up login detection: $e');
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
              await _credentialsService.saveCredentials(
                username: _usernameController.text,
                password: _passwordController.text,
              );
              setState(() {
                _showRememberDialog = false;
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Credentials saved securely'),
                  duration: Duration(seconds: 2),
                ),
              );
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
              _controller.reload();
            } else if (value == 'test_capture') {
              await _testCredentialCapture();
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
            const PopupMenuItem(
              value: 'test_capture',
              child: Row(
                children: [
                  Icon(Icons.bug_report, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Test Capture (Debug)'),
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

  /// Clear saved credentials
  Future<void> _clearCredentials() async {
    final hasCredentials = await _credentialsService.hasCredentials();
    if (!hasCredentials) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved credentials to clear'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

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
              await _credentialsService.clearCredentials();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Saved credentials cleared'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
