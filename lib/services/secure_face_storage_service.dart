// lib/services/secure_face_storage_service.dart - UPDATED FOR ENHANCED FEATURES

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import the new enhanced model
import 'package:phoenician_face_auth/model/enhanced_face_features.dart';
import 'package:phoenician_face_auth/model/user_model.dart'; // Keep for backward compatibility
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ ADD THESE MISSING IMPORTS
import 'package:cloud_firestore/cloud_firestore.dart';  // For DocumentSnapshot
import 'package:phoenician_face_auth/services/connectivity_service.dart';  // For ConnectivityService
import 'package:phoenician_face_auth/services/service_locator.dart';  // For getIt

// Import the new enhanced model
import 'package:phoenician_face_auth/model/enhanced_face_features.dart';
import 'package:phoenician_face_auth/model/user_model.dart';

class SecureFaceStorageService {
  static const String _imagePrefix = 'secure_face_image_';
  static const String _featuresPrefix = 'secure_face_features_';
  static const String _enhancedFeaturesPrefix = 'secure_enhanced_face_features_'; // NEW
  static const String _registeredPrefix = 'face_registered_';
  static const String _enhancedRegisteredPrefix = 'enhanced_face_registered_'; // NEW

  /// Save face image securely
  Future<void> saveFaceImage(String employeeId, String base64Image) async {
    try {
      debugPrint("SecureFaceStorage: Saving face image for $employeeId");

      // Clean the image data
      String cleanedImage = base64Image;
      if (cleanedImage.contains('data:image') && cleanedImage.contains(',')) {
        cleanedImage = cleanedImage.split(',')[1];
        debugPrint("SecureFaceStorage: Cleaned data URL format");
      }

      // Primary storage: Try external storage first (more secure, persists across app updates)
      bool savedToExternal = await _saveToExternalStorage(employeeId, cleanedImage, 'image');

      if (!savedToExternal) {
        debugPrint("SecureFaceStorage: External storage failed, using SharedPreferences fallback");
        // Fallback: SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_imagePrefix$employeeId', cleanedImage);
      }

      debugPrint("SecureFaceStorage: ✅ Face image saved successfully for $employeeId");
    } catch (e) {
      debugPrint("SecureFaceStorage: ❌ Error saving face image: $e");
      rethrow;
    }
  }

  /// Get face image securely
  Future<String?> getFaceImage(String employeeId) async {
    try {
      debugPrint("SecureFaceStorage: Retrieving face image for $employeeId");

      // Try external storage first
      String? image = await _getFromExternalStorage(employeeId, 'image');

      if (image != null) {
        debugPrint("SecureFaceStorage: ✅ Retrieved image from external storage");
        return image;
      }

      // Fallback: SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      image = prefs.getString('$_imagePrefix$employeeId');

      if (image != null) {
        debugPrint("SecureFaceStorage: ✅ Retrieved image from SharedPreferences");
        return image;
      }

      debugPrint("SecureFaceStorage: ❌ No face image found for $employeeId");
      return null;
    } catch (e) {
      debugPrint("SecureFaceStorage: ❌ Error retrieving face image: $e");
      return null;
    }
  }

  /// Save legacy face features (for backward compatibility)
  Future<void> saveFaceFeatures(String employeeId, FaceFeatures features) async {
    try {
      debugPrint("SecureFaceStorage: Saving legacy face features for $employeeId");

      String featuresJson = jsonEncode(features.toJson());

      // Try external storage first
      bool savedToExternal = await _saveToExternalStorage(employeeId, featuresJson, 'features');

      if (!savedToExternal) {
        // Fallback: SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_featuresPrefix$employeeId', featuresJson);
      }

      debugPrint("SecureFaceStorage: ✅ Legacy face features saved for $employeeId");
    } catch (e) {
      debugPrint("SecureFaceStorage: ❌ Error saving legacy face features: $e");
      rethrow;
    }
  }


  // ADD THESE METHODS TO SecureFaceStorageService class

