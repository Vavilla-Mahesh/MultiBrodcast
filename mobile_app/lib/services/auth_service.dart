import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';

class AuthService extends StateNotifier<AuthState> {
  AuthService() : super(AuthState());

  static const String baseUrl = 'http://localhost:3000/api';
  
  // Google Sign In instance for OAuth management
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/youtube',
      'https://www.googleapis.com/auth/youtube.force-ssl',
    ],
  );
  
  bool get isAuthenticated => state.token != null && state.user != null;

  Future<void> loadSavedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userJson = prefs.getString('user_data');
    final googleAccountJson = prefs.getString('google_account');
    
    if (token != null && userJson != null) {
      final user = User.fromJson(jsonDecode(userJson));
      GoogleAccount? googleAccount;
      
      if (googleAccountJson != null) {
        googleAccount = GoogleAccount.fromJson(jsonDecode(googleAccountJson));
      }
      
      state = state.copyWith(
        token: token, 
        user: user,
        googleAccount: googleAccount,
        step1Complete: true,
        step2Complete: googleAccount != null,
      );
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
    try {
      // Sign out from Google if signed in
      await _googleSignIn.signOut();
    } catch (e) {
      // Ignore Google sign out errors - user might not be signed in
    }
    
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