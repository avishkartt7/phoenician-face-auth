// lib/common/utils/enhanced_face_extractor.dart - iOS COMPATIBLE VERSION

import 'dart:io';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:phoenician_face_auth/model/enhanced_face_features.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class EnhancedFaceExtractor {
  // Create face detector with iOS-optimized settings
  static final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableContours: true,
      enableTracking: true,
      minFaceSize: Platform.isIOS ? 0.05 : 0.1,  // Lower for iOS
      performanceMode: Platform.isIOS 
          ? FaceDetectorMode.fast  // Fast mode for iOS
          : FaceDetectorMode.accurate,
    ),
  );

  /// Extract enhanced face features - iOS compatible
  static Future<EnhancedFaceFeatures?> extractEnhancedFeatures(
      InputImage inputImage, {
        double? screenWidth,
        double? screenHeight,
        double minimumQuality = 0.5,
      }) async {
    try {
      debugPrint("🔍 Starting enhanced face extraction (iOS compatible)...");

      // Detect faces in the image
      List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        debugPrint("❌ No faces detected");
        return null;
      }

      if (faces.length > 1) {
        debugPrint("⚠️ Multiple faces detected (${faces.length}), using largest");
      }

      // Get the largest/most prominent face
      Face primaryFace = _selectBestFace(faces);

      // Create enhanced features with iOS-specific adjustments
      EnhancedFaceFeatures features = EnhancedFaceFeatures.fromMLKitFace(
        primaryFace,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );

      debugPrint("✅ Enhanced features extracted: $features");

      // ✅ iOS-specific quality adjustment - be more lenient
      double adjustedMinQuality = Platform.isIOS ? 0.3 : minimumQuality;

      if ((features.faceQualityScore ?? 0) < adjustedMinQuality) {
        debugPrint("❌ Face quality too poor: ${features.faceQualityScore} (min: $adjustedMinQuality)");
        return null;
      }

      return features;

    } catch (e) {
      debugPrint("❌ Error extracting enhanced face features: $e");
      return null;
    }
  }

  /// Extract features for real-time processing (iOS optimized)
  static Future<EnhancedFaceFeatures?> extractForRealTime(
      InputImage inputImage, {
        double? screenWidth,
        double? screenHeight,
      }) async {
    try {
      debugPrint("🔍 Real-time face extraction (iOS optimized)...");

      // Use same detection but with more lenient quality requirements
      List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        debugPrint("❌ No faces detected in real-time");
        return null;
      }

      Face primaryFace = _selectBestFace(faces);

      // Create features with iOS-specific adjustments
      EnhancedFaceFeatures features = EnhancedFaceFeatures.fromMLKitFace(
        primaryFace,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );

      debugPrint("✅ Real-time features extracted: quality=${features.faceQualityScore}");

      return features;

    } catch (e) {
      debugPrint("❌ Error in real-time face extraction: $e");
      return null;
    }
  }

  /// Select the best face from multiple detected faces
  static Face _selectBestFace(List<Face> faces) {
    if (faces.length == 1) return faces.first;

    // Score each face and return the best one
    Face bestFace = faces.first;
    double bestScore = _calculateFaceScore(bestFace);

    for (Face face in faces.skip(1)) {
      double score = _calculateFaceScore(face);
      if (score > bestScore) {
        bestScore = score;
        bestFace = face;
      }
    }

    return bestFace;
  }

  /// Calculate a score for face selection - iOS optimized
  static double _calculateFaceScore(Face face) {
    double score = 0.0;

    // Prefer larger faces
    double faceSize = face.boundingBox.width * face.boundingBox.height;
    score += faceSize / 10000;

    // Prefer faces looking more straight ahead
    double headYaw = (face.headEulerAngleY ?? 0).abs();
    score += (90 - headYaw) / 90;

    // ✅ iOS-specific: Be more lenient with eye detection
    if (Platform.isIOS) {
      // For iOS, just check that eye probabilities exist
      if (face.leftEyeOpenProbability != null) score += 0.5;
      if (face.rightEyeOpenProbability != null) score += 0.5;
    } else {
      // For Android, check both eyes detected
      if (face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null) {
        score += 1.0;
      }
    }

    return score;
  }

  /// Generate detailed face analysis for debugging
  static Map<String, dynamic> analyzeFace(Face face) {
    Map<String, dynamic> landmarkData = {};
    face.landmarks.forEach((type, landmark) {
      if (landmark != null) {
        landmarkData[type.toString()] = {
          'x': landmark.position.x,
          'y': landmark.position.y,
        };
      }
    });

    Map<String, dynamic> contourData = {};
    face.contours.forEach((type, contour) {
      if (contour != null) {
        contourData[type.toString()] = {
          'pointCount': contour.points.length,
          'points': contour.points.map((point) => {
            'x': point.x,
            'y': point.y,
          }).toList(),
        };
      }
    });

    return {
      'platform': Platform.isIOS ? 'iOS' : 'Android',
      'boundingBox': {
        'left': face.boundingBox.left,
        'top': face.boundingBox.top,
        'right': face.boundingBox.right,
        'bottom': face.boundingBox.bottom,
        'width': face.boundingBox.width,
        'height': face.boundingBox.height,
      },
      'headPose': {
        'eulerX': face.headEulerAngleX,
        'eulerY': face.headEulerAngleY,
        'eulerZ': face.headEulerAngleZ,
      },
      'eyeStates': {
        'leftEyeOpen': face.leftEyeOpenProbability,
        'rightEyeOpen': face.rightEyeOpenProbability,
      },
      'expressions': {
        'smiling': face.smilingProbability,
      },
      'tracking': {
        'trackingId': face.trackingId,
      },
      'landmarks': landmarkData,
      'contours': contourData,
    };
  }

  /// Check if face meets minimum requirements for registration - iOS optimized
  static bool isValidForRegistration(EnhancedFaceFeatures features) {
    // ✅ iOS-specific quality checks - be more lenient
    double minQuality = Platform.isIOS ? 0.3 : 0.6;
    
    if ((features.faceQualityScore ?? 0) < minQuality) {
      debugPrint("❌ Registration failed: Quality too low (${features.faceQualityScore} < $minQuality)");
      return false;
    }

    // Must have key landmarks
    List<String> requiredLandmarks = [
      'FaceLandmarkType.leftEye',
      'FaceLandmarkType.rightEye',
      'FaceLandmarkType.noseBase',
    ];

    // ✅ iOS-specific: Only require essential landmarks
    if (Platform.isIOS) {
      requiredLandmarks = [
        'FaceLandmarkType.noseBase',
      ];
    }

    for (String landmark in requiredLandmarks) {
      if (!features.landmarkPositions.containsKey(landmark)) {
        debugPrint("❌ Registration failed: Missing landmark $landmark");
        return false;
      }
    }

    // ✅ iOS-specific: More lenient eye detection
    if (Platform.isIOS) {
      // For iOS, just check that we have eye probabilities
      bool hasEyeData = features.leftEyeOpenProbability != null || 
                       features.rightEyeOpenProbability != null;
      if (!hasEyeData) {
        debugPrint("❌ Registration failed: No eye data available");
        return false;
      }
    } else {
      // For Android, check eyes are clearly open
      if (!features.areEyesOpen) {
        debugPrint("❌ Registration failed: Eyes not clearly open");
        return false;
      }
    }

    debugPrint("✅ Face is valid for registration (Platform: ${Platform.isIOS ? 'iOS' : 'Android'})");
    return true;
  }

  /// Dispose the face detector
  static void dispose() {
    _faceDetector.close();
  }
}

