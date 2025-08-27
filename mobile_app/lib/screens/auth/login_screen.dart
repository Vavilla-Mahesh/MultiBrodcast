import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;

  // Configure Google Sign In for YouTube OAuth
  // Note: In production, configure these scopes and client ID properly
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/youtube',
      'https://www.googleapis.com/auth/youtube.force-ssl',
    ],
  );

  @override
  void initState() {
    super.initState();
    // Check if already logged in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authServiceProvider.notifier).loadSavedAuth().then((_) {
        if (ref.read(authServiceProvider).step2Complete) {
          context.go('/home');
        }
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    ref.read(authServiceProvider.notifier).clearError();

    final success = await ref.read(authServiceProvider.notifier).loginStep1(
      _emailController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (success) {
      // Show step 2 dialog for Google OAuth
      _showGoogleOAuthDialog();
    } else {
      // Error handling is done through the state
      final error = ref.read(authServiceProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showGoogleOAuthDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Connect YouTube Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.video_call,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Step 2: Connect your YouTube account to enable live streaming features.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'You can connect any Google account with YouTube access, not necessarily the same email used for local login.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'This will redirect you to Google\'s authorization page.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(authServiceProvider.notifier).logout();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performGoogleOAuth();
            },
            child: const Text('Connect YouTube'),
          ),
        ],
      ),
    );
  }

  // Real Google OAuth implementation
  // This allows users to sign in with any Google account, independent of their local login email
  Future<void> _performGoogleOAuth() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Connecting to YouTube...'),
            SizedBox(height: 8),
            Text(
              'You can use any Google account, not necessarily the same as your local login.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    try {
      // Sign out first to ensure user can choose any account
      await _googleSignIn.signOut();
      
      // Perform Google OAuth - this will show account picker
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign-in was cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Get access token and other details
      final String? accessToken = googleAuth.accessToken;
      final String? refreshToken = googleAuth.refreshToken;
      
      if (accessToken == null) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get access token'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // For YouTube, we need to get the channel information
      // Using the user's display name and ID as channel info for demo
      // In production, you'd call YouTube API to get actual channel details
      final String channelId = 'UC_${googleUser.id}'; // Simulated channel ID
      final String channelTitle = googleUser.displayName ?? 'Unknown Channel';

      final success = await ref.read(authServiceProvider.notifier).exchangeGoogleTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiryDate: googleAuth.accessTokenExpirationDate?.millisecondsSinceEpoch,
        channelId: channelId,
        channelTitle: channelTitle,
        scopes: [
          'https://www.googleapis.com/auth/youtube',
          'https://www.googleapis.com/auth/youtube.force-ssl',
        ],
      );

      Navigator.of(context).pop(); // Close loading dialog

      if (success) {
        // Show success message with the Google account used
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully connected YouTube account: ${googleUser.email}'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/home');
      } else {
        final error = ref.read(authServiceProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Failed to connect YouTube account'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OAuth error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo and title
                    const Icon(
                      Icons.live_tv,
                      size: 80,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'MultiBroadcast',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Professional Live Streaming for YouTube',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Login form
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_passwordVisible,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _passwordVisible ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _passwordVisible = !_passwordVisible;
                                  });
                                },
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                      'Login (Step 1)',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Demo credentials info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Demo Credentials',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'admin@multibroadcast.com / admin123',
                      style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                    const Text(
                      'user@multibroadcast.com / user123',
                      style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Two-step authentication: Local config + YouTube OAuth',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}