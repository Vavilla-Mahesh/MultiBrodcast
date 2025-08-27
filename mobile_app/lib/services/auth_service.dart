import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

class AuthService extends StateNotifier<AuthState> {
  AuthService() : super(AuthState());

  static const String baseUrl = 'http://localhost:3000/api';
  
  bool get isAuthenticated => state.token != null && state.user != null;

  Future<void> loadSavedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userJson = prefs.getString('user_data');
    
    if (token != null && userJson != null) {
      final user = User.fromJson(jsonDecode(userJson));
      state = state.copyWith(token: token, user: user);
    }
  }

  Future<bool> loginStep1(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['data']['token'];
        final userData = data['data']['user'];
        
        final user = User.fromJson(userData);
        state = state.copyWith(
          token: token,
          user: user,
          step1Complete: true,
        );
        
        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setString('user_data', jsonEncode(userData));
        
        return true;
      } else {
        final error = jsonDecode(response.body);
        state = state.copyWith(error: error['error']['message']);
        return false;
      }
    } catch (e) {
      state = state.copyWith(error: 'Network error: $e');
      return false;
    }
  }

  Future<bool> exchangeGoogleTokens({
    required String accessToken,
    String? refreshToken,
    int? expiryDate,
    required String channelId,
    required String channelTitle,
    List<String>? scopes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google/exchange-legacy'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'access_token': accessToken,
          'refresh_token': refreshToken,
          'expiry_date': expiryDate,
          'channel_id': channelId,
          'channel_title': channelTitle,
          'scopes': scopes ?? [],
          'user_id': state.user?.id,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final googleAccount = GoogleAccount.fromJson(data['data']['googleAccount']);
        
        state = state.copyWith(
          googleAccount: googleAccount,
          step2Complete: true,
        );
        
        // Save Google account data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('google_account', jsonEncode(googleAccount.toJson()));
        
        return true;
      } else {
        final error = jsonDecode(response.body);
        state = state.copyWith(error: error['error']['message']);
        return false;
      }
    } catch (e) {
      state = state.copyWith(error: 'Network error: $e');
      return false;
    }
  }

  String _generateCodeVerifier() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(128, (i) => chars[random.nextInt(chars.length)]).join();
  }

  String _generateCodeChallenge(String codeVerifier) {
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  Future<bool> startGoogleOAuth() async {
    try {
      // Generate PKCE parameters
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);
      
      // Save code verifier for later use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('oauth_code_verifier', codeVerifier);

      // Get OAuth URL from backend
      final response = await http.get(
        Uri.parse('$baseUrl/auth/google/auth'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final authUrl = data['data']['authUrl'] as String;
        
        // Replace the code_challenge in the URL with our own
        final uri = Uri.parse(authUrl);
        final newParams = Map<String, String>.from(uri.queryParameters);
        newParams['code_challenge'] = codeChallenge;
        
        final newUri = uri.replace(queryParameters: newParams);
        
        // Launch the OAuth URL
        if (await canLaunchUrl(newUri)) {
          return await launchUrl(
            newUri,
            mode: LaunchMode.externalApplication,
          );
        } else {
          state = state.copyWith(error: 'Could not launch OAuth URL');
          return false;
        }
      } else {
        final error = jsonDecode(response.body);
        state = state.copyWith(error: error['error']['message'] ?? 'Failed to get OAuth URL');
        return false;
      }
    } catch (e) {
      state = state.copyWith(error: 'OAuth error: $e');
      return false;
    }
  }

  Future<bool> exchangeAuthorizationCode(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final codeVerifier = prefs.getString('oauth_code_verifier');
      
      if (codeVerifier == null) {
        state = state.copyWith(error: 'OAuth code verifier not found');
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/google/exchange'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': code,
          'code_verifier': codeVerifier,
          'user_id': state.user?.id,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final googleAccount = GoogleAccount.fromJson(data['data']['googleAccount']);
        
        state = state.copyWith(
          googleAccount: googleAccount,
          step2Complete: true,
        );
        
        // Save Google account data and clean up OAuth state
        await prefs.setString('google_account', jsonEncode(googleAccount.toJson()));
        await prefs.remove('oauth_code_verifier');
        
        return true;
      } else {
        final error = jsonDecode(response.body);
        state = state.copyWith(error: error['error']['message'] ?? 'Failed to exchange code');
        return false;
      }
    } catch (e) {
      state = state.copyWith(error: 'Code exchange error: $e');
      return false;
    }
  }

  // Legacy method for demo purposes - now just redirects to real OAuth
  Future<bool> exchangeGoogleTokens({
    required String accessToken,
    String? refreshToken,
    int? expiryDate,
    required String channelId,
    required String channelTitle,
    List<String>? scopes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google/exchange'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'access_token': accessToken,
          'refresh_token': refreshToken,
          'expiry_date': expiryDate,
          'channel_id': channelId,
          'channel_title': channelTitle,
          'scopes': scopes ?? [],
          'user_id': state.user?.id,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final googleAccount = GoogleAccount.fromJson(data['data']['googleAccount']);
        
        state = state.copyWith(
          googleAccount: googleAccount,
          step2Complete: true,
        );
        
        // Save Google account data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('google_account', jsonEncode(googleAccount.toJson()));
        
        return true;
      } else {
        final error = jsonDecode(response.body);
        state = state.copyWith(error: error['error']['message']);
        return false;
      }
    } catch (e) {
      state = state.copyWith(error: 'Network error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    state = AuthState();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    await prefs.remove('google_account');
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

class AuthState {
  final String? token;
  final User? user;
  final GoogleAccount? googleAccount;
  final bool step1Complete;
  final bool step2Complete;
  final String? error;

  AuthState({
    this.token,
    this.user,
    this.googleAccount,
    this.step1Complete = false,
    this.step2Complete = false,
    this.error,
  });

  AuthState copyWith({
    String? token,
    User? user,
    GoogleAccount? googleAccount,
    bool? step1Complete,
    bool? step2Complete,
    String? error,
  }) {
    return AuthState(
      token: token ?? this.token,
      user: user ?? this.user,
      googleAccount: googleAccount ?? this.googleAccount,
      step1Complete: step1Complete ?? this.step1Complete,
      step2Complete: step2Complete ?? this.step2Complete,
      error: error,
    );
  }
}

class User {
  final int id;
  final String email;
  final String role;

  User({
    required this.id,
    required this.email,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
    };
  }
}

class GoogleAccount {
  final int id;
  final String channelId;
  final String channelTitle;
  final List<String> scopes;

  GoogleAccount({
    required this.id,
    required this.channelId,
    required this.channelTitle,
    required this.scopes,
  });

  factory GoogleAccount.fromJson(Map<String, dynamic> json) {
    return GoogleAccount(
      id: json['id'],
      channelId: json['channelId'],
      channelTitle: json['channelTitle'],
      scopes: List<String>.from(json['scopes']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'channelId': channelId,
      'channelTitle': channelTitle,
      'scopes': scopes,
    };
  }
}

final authServiceProvider = StateNotifierProvider<AuthService, AuthState>((ref) {
  return AuthService();
});