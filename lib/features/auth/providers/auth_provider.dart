import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lexguard_ai/models/user_model.dart';
import 'package:lexguard_ai/services/auth_service.dart';

enum AuthState { initial, authenticated, unauthenticated, loading, verifying }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  // Use getters to prevent synchronous crash on Provider instantiation if Firebase fails
  bool _googleInitialized = false;
  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;
  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;
  
  AuthState _authState = AuthState.initial;
  UserModel? _user;
  String? _errorMessage;
  bool _rememberMe = false;

  // Google Sign-In user data — populated after successful googleSignIn()
  String? _firebaseUid;
  String? _googleEmail;
  String? _googleDisplayName;
  String? _googlePhotoURL;

  AuthState get authState => _authState;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get rememberMe => _rememberMe;
  bool get isAuthenticated => _authState == AuthState.authenticated;

  /// Returns the four Google/Firebase user fields after a successful [googleSignIn].
  /// Returns null if the user has not signed in via Google.
  Map<String, String?> get googleUserData => {
        'email': _googleEmail,
        'displayName': _googleDisplayName,
        'photoURL': _googlePhotoURL,
        'firebaseUid': _firebaseUid,
      };

  /// Firebase UID of the currently signed-in user (Google auth only).
  String? get firebaseUid => _firebaseUid;

  void setRememberMe(bool value) {
    _rememberMe = value;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    print('[AuthProvider] login() called');
    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    bool isSuccess = false;
    try {
      print('[AuthProvider] Calling _authService.login');
      final result = await _authService.login(email, password);
      print('[AuthProvider] _authService.login result: $result');
      if (result['success']) {
        final data = result['data'];
        if (data == null || data['access_token'] == null) {
          print('[AuthProvider] Login failed: missing access_token in response');
          _errorMessage = 'Server error: missing login token. Please try again.';
          return false;
        }

        print('[AuthProvider] Login success, saving auth data');
        await _saveAuthData(data);
        _authState = AuthState.authenticated;
        notifyListeners();
        print('[AuthProvider] Auth state set to authenticated');
        isSuccess = true;
        return true;
      } else {
        print('[AuthProvider] Login failed: ${result['message']}');
        _errorMessage = result['message'] ?? 'Login failed. Please try again.';
        return false;
      }
    } catch (e) {
      print('[AuthProvider] Exception in login: $e');
      _errorMessage = e.toString();
      return false;
    } finally {
      if (!isSuccess) {
        _authState = AuthState.unauthenticated;
        notifyListeners();
        print('[AuthProvider] Auth state set to unauthenticated in finally');
      }
    }
  }

  Future<bool> signUp(String name, String email, String password) async {
    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();
    debugPrint('AuthProvider: Starting signup for $email');

    try {
      final result = await _authService.signUp(name, email, password);
      debugPrint('AuthProvider: Signup API result: ${result['success']}');
      
      if (result['success']) {
        // Backend now returns a message, not a token
        _authState = AuthState.unauthenticated;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'] ?? 'Signup failed. Please try again.';
        debugPrint('AuthProvider: Signup failed: $_errorMessage');
        _authState = AuthState.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (e, stack) {
      debugPrint('AuthProvider: Signup exception: $e');
      debugPrint('AuthProvider: Stack trace: $stack');
      _errorMessage = e.toString();
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendOtp(String email) async {
    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();
    debugPrint('AuthProvider: Requesting OTP for $email');

    try {
      final result = await _authService.sendOtp(email);
      debugPrint('AuthProvider: Send OTP result: ${result['success']}');
      
      if (result['success']) {
        _authState = AuthState.unauthenticated;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'] ?? 'Failed to send OTP.';
        _authState = AuthState.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (e, stack) {
      debugPrint('AuthProvider: Send OTP exception: $e');
      debugPrint('AuthProvider: Stack trace: $stack');
      _errorMessage = e.toString();
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String email, String otp) async {
    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.verifyOtp(email, otp);
      if (result['success']) {
        final data = result['data'];
        
        // If the response contains an access_token, it means registration was completed
        if (data['access_token'] != null) {
          await _saveAuthData(data);
          _authState = AuthState.authenticated;
        } else {
          // This might be for forgot password
          _authState = AuthState.verifying;
        }
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _authState = AuthState.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> googleSignIn() async {
    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Initialize once per provider lifetime
      if (!_googleInitialized) {
        await _googleSignIn.initialize();
        _googleInitialized = true;
        debugPrint('[AuthProvider] GoogleSignIn initialized');
      }

      debugPrint('[AuthProvider] Starting Google Sign-In...');
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      // In google_sign_in ^7.x with the instance API, authentication is synchronous
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      if (googleAuth.idToken == null) {
        debugPrint('[AuthProvider] Google idToken is null — OAuth client may not be configured.');
        _errorMessage = 'Google Sign-In is not fully configured. Please contact support.';
        _authState = AuthState.unauthenticated;
        notifyListeners();
        return false;
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      debugPrint('[AuthProvider] Signing into Firebase with Google credential...');
      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        _errorMessage = 'Firebase authentication returned no user.';
        _authState = AuthState.unauthenticated;
        notifyListeners();
        return false;
      }

      // ── Store the four required Google user fields ──────────────────────
      _firebaseUid      = firebaseUser.uid;
      _googleEmail      = firebaseUser.email;
      _googleDisplayName = firebaseUser.displayName;
      _googlePhotoURL   = firebaseUser.photoURL;

      debugPrint('[AuthProvider] Firebase Auth Success');
      debugPrint('  email       : $_googleEmail');
      debugPrint('  displayName : $_googleDisplayName');
      debugPrint('  photoURL    : $_googlePhotoURL');
      debugPrint('  firebaseUid : $_firebaseUid');

      final String? firebaseIdToken = await firebaseUser.getIdToken();

      final result = await _authService.googleAuth(
        firebaseUser.email!,
        firebaseUser.displayName ?? 'Google User',
        firebaseUser.photoURL,
        firebaseUid: firebaseUser.uid,   // ← primary key sent to backend
        idToken: firebaseIdToken ?? googleAuth.idToken!,
      );

      if (result['success']) {
        final data = result['data'];
        await _saveAuthData(
          data,
          email: firebaseUser.email,
          name: firebaseUser.displayName,
          photo: firebaseUser.photoURL,
        );
        _authState = AuthState.authenticated;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'] ?? 'Backend rejected the Google Sign-In.';
      }

      _authState = AuthState.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('[AuthProvider] Google Sign-In Error: $e');
      _errorMessage = _friendlyGoogleError(e);
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Converts raw Google Sign-In exceptions into user-friendly messages.
  String _friendlyGoogleError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('ApiException: 10') || msg.contains('DEVELOPER_ERROR')) {
      return 'Google Sign-In is not configured (missing OAuth client). Contact support.';
    }
    if (msg.contains('network_error') || msg.contains('7:')) {
      return 'Network error. Please check your internet connection.';
    }
    if (msg.contains('sign_in_cancelled') ||
        msg.contains('12501') ||
        msg.contains('User cancelled')) {
      return 'Sign-In was cancelled.';
    }
    if (msg.contains('sign_in_failed') || msg.contains('12500')) {
      return 'Google Sign-In failed. Please try again.';
    }
    return 'Google Sign-In failed. Please try again.';
  }

  Future<void> _saveAuthData(Map<String, dynamic> data, {String? email, String? name, String? photo}) async {
    final accessToken = data['access_token'];
    final refreshToken = data['refresh_token'];
    
    const storage = FlutterSecureStorage();
    if (accessToken != null) {
      await storage.write(key: 'auth_token', value: accessToken);
      debugPrint('[AuthProvider] Saved auth token successfully');
    }
    if (refreshToken != null) {
      await storage.write(key: 'refresh_token', value: refreshToken);
      debugPrint('[AuthProvider] Saved refresh token successfully');
    }
    
    if (data['user'] != null) {
      _user = UserModel.fromJson(data['user']);
    } else {
      // Fallback if backend doesn't return user object
      _user = UserModel(
        id: data['user_id']?.toString() ?? '',
        name: name ?? 'User',
        email: email ?? 'user@example.com',
        role: 'Legal Professional',
        avatarUrl: photo,
        createdAt: DateTime.now(),
      );
    }
  }

  Future<bool> sendResetOtp(String email) async {
    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _authService.sendResetOtp(email);
      if (result['success']) {
        _authState = AuthState.unauthenticated;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _authState = AuthState.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyResetOtp(String email, String otp) async {
    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _authService.verifyResetOtp(email, otp);
      if (result['success']) {
        _authState = AuthState.verifying;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _authState = AuthState.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    return sendResetOtp(email);
  }

  Future<bool> resetPassword(String email, String otp, String newPassword) async {
    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _authService.resetPassword(email, otp, newPassword);
      if (result['success']) {
        _authState = AuthState.unauthenticated;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _authState = AuthState.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({String? name, String? phone}) async {
    if (_user == null) return false;
    
    _authState = AuthState.loading;
    notifyListeners();
    
    try {
      final data = {
        if (name != null) 'full_name': name,
        if (phone != null) 'phone': phone,
      };
      
      final result = await _authService.updateProfile(data);
      if (result['success']) {
        // Update local user object
        _user = _user!.copyWith(
          name: name ?? _user!.name,
        );
        _authState = AuthState.authenticated;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _authState = AuthState.authenticated;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to update profile.';
      _authState = AuthState.authenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    _authState = AuthState.loading;
    notifyListeners();
    
    try {
      final result = await _authService.changePassword(currentPassword, newPassword);
      _authState = AuthState.authenticated;
      notifyListeners();
      
      if (result['success']) {
        return true;
      } else {
        _errorMessage = result['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _authState = AuthState.authenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    _authState = AuthState.loading;
    notifyListeners();
    // Assuming backend will support this soon, but for now we'll just sign out
    try {
      await Future.delayed(const Duration(seconds: 1));
      logout();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete account.';
      _authState = AuthState.authenticated;
      notifyListeners();
      return false;
    }
  }

  /// Re-fetches /user/me and updates the local [user] with live statistics
  /// (documents_analyzed, high_risk_count, ai_chat_count, storage_used_mb).
  /// Silent — never changes auth state or shows an error to the user.
  Future<void> refreshStats() async {
    try {
      final result = await _authService.getMe();
      if (result['success'] && result['data'] != null) {
        _user = UserModel.fromJson(result['data']);
        notifyListeners();
      }
    } catch (_) {
      // Silently ignore — stats are non-critical
    }
  }

  Future<void> logout() async {
    const storage = FlutterSecureStorage();
    final refreshToken = await storage.read(key: 'refresh_token');
    
    if (refreshToken != null) {
      try {
        await _authService.logout(refreshToken);
      } catch (_) {}
    }
    
    await storage.delete(key: 'auth_token');
    await storage.delete(key: 'refresh_token');
    
    try {
      if (_googleInitialized) {
        await _googleSignIn.disconnect();
      }
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('AuthProvider: Error signing out of Google: $e');
    }
    
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      debugPrint('AuthProvider: Error signing out of Firebase: $e');
    }
    
    _user = null;
    _authState = AuthState.unauthenticated;
    notifyListeners();
  }

  Future<void> checkInitialAuth() async {
    debugPrint('AuthProvider: Starting initial auth check...');
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');
      final refreshToken = await storage.read(key: 'refresh_token');
      
      debugPrint('AuthProvider: Token found: ${token != null}');

      if (token != null && _isTokenExpired(token)) {
        debugPrint('AuthProvider: Cached token expired locally. Clearing saved auth.');
        logout();
        return;
      }
      
      if (token != null) {
        // Verify token with backend
        final result = await _authService.getMe();
        if (result['success']) {
          _user = UserModel.fromJson(result['data']);
          _authState = AuthState.authenticated;
          debugPrint('AuthProvider: Token verified, user loaded: ${_user?.name}');
        } else {
          final message = result['message']?.toString() ?? '';
          debugPrint('AuthProvider: Token verification failed: $message');
          final isAuthError = message.contains('401') || message.contains('403') || message.contains('credentials') || message.contains('Unauthorized');
          
          if (isAuthError) {
            if (refreshToken != null) {
              // Attempt to refresh token
              final refreshResult = await _authService.refreshToken(refreshToken);
              if (refreshResult['success']) {
                await storage.write(key: 'auth_token', value: refreshResult['data']['access_token']);
                final newResult = await _authService.getMe();
                if (newResult['success']) {
                  _user = UserModel.fromJson(newResult['data']);
                  _authState = AuthState.authenticated;
                  notifyListeners();
                  return;
                }
              }
            }
            logout();
          } else {
            // Transient network/server error: do NOT log out or delete tokens
            _authState = AuthState.unauthenticated;
            _errorMessage = "Server is unreachable. Operating in offline mode.";
          }
        }
      } else {
        _authState = AuthState.unauthenticated;
        debugPrint('AuthProvider: No token, set to unauthenticated');
      }
    } catch (e) {
      debugPrint('AuthProvider: Error during initial auth check: $e');
      _authState = AuthState.unauthenticated;
    } finally {
      notifyListeners();
    }
  }

  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final rawPayload = parts[1];
      final normalized = base64Url.normalize(rawPayload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = json.decode(decoded) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true)
            .isBefore(DateTime.now().toUtc());
      }
      return true;
    } catch (e) {
      debugPrint('AuthProvider: JWT decode failed: $e');
      return true;
    }
  }

  Future<bool> validateBackend() async {
    debugPrint('AuthProvider: Validating backend health...');
    try {
      final result = await _authService.healthCheck();
      debugPrint('AuthProvider: Backend health check result: $result');
      return result['success'];
    } catch (e) {
      debugPrint('AuthProvider: Backend health check exception: $e');
      return false;
    }
  }
}
