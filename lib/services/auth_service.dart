import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Anonymous Firebase authentication.
///
/// Every install gets a unique, random `uid` from Firebase on first launch.
/// The session token is persisted by the Firebase SDK, so the same `uid`
/// is restored on subsequent launches without any user interaction.
/// No personal data is stored — only the anonymous `uid` exists in Firebase.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Current anonymous uid, or `null` if sign-in hasn't completed yet.
  String? get uid => _auth.currentUser?.uid;

  /// Emits the current user whenever auth state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Makes sure the device has an anonymous account and returns its uid.
  ///
  /// Reuses the existing session if present, otherwise creates a new
  /// anonymous user. Returns `null` if sign-in failed (e.g. no network) —
  /// the app should keep working without it.
  Future<String?> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) {
      debugPrint('[Auth] restored anonymous uid: ${existing.uid}');
      return existing.uid;
    }

    try {
      final credential = await _auth.signInAnonymously();
      final uid = credential.user?.uid;
      debugPrint('[Auth] created anonymous uid: $uid');
      return uid;
    } on FirebaseAuthException catch (e) {
      debugPrint('[Auth] sign-in failed: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[Auth] sign-in failed: $e');
      return null;
    }
  }
}