/// Real-time face feedback system - iOS optimized
class RealTimeFaceFeedback {
  static String getFeedbackMessage(EnhancedFaceFeatures? features,
      double screenWidth, double screenHeight) {
    if (features == null) {
      return "👤 Please position your face in the camera";
    }

    // ✅ iOS-specific: More lenient quality requirements
    double minQuality = Platform.isIOS ? 0.2 : 0.3;

    // Check distance
    if (!features.isProperDistance) {
      if ((features.faceWidth ?? 0) < screenWidth * 0.25) {
        return "📏 Move closer to the camera";
      } else {
        return "📏 Move farther from the camera";
      }
    }

    // Check centering
    if (!features.isFaceCentered) {
      double? faceCenterX = features.faceCenterX;
      if (faceCenterX != null) {
        double screenCenterX = screenWidth / 2;
        if (faceCenterX < screenCenterX - 50) {
          return "⬅️ Move your face to the right";
        } else if (faceCenterX > screenCenterX + 50) {
          return "➡️ Move your face to the left";
        }
      }
      return "🎯 Center your face in the camera";
    }

    // Check lighting/quality
    if ((features.faceQualityScore ?? 0) < minQuality) {
      return "💡 Find better lighting";
    }

    // Check eyes - more lenient for iOS
    if (Platform.isIOS) {
      // For iOS, just check that we have eye data
      bool hasEyeData = features.leftEyeOpenProbability != null || 
                       features.rightEyeOpenProbability != null;
      if (!hasEyeData) {
        return "👀 Please open your eyes";
      }
    } else {
      // For Android, check eyes are clearly open
      if (!features.areEyesOpen) {
        return "👀 Keep your eyes open";
      }
    }

    // All good!
    if (features.isGoodQuality) {
      return "✅ Perfect! Hold still...";
    }

    return "🔄 Adjusting detection...";
  }

  static Color getFeedbackColor(EnhancedFaceFeatures? features) {
    if (features == null) return Colors.red;

    // ✅ iOS-specific: More lenient quality thresholds
    double goodQuality = Platform.isIOS ? 0.4 : 0.7;
    double okQuality = Platform.isIOS ? 0.2 : 0.4;

    if ((features.faceQualityScore ?? 0) > goodQuality) {
      return Colors.green;
    } else if ((features.faceQualityScore ?? 0) > okQuality) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
