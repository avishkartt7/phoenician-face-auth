// lib/services/registration_completion_service.dart - CREATE THIS NEW FILE

import 'dart:convert'; // ✅ ADDED for jsonDecode
import 'package:flutter/foundation.dart'; // ✅ ADDED for debugPrint
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationCompletionService {

  /// Mark user as fully registered and authenticated
  /// Call this after successful face registration
  static Future<void> markRegistrationComplete(String employeeId) async {
    try {
      debugPrint("✅ Marking registration complete for: $employeeId");

      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Mark as fully authenticated
      await prefs.setBool('is_authenticated', true);
      await prefs.setInt('authentication_timestamp', DateTime.now().millisecondsSinceEpoch);

      // Update Firestore with completion status
      try {
        await FirebaseFirestore.instance
            .collection('employees')
            .doc(employeeId)
            .update({
          'profileCompleted': true,
          'registrationCompleted': true,
          'faceRegistered': true,
          'lastLoginDate': FieldValue.serverTimestamp(),
        });

        debugPrint("✅ Registration status updated in Firestore");
      } catch (e) {
        debugPrint("⚠️ Error updating Firestore: $e");
        // Continue - local storage update is more important
      }

      debugPrint("🎉 Registration completion process finished");

    } catch (e) {
      debugPrint("❌ Error marking registration complete: $e");
    }
  }

  /// Check if user has complete registration
  static Future<bool> isRegistrationComplete(String employeeId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Check authentication status
      bool isAuthenticated = prefs.getBool('is_authenticated') ?? false;
      if (!isAuthenticated) return false;

      // Check face registration
      bool faceRegistered = prefs.getBool('face_registered_$employeeId') ?? false;
      String? storedImage = prefs.getString('employee_image_$employeeId');
      bool hasImage = storedImage != null && storedImage.isNotEmpty;

      // Check user data
      String? userData = prefs.getString('user_data_$employeeId');
      if (userData == null) return false;

      try {
        Map<String, dynamic> data = jsonDecode(userData);
        bool profileCompleted = data['profileCompleted'] ?? false;
        bool registrationCompleted = data['registrationCompleted'] ?? false;

        return profileCompleted && registrationCompleted && faceRegistered && hasImage;
      } catch (e) {
        return false;
      }

    } catch (e) {
      debugPrint("❌ Error checking registration status: $e");
      return false;
    }
  }

  /// Clear incomplete registration data
  static Future<void> clearIncompleteRegistration(String employeeId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Don't clear user data, just mark as not fully authenticated
      await prefs.setBool('is_authenticated', false);

      debugPrint("🧹 Cleared incomplete registration for: $employeeId");
    } catch (e) {
      debugPrint("❌ Error clearing incomplete registration: $e");
    }
  }
}