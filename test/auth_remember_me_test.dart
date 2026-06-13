import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lexguard_ai/features/auth/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth remember_me persistence tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('Case 1: Remember Me OFF -> Login -> Reopen app -> Expects Login Screen (Unauthenticated)', () async {
      final authProvider = AuthProvider();

      // 1. User sets Remember Me = OFF
      authProvider.setRememberMe(false);
      expect(authProvider.rememberMe, isFalse);

      // 2. Perform a mock auth data save (simulating login success)
      final prefs = await SharedPreferences.getInstance();
      const storage = FlutterSecureStorage();

      await storage.write(key: 'auth_token', value: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjIwMDAwMDAwMDAsInN1YiI6InVzZXItMTIzIn0.signature');
      await prefs.setBool('remember_me', false);

      // 3. Simulate app close and reopen by triggering checkInitialAuth on a new instance
      final newAuthProvider = AuthProvider();
      await newAuthProvider.checkInitialAuth();

      // 4. Expect user to be unauthenticated (requires Login) and session data cleared
      expect(newAuthProvider.isAuthenticated, isFalse);
      expect(newAuthProvider.authState, equals(AuthState.unauthenticated));
      expect(await storage.read(key: 'auth_token'), isNull);
    });

    test('Case 2: Remember Me ON -> Login -> Reopen app -> Expects Auto-Login (Authenticated)', () async {
      final prefs = await SharedPreferences.getInstance();
      const storage = FlutterSecureStorage();

      // Simulate login with Remember Me ON
      await storage.write(key: 'auth_token', value: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjIwMDAwMDAwMDAsInN1YiI6InVzZXItMTIzIn0.signature');
      await prefs.setBool('remember_me', true);
      // Save dummy user data in shared prefs
      await prefs.setString('user_data', '{"id": "user-123", "full_name": "Test User", "email": "test@test.com", "role": "User", "created_at": "2026-06-13T00:00:00Z"}');

      // Reopen app
      final newAuthProvider = AuthProvider();
      await newAuthProvider.checkInitialAuth();

      // Expect auto-login to succeed
      expect(newAuthProvider.isAuthenticated, isTrue);
      expect(newAuthProvider.authState, equals(AuthState.authenticated));
      expect(newAuthProvider.user?.name, equals('Test User'));
    });

    test('Case 3: Expired Token -> Reopen app -> Expects Logout/Unauthenticated', () async {
      final prefs = await SharedPreferences.getInstance();
      const storage = FlutterSecureStorage();

      // Simulate login with Remember Me ON but an invalid/expired token (no three parts or decode fail)
      await storage.write(key: 'auth_token', value: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjEwMDAwMDAwMDAsInN1YiI6InVzZXItMTIzIn0.signature'); // exp = 1000000000 (past)
      await prefs.setBool('remember_me', true);

      // Reopen app
      final newAuthProvider = AuthProvider();
      await newAuthProvider.checkInitialAuth();

      // Expect unauthenticated
      expect(newAuthProvider.isAuthenticated, isFalse);
    });

    test('Case 4: Logout -> Expects session and remember_me cleared', () async {
      final prefs = await SharedPreferences.getInstance();
      const storage = FlutterSecureStorage();

      // Simulate active logged-in state
      await storage.write(key: 'auth_token', value: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjIwMDAwMDAwMDAsInN1YiI6InVzZXItMTIzIn0.signature');
      await prefs.setBool('remember_me', true);

      final authProvider = AuthProvider();
      await authProvider.checkInitialAuth();
      expect(authProvider.isAuthenticated, isTrue);

      // Logout
      await authProvider.logout();

      // Expect clean state
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.rememberMe, isFalse);
      expect(await storage.read(key: 'auth_token'), isNull);
      expect(prefs.getBool('remember_me'), isNull);
    });
  });
}
