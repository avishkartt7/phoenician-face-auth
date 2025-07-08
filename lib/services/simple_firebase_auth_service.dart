// lib/services/simple_firebase_auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SimpleFirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current Firebase user
  static User? get currentUser => _auth.currentUser;

  /// Check if user is authenticated
  static bool get isAuthenticated => _auth.currentUser != null;

  /// Simple anonymous authentication for file uploads
  static Future<bool> ensureAuthenticated() async {
    try {
      // Check if already authenticated
      if (_auth.currentUser != null) {
        debugPrint("✅ User already authenticated anonymously");
        return true;
      }

      debugPrint("🔐 Signing in anonymously for file upload...");

      // Sign in anonymously
      final userCredential = await _auth.signInAnonymously();

      if (userCredential.user != null) {
        debugPrint("✅ Anonymous authentication successful");
        debugPrint("🔑 User UID: ${userCredential.user!.uid}");
        return true;
      }

      debugPrint("❌ Anonymous authentication failed - no user returned");
      return false;

    } catch (e) {
      debugPrint("❌ Error during anonymous authentication: $e");
      return false;
    }
  }

  /// Sign out current user
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint("👋 User signed out successfully");
    } catch (e) {
      debugPrint("❌ Error signing out: $e");
    }
  }

  /// Get authentication token for API calls
  static Future<String?> getAuthToken() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        return await user.getIdToken();
      }
      return null;
    } catch (e) {
      debugPrint("❌ Error getting auth token: $e");
      return null;
    }
  }
}