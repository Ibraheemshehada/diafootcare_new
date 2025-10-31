// lib/core/services/auth_services.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ---------- Sign In / Up / Out ----------
  Future<User?> signIn(String email, String password) async {
    try {
      final res = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return res.user;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  Future<User?> signUp(String email, String password) async {
    try {
      final res = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return res.user;
    } catch (e) {
      print('Sign-up error: $e');
      return null;
    }
  }

  Future<void> signOut() async => _auth.signOut();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ---------- Password reset (email) ----------
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // (Only if you’ll handle deep link in app)
  Future<String?> verifyPasswordResetCode(String oobCode) async {
    return await _auth.verifyPasswordResetCode(oobCode);
  }

  Future<void> confirmPasswordReset({
    required String oobCode,
    required String newPassword,
  }) async {
    await _auth.confirmPasswordReset(code: oobCode, newPassword: newPassword);
  }

  // Update while logged-in
  Future<void> updatePasswordWhileLoggedIn(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-user');
    await user.updatePassword(newPassword);
    await user.reload();
  }

  // Update user display name
  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-user');
    await user.updateDisplayName(displayName);
    await user.reload();
  }
}