  /// NEW: Download face data from Firestore when local data is missing
  Future<bool> downloadFaceDataFromCloud(String employeeId) async {
    try {
      debugPrint("🌐 Attempting to download face data from cloud for: $employeeId");

      // Check if we're online
      final connectivityService = getIt<ConnectivityService>();
      if (connectivityService.currentStatus == ConnectionStatus.offline) {
        debugPrint("❌ Cannot download - device is offline");
        return false;
      }

      // Get data from Firestore
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(employeeId)
          .get()
          .timeout(Duration(seconds: 10));

      if (!doc.exists) {
        debugPrint("❌ Employee document not found in Firestore");
        return false;
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      // Check if face data exists in cloud
      bool hasFaceImage = data.containsKey('image') && data['image'] != null;
      bool hasEnhancedFeatures = data.containsKey('enhancedFaceFeatures') && data['enhancedFaceFeatures'] != null;
      bool isFaceRegistered = data['faceRegistered'] ?? false;

      if (!hasFaceImage || !isFaceRegistered) {
        debugPrint("❌ No valid face data found in cloud");
        return false;
      }

      debugPrint("✅ Face data found in cloud, downloading...");

      // Download and save face image
      String faceImage = data['image'];
      await saveFaceImage(employeeId, faceImage);
      debugPrint("✅ Face image downloaded and saved");

      // Download and save enhanced features (if available)
      if (hasEnhancedFeatures) {
        try {
          Map<String, dynamic> featuresMap = data['enhancedFaceFeatures'];
          EnhancedFaceFeatures features = EnhancedFaceFeatures.fromJson(featuresMap);
          await saveEnhancedFaceFeatures(employeeId, features);
          await setEnhancedFaceRegistered(employeeId, true);
          debugPrint("✅ Enhanced face features downloaded and saved");
        } catch (e) {
          debugPrint("⚠️ Error downloading enhanced features: $e");
          // Continue with basic registration
        }
      }

      // Set registration flags
      await setFaceRegistered(employeeId, true);

      // Also save to standard SharedPreferences for backward compatibility
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('employee_image_$employeeId', faceImage);
      await prefs.setBool('face_registered_$employeeId', true);

      if (hasEnhancedFeatures) {
        await prefs.setString('enhanced_face_features_$employeeId',
            jsonEncode(data['enhancedFaceFeatures']));
      }

      debugPrint("🎉 Face data successfully downloaded and restored for: $employeeId");
      return true;

    } catch (e) {
      debugPrint("❌ Error downloading face data from cloud: $e");
      return false;
    }
  }

  /// NEW: Check if local face data is missing and needs cloud recovery
  Future<bool> needsCloudRecovery(String employeeId) async {
    try {
      // Check if we have any local face data
      String? localImage = await getFaceImage(employeeId);
      bool hasLocalImage = localImage != null && localImage.isNotEmpty;

      // Check registration flags
      bool isRegistered = await isFaceRegistered(employeeId);
      bool isEnhancedRegistered = await isEnhancedFaceRegistered(employeeId);

      // Check SharedPreferences backup
      final prefs = await SharedPreferences.getInstance();
      bool hasBackupImage = prefs.getString('employee_image_$employeeId') != null;

      // If registration flags exist but no actual data, we need recovery
      bool needsRecovery = (isRegistered || isEnhancedRegistered) && !hasLocalImage && !hasBackupImage;

      debugPrint("🔍 Face data status for $employeeId:");
      debugPrint("   - Has local image: $hasLocalImage");
      debugPrint("   - Is registered: $isRegistered");
      debugPrint("   - Is enhanced registered: $isEnhancedRegistered");
      debugPrint("   - Has backup image: $hasBackupImage");
      debugPrint("   - Needs recovery: $needsRecovery");

      return needsRecovery;

    } catch (e) {
      debugPrint("❌ Error checking if cloud recovery needed: $e");
      return false;
    }
  }

  /// NEW: Validate that all required face data exists locally
  Future<bool> validateLocalFaceData(String employeeId) async {
    try {
      String? image = await getFaceImage(employeeId);
      bool hasImage = image != null && image.isNotEmpty;

      bool isRegistered = await isFaceRegistered(employeeId);
      bool isEnhancedRegistered = await isEnhancedFaceRegistered(employeeId);

      // Check if we have the registration flag but missing data
      if ((isRegistered || isEnhancedRegistered) && !hasImage) {
        debugPrint("⚠️ Registration flag exists but face data missing for: $employeeId");
        return false;
      }

      return hasImage && (isRegistered || isEnhancedRegistered);

    } catch (e) {
      debugPrint("❌ Error validating local face data: $e");
      return false;
    }
  }

  /// NEW: Smart recovery - check and download if needed
  Future<bool> ensureFaceDataAvailable(String employeeId) async {
    try {
      debugPrint("🔄 Ensuring face data is available for: $employeeId");

      // First, validate current local data
      bool isValid = await validateLocalFaceData(employeeId);
      if (isValid) {
        debugPrint("✅ Local face data is valid");
        return true;
      }

      // Check if we need cloud recovery
      bool needsRecovery = await needsCloudRecovery(employeeId);
      if (!needsRecovery) {
        debugPrint("ℹ️ No cloud recovery needed");
        return false;
      }

      // Attempt cloud recovery
      debugPrint("🌐 Attempting cloud recovery...");
      bool recovered = await downloadFaceDataFromCloud(employeeId);

      if (recovered) {
        debugPrint("🎉 Face data successfully recovered from cloud");
        return true;
      } else {
        debugPrint("❌ Failed to recover face data from cloud");
        return false;
      }

    } catch (e) {
      debugPrint("❌ Error in ensureFaceDataAvailable: $e");
      return false;
    }
  }

  /// Get legacy face features (for backward compatibility)
  Future<FaceFeatures?> getFaceFeatures(String employeeId) async {
    try {
      debugPrint("SecureFaceStorage: Retrieving legacy face features for $employeeId");

      // Try external storage first
      String? featuresJson = await _getFromExternalStorage(employeeId, 'features');

      if (featuresJson == null) {
        // Fallback: SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        featuresJson = prefs.getString('$_featuresPrefix$employeeId');
      }

      if (featuresJson != null) {
        Map<String, dynamic> featuresMap = jsonDecode(featuresJson);
        FaceFeatures features = FaceFeatures.fromJson(featuresMap);
        debugPrint("SecureFaceStorage: ✅ Retrieved legacy face features for $employeeId");
        return features;
      }

      debugPrint("SecureFaceStorage: ❌ No legacy face features found for $employeeId");
      return null;
    } catch (e) {
      debugPrint("SecureFaceStorage: ❌ Error retrieving legacy face features: $e");
      return null;
    }
  }

  /// NEW: Save enhanced face features
  Future<void> saveEnhancedFaceFeatures(String employeeId, EnhancedFaceFeatures features) async {
    try {
      debugPrint("SecureFaceStorage: Saving ENHANCED face features for $employeeId");

      String featuresJson = jsonEncode(features.toJson());

      // Try external storage first
      bool savedToExternal = await _saveToExternalStorage(employeeId, featuresJson, 'enhanced_features');

      if (!savedToExternal) {
        // Fallback: SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_enhancedFeaturesPrefix$employeeId', featuresJson);
      }

      // Also set the enhanced registration flag
      await setEnhancedFaceRegistered(employeeId, true);

      debugPrint("SecureFaceStorage: ✅ Enhanced face features saved for $employeeId");
      debugPrint("SecureFaceStorage: Features summary: $features");
    } catch (e) {
      debugPrint("SecureFaceStorage: ❌ Error saving enhanced face features: $e");
      rethrow;
    }
  }

  /// NEW: Get enhanced face features
  Future<EnhancedFaceFeatures?> getEnhancedFaceFeatures(String employeeId) async {
    try {
      debugPrint("SecureFaceStorage: Retrieving ENHANCED face features for $employeeId");

      // Try external storage first
      String? featuresJson = await _getFromExternalStorage(employeeId, 'enhanced_features');

      if (featuresJson == null) {
        // Fallback: SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        featuresJson = prefs.getString('$_enhancedFeaturesPrefix$employeeId');
      }

      if (featuresJson != null) {
        Map<String, dynamic> featuresMap = jsonDecode(featuresJson);
        EnhancedFaceFeatures features = EnhancedFaceFeatures.fromJson(featuresMap);
        debugPrint("SecureFaceStorage: ✅ Retrieved enhanced face features for $employeeId");
        debugPrint("SecureFaceStorage: Features quality: ${features.faceQualityScore}");
        return features;
      }

      debugPrint("SecureFaceStorage: ❌ No enhanced face features found for $employeeId");
      return null;
    } catch (e) {
      debugPrint("SecureFaceStorage: ❌ Error retrieving enhanced face features: $e");
      return null;
    }
  }

  /// Set face registered flag (legacy)
  Future<void> setFaceRegistered(String employeeId, bool isRegistered) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_registeredPrefix$employeeId', isRegistered);
      debugPrint("SecureFaceStorage: Set legacy face registered for $employeeId: $isRegistered");
    } catch (e) {
      debugPrint("SecureFaceStorage: Error setting face registered flag: $e");
    }
  }

  /// Check if face is registered (legacy)
  Future<bool> isFaceRegistered(String employeeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool isRegistered = prefs.getBool('$_registeredPrefix$employeeId') ?? false;
      debugPrint("SecureFaceStorage: Legacy face registered for $employeeId: $isRegistered");
      return isRegistered;
    } catch (e) {
      debugPrint("SecureFaceStorage: Error checking face registered flag: $e");
      return false;
    }
  }

  /// NEW: Set enhanced face registered flag
  Future<void> setEnhancedFaceRegistered(String employeeId, bool isRegistered) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_enhancedRegisteredPrefix$employeeId', isRegistered);
      debugPrint("SecureFaceStorage: Set ENHANCED face registered for $employeeId: $isRegistered");
    } catch (e) {
      debugPrint("SecureFaceStorage: Error setting enhanced face registered flag: $e");
    }
  }

  /// NEW: Check if enhanced face is registered
  Future<bool> isEnhancedFaceRegistered(String employeeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool isRegistered = prefs.getBool('$_enhancedRegisteredPrefix$employeeId') ?? false;
      debugPrint("SecureFaceStorage: Enhanced face registered for $employeeId: $isRegistered");
      return isRegistered;
    } catch (e) {
      debugPrint("SecureFaceStorage: Error checking enhanced face registered flag: $e");
      return false;
    }
  }

  /// NEW: Check which registration type is available
  Future<String> getRegistrationType(String employeeId) async {
    bool hasEnhanced = await isEnhancedFaceRegistered(employeeId);
    bool hasLegacy = await isFaceRegistered(employeeId);

    if (hasEnhanced) {
      return 'enhanced';
    } else if (hasLegacy) {
      return 'legacy';
    } else {
      return 'none';
    }
  }

  /// Clear all face data for an employee
  Future<void> clearFaceData(String employeeId) async {
    try {
      debugPrint("SecureFaceStorage: Clearing all face data for $employeeId");

      // Clear from external storage
      await _deleteFromExternalStorage(employeeId, 'image');
      await _deleteFromExternalStorage(employeeId, 'features');
      await _deleteFromExternalStorage(employeeId, 'enhanced_features');

      // Clear from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_imagePrefix$employeeId');
      await prefs.remove('$_featuresPrefix$employeeId');
      await prefs.remove('$_enhancedFeaturesPrefix$employeeId');
      await prefs.remove('$_registeredPrefix$employeeId');
      await prefs.remove('$_enhancedRegisteredPrefix$employeeId');

      debugPrint("SecureFaceStorage: ✅ All face data cleared for $employeeId");
    } catch (e) {
      debugPrint("SecureFaceStorage: ❌ Error clearing face data: $e");
    }
  }

  /// Get comprehensive face data info for debugging
  Future<Map<String, dynamic>> getFaceDataInfo(String employeeId) async {
    try {
      String? image = await getFaceImage(employeeId);
      FaceFeatures? legacyFeatures = await getFaceFeatures(employeeId);
      EnhancedFaceFeatures? enhancedFeatures = await getEnhancedFaceFeatures(employeeId);
      bool isLegacyRegistered = await isFaceRegistered(employeeId);
      bool isEnhancedRegistered = await isEnhancedFaceRegistered(employeeId);
      String registrationType = await getRegistrationType(employeeId);

      return {
        'employeeId': employeeId,
        'hasImage': image != null,
        'imageSize': image?.length ?? 0,
        'hasLegacyFeatures': legacyFeatures != null,
        'hasEnhancedFeatures': enhancedFeatures != null,
        'isLegacyRegistered': isLegacyRegistered,
        'isEnhancedRegistered': isEnhancedRegistered,
        'registrationType': registrationType,
        'enhancedQuality': enhancedFeatures?.faceQualityScore,
        'enhancedLandmarkCount': enhancedFeatures?.landmarkCount ?? 0,
        'enhancedContourCount': 0, // Simplified version doesn't track contours separately
      };
    } catch (e) {
      debugPrint("SecureFaceStorage: Error getting face data info: $e");
      return {'error': e.toString()};
    }
  }

  // Private helper methods for external storage

  Future<bool> _saveToExternalStorage(String employeeId, String data, String dataType) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        Directory? directory = await getExternalStorageDirectory();

        if (directory != null) {
          String filePath = '${directory.path}/face_data_${employeeId}_$dataType.dat';
          File file = File(filePath);

          // Create directory if it doesn't exist
          await file.parent.create(recursive: true);

          // Write data
          await file.writeAsString(data);
          debugPrint("SecureFaceStorage: Saved $dataType to external storage: $filePath");
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint("SecureFaceStorage: Error saving to external storage: $e");
      return false;
    }
  }

  Future<String?> _getFromExternalStorage(String employeeId, String dataType) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        Directory? directory = await getExternalStorageDirectory();

        if (directory != null) {
          String filePath = '${directory.path}/face_data_${employeeId}_$dataType.dat';
          File file = File(filePath);

          if (await file.exists()) {
            String data = await file.readAsString();
            debugPrint("SecureFaceStorage: Retrieved $dataType from external storage");
            return data;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint("SecureFaceStorage: Error reading from external storage: $e");
      return null;
    }
  }

  Future<void> _deleteFromExternalStorage(String employeeId, String dataType) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        Directory? directory = await getExternalStorageDirectory();

        if (directory != null) {
          String filePath = '${directory.path}/face_data_${employeeId}_$dataType.dat';
          File file = File(filePath);

          if (await file.exists()) {
            await file.delete();
            debugPrint("SecureFaceStorage: Deleted $dataType from external storage");
          }
        }
      }
    } catch (e) {
      debugPrint("SecureFaceStorage: Error deleting from external storage: $e");
    }
  }
}