// lib/common/utils/enhanced_face_extractor.dart - SIMPLIFIED WORKING VERSION
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:phoenician_face_auth/model/enhanced_face_features.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class EnhancedFaceExtractor {
  // Create face detector with ALL options enabled for maximum data
  static final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,    // Enable smile, eye open probability
      enableLandmarks: true,         // Enable facial landmarks
      enableContours: true,          // Enable face contours
      enableTracking: true,          // Enable face tracking across frames
      minFaceSize: 0.1,             // Detect smaller faces
      performanceMode: FaceDetectorMode.accurate, // Use accurate mode
    ),
  );

  /// Extract enhanced face features from camera input
  /// Returns null if no face detected or quality too poor
  static Future<EnhancedFaceFeatures?> extractEnhancedFeatures(
      InputImage inputImage, {
        double? screenWidth,
        double? screenHeight,
        double minimumQuality = 0.5, // Minimum quality threshold
      }) async {
    try {
      debugPrint("🔍 Starting enhanced face extraction...");

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

      // Create enhanced features
      EnhancedFaceFeatures features = EnhancedFaceFeatures.fromMLKitFace(
        primaryFace,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );

      debugPrint("✅ Enhanced features extracted: $features");

      // Quality check
      if ((features.faceQualityScore ?? 0) < minimumQuality) {
        debugPrint("❌ Face quality too poor: ${features.faceQualityScore}");
        return null;
      }

      return features;

    } catch (e) {
      debugPrint("❌ Error extracting enhanced face features: $e");
      return null;
    }
  }

  /// Extract features for real-time processing (lighter version)
  static Future<EnhancedFaceFeatures?> extractForRealTime(
      InputImage inputImage, {
        double? screenWidth,
        double? screenHeight,
      }) async {
    try {
      // Use same detection but with more lenient quality requirements
      List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) return null;

      Face primaryFace = _selectBestFace(faces);

      return EnhancedFaceFeatures.fromMLKitFace(
        primaryFace,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );

    } catch (e) {
      debugPrint("Error in real-time face extraction: $e");
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

  /// Calculate a score for face selection (larger, more centered faces score higher)
  static double _calculateFaceScore(Face face) {
    double score = 0.0;

    // Prefer larger faces
    double faceSize = face.boundingBox.width * face.boundingBox.height;
    score += faceSize / 10000; // Normalize to reasonable range

    // Prefer faces looking more straight ahead
    double headYaw = (face.headEulerAngleY ?? 0).abs();
    score += (90 - headYaw) / 90; // Less yaw = higher score

    // Prefer faces with both eyes detected
    if (face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null) {
      score += 1.0;
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

  /// Check if face meets minimum requirements for registration
  static bool isValidForRegistration(EnhancedFaceFeatures features) {
    // Quality checks
    if ((features.faceQualityScore ?? 0) < 0.6) {
      debugPrint("❌ Registration failed: Quality too low");
      return false;
    }

    // Must have key landmarks
    List<String> requiredLandmarks = [
      'FaceLandmarkType.leftEye',
      'FaceLandmarkType.rightEye',
      'FaceLandmarkType.noseBase',
      'FaceLandmarkType.leftMouth',
      'FaceLandmarkType.rightMouth',
    ];

    for (String landmark in requiredLandmarks) {
      if (!features.landmarkPositions.containsKey(landmark)) {
        debugPrint("❌ Registration failed: Missing landmark $landmark");
        return false;
      }
    }

    // Eyes should be open for registration
    if (!features.areEyesOpen) {
      debugPrint("❌ Registration failed: Eyes not clearly open");
      return false;
    }

    // Face should be looking roughly straight
    if (!features.isLookingStraight) {
      debugPrint("❌ Registration failed: Face not looking straight ahead");
      return false;
    }

    debugPrint("✅ Face is valid for registration");
    return true;
  }

  /// Dispose the face detector
  static void dispose() {
    _faceDetector.close();
  }
}

/// Real-time face feedback system
class RealTimeFaceFeedback {
  static String getFeedbackMessage(EnhancedFaceFeatures? features,
      double screenWidth, double screenHeight) {
    if (features == null) {
      return "👤 Please position your face in the camera";
    }

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

    // Check head pose
    if (!features.isLookingStraight) {
      double headYaw = features.headEulerAngleY ?? 0;
      if (headYaw > 15) {
        return "↩️ Turn your head slightly to the right";
      } else if (headYaw < -15) {
        return "↪️ Turn your head slightly to the left";
      }
    }

    // Check lighting/quality
    if (!features.hasGoodLighting) {
      return "💡 Find better lighting";
    }

    // Check eyes
    if (!features.areEyesOpen) {
      return "👀 Keep your eyes open";
    }

    // All good!
    if (features.isGoodQuality) {
      return "✅ Perfect! Hold still...";
    }

    return "🔄 Adjusting detection...";
  }

  static Color getFeedbackColor(EnhancedFaceFeatures? features) {
    if (features == null) return Colors.red;

    if (features.isGoodQuality) {
      return Colors.green;
    } else if ((features.faceQualityScore ?? 0) > 0.4) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
