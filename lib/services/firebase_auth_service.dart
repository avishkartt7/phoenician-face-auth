// lib/services/firebase_auth_service.dart - FIXED VERSION FOR YOUR RULES

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current Firebase user
  static User? get currentUser => _auth.currentUser;

  /// Check if user is authenticated
  static bool get isAuthenticated => _auth.currentUser != null;

  /// Get current user's employee ID
  static String? get currentEmployeeId => _auth.currentUser?.uid;

  /// ✅ MAIN AUTHENTICATION METHOD - USE THIS IN PIN ENTRY
  static Future<UserCredential?> authenticateEmployeeByPin(String pin) async {
    try {
      debugPrint("🔐 Starting authentication for PIN: $pin");

      // Step 1: Create deterministic email from PIN
      final email = 'emp$pin@yourcompany.com';
      final password = 'emp${pin}secure123'; // More secure password

      UserCredential? userCredential;

      try {
        // Try to sign in existing user
        userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        debugPrint("✅ Existing user signed in successfully");

      } catch (signInError) {
        debugPrint("⚠️ User doesn't exist, checking if PIN is valid...");

        // Step 2: Check if PIN exists in employees collection using ADMIN access
        bool pinExists = await _checkPinExistsWithAdminAccess(pin);

        if (!pinExists) {
          debugPrint("❌ Invalid PIN: $pin");
          return null;
        }

        // Step 3: Create account for valid PIN
        try {
          userCredential = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

          debugPrint("✅ New user account created successfully");

          // Step 4: Set up user profile
          await _setupUserProfile(userCredential.user!.uid, pin);

        } catch (createError) {
          debugPrint("❌ Failed to create account: $createError");
          return null;
        }
      }

      // Step 5: Update last login
      await _updateLastLogin(userCredential!.user!.uid, pin);

      debugPrint("🎉 Authentication completed successfully for PIN: $pin");
      return userCredential;

    } catch (e) {
      debugPrint("❌ Authentication error: $e");
      return null;
    }
  }

  /// ✅ CHECK IF PIN EXISTS USING TEMPORARY ADMIN ACCESS
  static Future<bool> _checkPinExistsWithAdminAccess(String pin) async {
    try {
      // Create temporary admin authentication
      debugPrint("🔑 Creating temporary admin access to validate PIN");

      // Use a service account or admin authentication here
      // For now, we'll use anonymous auth which should be allowed for read operations
      UserCredential? tempAuth = await _auth.signInAnonymously();

      if (tempAuth.user != null) {
        debugPrint("✅ Temporary auth created, checking PIN validity");

        try {
          // Query employees collection to check if PIN exists
          QuerySnapshot querySnapshot = await _firestore
              .collection('employees')
              .where('pin', isEqualTo: pin)
              .limit(1)
              .get();

          bool exists = querySnapshot.docs.isNotEmpty;
          debugPrint("📋 PIN check result: ${exists ? 'Valid' : 'Invalid'}");

          // Sign out temporary user
          await _auth.signOut();

          return exists;

        } catch (queryError) {
          debugPrint("❌ Error querying PIN: $queryError");
          await _auth.signOut();
          return false;
        }
      }

      return false;
    } catch (e) {
      debugPrint("❌ Error in PIN validation: $e");
      return false;
    }
  }

  /// ✅ SETUP USER PROFILE AFTER ACCOUNT CREATION
  static Future<void> _setupUserProfile(String uid, String pin) async {
    try {
      debugPrint("👤 Setting up user profile for UID: $uid");

      await _firestore.collection('user_profiles').doc(uid).set({
        'employeePin': pin,
        'email': 'emp$pin@yourcompany.com',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'isActive': true,
        'authMethod': 'pin',
        'permissions': ['employee'], // Basic employee permissions
      });

      debugPrint("✅ User profile created successfully");
    } catch (e) {
      debugPrint("❌ Error setting up user profile: $e");
    }
  }

  /// ✅ UPDATE LAST LOGIN TIMESTAMP
  static Future<void> _updateLastLogin(String uid, String pin) async {
    try {
      await _firestore.collection('user_profiles').doc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
        'employeePin': pin, // Ensure pin is stored
      });
    } catch (e) {
      debugPrint("⚠️ Error updating last login: $e");
      // Don't fail authentication for this
    }
  }

  /// ✅ GET EMPLOYEE DATA AFTER AUTHENTICATION
  static Future<Map<String, dynamic>?> getEmployeeDataByPin(String pin) async {
    try {
      if (_auth.currentUser == null) {
        debugPrint("❌ No authenticated user");
        return null;
      }

      debugPrint("📊 Fetching employee data for PIN: $pin");

      // Now that user is authenticated, we can access Firestore
      QuerySnapshot querySnapshot = await _firestore
          .collection('employees')
          .where('pin', isEqualTo: pin)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot doc = querySnapshot.docs.first;
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Add document ID
        data['documentId'] = doc.id;

        debugPrint("✅ Employee data retrieved successfully");
        return data;
      }

      debugPrint("❌ No employee found with PIN: $pin");
      return null;

    } catch (e) {
      debugPrint("❌ Error getting employee data: $e");
      return null;
    }
  }

  /// ✅ CHECK IF USER HAS SPECIFIC PERMISSIONS
  static Future<bool> hasPermission(String permission) async {
    try {
      if (_auth.currentUser == null) return false;

      // Check if user is admin
      final adminDoc = await _firestore
          .collection('admins')
          .doc(_auth.currentUser!.uid)
          .get();

      if (adminDoc.exists) {
        debugPrint("✅ User has admin permissions");
        return true;
      }

      // Check user profile permissions
      final profileDoc = await _firestore
          .collection('user_profiles')
          .doc(_auth.currentUser!.uid)
          .get();

      if (profileDoc.exists) {
        final data = profileDoc.data() as Map<String, dynamic>;
        final permissions = data['permissions'] as List<dynamic>? ?? [];
        return permissions.contains(permission);
      }

      return false;
    } catch (e) {
      debugPrint("❌ Error checking permissions: $e");
      return false;
    }
  }

  /// ✅ SIGN OUT USER
  static Future<void> signOut() async {
    try {
      await _auth.signOut();

      // Clear local authentication data
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('authenticated_user_id');
      await prefs.setBool('is_authenticated', false);

      debugPrint("👋 User signed out successfully");
    } catch (e) {
      debugPrint("❌ Error signing out: $e");
    }
  }

  /// ✅ GET AUTHENTICATION TOKEN
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

  /// ✅ LISTEN TO AUTH STATE CHANGES
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// ✅ CHECK CURRENT AUTHENTICATION STATUS
  static Future<bool> checkAuthStatus() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        debugPrint("✅ User is authenticated: ${user.uid}");
        return true;
      } else {
        debugPrint("❌ No authenticated user");
        return false;
      }
    } catch (e) {
      debugPrint("❌ Error checking auth status: $e");
      return false;
    }
  }

  /// ✅ GET EMPLOYEE ID FROM AUTHENTICATED USER
  static Future<String?> getAuthenticatedEmployeeId() async {
    try {
      if (_auth.currentUser == null) return null;

      final profileDoc = await _firestore
          .collection('user_profiles')
          .doc(_auth.currentUser!.uid)
          .get();

      if (profileDoc.exists) {
        final data = profileDoc.data() as Map<String, dynamic>;
        return data['employeePin'] as String?;
      }

      return null;
    } catch (e) {
      debugPrint("❌ Error getting employee ID: $e");
      return null;
    }
  }
}