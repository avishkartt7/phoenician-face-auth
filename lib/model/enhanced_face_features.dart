// lib/model/enhanced_face_features.dart - SIMPLIFIED WORKING VERSION
import 'dart:convert';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class EnhancedFaceFeatures {
  // Head pose information (CRITICAL for liveness detection)
  final double? headEulerAngleX; // Nod up/down (-90 to +90)
  final double? headEulerAngleY; // Shake left/right (-90 to +90)
  final double? headEulerAngleZ; // Tilt left/right (-180 to +180)

  // Eye state information (ESSENTIAL for blink detection)
  final double? leftEyeOpenProbability;  // 0.0 = closed, 1.0 = open
  final double? rightEyeOpenProbability; // 0.0 = closed, 1.0 = open
  final double? smilingProbability;      // 0.0 = not smiling, 1.0 = smiling

  // Face bounds and tracking
  final double? faceWidth;
  final double? faceHeight;
  final double? faceCenterX;
  final double? faceCenterY;
  final int? trackingId; // Same face across frames

  // Simplified landmark storage (key positions as points)
  final Map<String, Map<String, double>> landmarkPositions;

  // Quality metrics
  final double? faceQualityScore; // Our custom quality assessment
  final bool hasGoodLighting;
  final bool isFaceCentered;
  final bool isProperDistance;

  EnhancedFaceFeatures({
    this.headEulerAngleX,
    this.headEulerAngleY,
    this.headEulerAngleZ,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    this.smilingProbability,
    this.faceWidth,
    this.faceHeight,
    this.faceCenterX,
    this.faceCenterY,
    this.trackingId,
    required this.landmarkPositions,
    this.faceQualityScore,
    this.hasGoodLighting = false,
    this.isFaceCentered = false,
    this.isProperDistance = false,
  });

  // Create from ML Kit Face object (SIMPLIFIED VERSION)
  factory EnhancedFaceFeatures.fromMLKitFace(Face face, {
    double? screenWidth,
    double? screenHeight,
  }) {
    // Calculate quality metrics
    final faceRect = face.boundingBox;
    final faceWidth = faceRect.width;
    final faceHeight = faceRect.height;
    final faceCenterX = faceRect.center.dx;
    final faceCenterY = faceRect.center.dy;

    // Quality assessments
    bool hasGoodLighting = _assessLighting(face);
    bool isFaceCentered = _assessCentering(faceCenterX, faceCenterY, screenWidth, screenHeight);
    bool isProperDistance = _assessDistance(faceWidth, faceHeight, screenWidth, screenHeight);
    double qualityScore = _calculateQualityScore(face, hasGoodLighting, isFaceCentered, isProperDistance);

    // Extract landmark positions (SIMPLIFIED - convert to simple map)
    Map<String, Map<String, double>> landmarkPositions = {};
    face.landmarks.forEach((type, landmark) {
      if (landmark != null) {
        landmarkPositions[type.toString()] = {
          'x': landmark.position.x.toDouble(),
          'y': landmark.position.y.toDouble(),
        };
      }
    });

    return EnhancedFaceFeatures(
      headEulerAngleX: face.headEulerAngleX,
      headEulerAngleY: face.headEulerAngleY,
      headEulerAngleZ: face.headEulerAngleZ,
      leftEyeOpenProbability: face.leftEyeOpenProbability,
      rightEyeOpenProbability: face.rightEyeOpenProbability,
      smilingProbability: face.smilingProbability,
      faceWidth: faceWidth,
      faceHeight: faceHeight,
      faceCenterX: faceCenterX,
      faceCenterY: faceCenterY,
      trackingId: face.trackingId,
      landmarkPositions: landmarkPositions,
      faceQualityScore: qualityScore,
      hasGoodLighting: hasGoodLighting,
      isFaceCentered: isFaceCentered,
      isProperDistance: isProperDistance,
    );
  }

  // Quality assessment methods
  static bool _assessLighting(Face face) {
    // Basic lighting assessment based on eye detection confidence
    return (face.leftEyeOpenProbability ?? -1) >= 0 &&
        (face.rightEyeOpenProbability ?? -1) >= 0;
  }

  static bool _assessCentering(double? faceCenterX, double? faceCenterY,
      double? screenWidth, double? screenHeight) {
    if (faceCenterX == null || faceCenterY == null ||
        screenWidth == null || screenHeight == null) return false;

    double screenCenterX = screenWidth / 2;
    double screenCenterY = screenHeight / 2;

    // Face should be within 20% of screen center
    double toleranceX = screenWidth * 0.2;
    double toleranceY = screenHeight * 0.2;

    return (faceCenterX - screenCenterX).abs() < toleranceX &&
        (faceCenterY - screenCenterY).abs() < toleranceY;
  }

  static bool _assessDistance(double? faceWidth, double? faceHeight,
      double? screenWidth, double? screenHeight) {
    if (faceWidth == null || faceHeight == null ||
        screenWidth == null || screenHeight == null) return false;

    // Face should occupy 25-60% of screen width for optimal detection
    double faceToScreenRatio = faceWidth / screenWidth;
    return faceToScreenRatio >= 0.25 && faceToScreenRatio <= 0.6;
  }

  static double _calculateQualityScore(Face face, bool hasGoodLighting,
      bool isFaceCentered, bool isProperDistance) {
    double score = 0.0;

    // Each factor contributes to quality score
    if (hasGoodLighting) score += 0.3;
    if (isFaceCentered) score += 0.2;
    if (isProperDistance) score += 0.2;

    // Eye detection confidence
    if ((face.leftEyeOpenProbability ?? 0) > 0.3) score += 0.1;
    if ((face.rightEyeOpenProbability ?? 0) > 0.3) score += 0.1;

    // Head pose (straight ahead is better)
    double headYaw = (face.headEulerAngleY ?? 0).abs();
    if (headYaw < 15) score += 0.1; // Face looking straight

    return score.clamp(0.0, 1.0);
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'headEulerAngleX': headEulerAngleX,
      'headEulerAngleY': headEulerAngleY,
      'headEulerAngleZ': headEulerAngleZ,
      'leftEyeOpenProbability': leftEyeOpenProbability,
      'rightEyeOpenProbability': rightEyeOpenProbability,
      'smilingProbability': smilingProbability,
      'faceWidth': faceWidth,
      'faceHeight': faceHeight,
      'faceCenterX': faceCenterX,
      'faceCenterY': faceCenterY,
      'trackingId': trackingId,
      'landmarkPositions': landmarkPositions,
      'faceQualityScore': faceQualityScore,
      'hasGoodLighting': hasGoodLighting,
      'isFaceCentered': isFaceCentered,
      'isProperDistance': isProperDistance,
    };
  }

  // Create from JSON
  factory EnhancedFaceFeatures.fromJson(Map<String, dynamic> json) {
    // Handle landmark positions
    Map<String, Map<String, double>> landmarkPositions = {};
    if (json['landmarkPositions'] != null) {
      final landmarks = json['landmarkPositions'] as Map<String, dynamic>;
      landmarks.forEach((key, value) {
        if (value != null && value is Map<String, dynamic>) {
          landmarkPositions[key] = {
            'x': (value['x'] ?? 0.0).toDouble(),
            'y': (value['y'] ?? 0.0).toDouble(),
          };
        }
      });
    }

    return EnhancedFaceFeatures(
      headEulerAngleX: json['headEulerAngleX']?.toDouble(),
      headEulerAngleY: json['headEulerAngleY']?.toDouble(),
      headEulerAngleZ: json['headEulerAngleZ']?.toDouble(),
      leftEyeOpenProbability: json['leftEyeOpenProbability']?.toDouble(),
      rightEyeOpenProbability: json['rightEyeOpenProbability']?.toDouble(),
      smilingProbability: json['smilingProbability']?.toDouble(),
      faceWidth: json['faceWidth']?.toDouble(),
      faceHeight: json['faceHeight']?.toDouble(),
      faceCenterX: json['faceCenterX']?.toDouble(),
      faceCenterY: json['faceCenterY']?.toDouble(),
      trackingId: json['trackingId'],
      landmarkPositions: landmarkPositions,
      faceQualityScore: json['faceQualityScore']?.toDouble(),
      hasGoodLighting: json['hasGoodLighting'] ?? false,
      isFaceCentered: json['isFaceCentered'] ?? false,
      isProperDistance: json['isProperDistance'] ?? false,
    );
  }

  // Enhanced comparison method (MUCH better than your current approach)
  double calculateSimilarityTo(EnhancedFaceFeatures other) {
    double totalScore = 0.0;
    int comparisons = 0;

    // 1. Compare head pose (important for consistency)
    if (headEulerAngleX != null && other.headEulerAngleX != null) {
      double angleDiff = (headEulerAngleX! - other.headEulerAngleX!).abs();
      totalScore += (30 - angleDiff.clamp(0, 30)) / 30; // Max 30 degree tolerance
      comparisons++;
    }

    if (headEulerAngleY != null && other.headEulerAngleY != null) {
      double angleDiff = (headEulerAngleY! - other.headEulerAngleY!).abs();
      totalScore += (30 - angleDiff.clamp(0, 30)) / 30;
      comparisons++;
    }

    // 2. Compare key landmarks with normalization for face size
    double faceScale = 1.0;
    if (faceWidth != null && other.faceWidth != null && other.faceWidth! > 0) {
      faceScale = faceWidth! / other.faceWidth!;
    }

    // Compare critical landmarks (eyes, nose, mouth)
    List<String> criticalLandmarks = [
      'FaceLandmarkType.leftEye',
      'FaceLandmarkType.rightEye',
      'FaceLandmarkType.noseBase',
      'FaceLandmarkType.leftMouth',
      'FaceLandmarkType.rightMouth',
    ];

    for (String landmarkKey in criticalLandmarks) {
      if (landmarkPositions.containsKey(landmarkKey) &&
          other.landmarkPositions.containsKey(landmarkKey)) {
        double similarity = _compareLandmarkPositions(
            landmarkPositions[landmarkKey]!,
            other.landmarkPositions[landmarkKey]!,
            faceScale
        );
        totalScore += similarity;
        comparisons++;
      }
    }

    return comparisons > 0 ? (totalScore / comparisons) : 0.0;
  }

  double _compareLandmarkPositions(Map<String, double> landmark1,
      Map<String, double> landmark2,
      double scale) {
    double dx = (landmark1['x']! - landmark2['x']! * scale).abs();
    double dy = (landmark1['y']! - landmark2['y']! * scale).abs();
    double distance = (dx * dx + dy * dy);

    // Normalize distance based on typical face size (200px width)
    double normalizedDistance = distance / (200 * 200);

    // Convert to similarity score (0-1, where 1 is perfect match)
    return (1.0 / (1.0 + normalizedDistance)).clamp(0.0, 1.0);
  }

  // Liveness detection helpers
  bool get areEyesOpen => (leftEyeOpenProbability ?? 0) > 0.5 &&
      (rightEyeOpenProbability ?? 0) > 0.5;

  bool get areEyesClosed => (leftEyeOpenProbability ?? 1) < 0.2 &&
      (rightEyeOpenProbability ?? 1) < 0.2;

  bool get isLookingStraight => (headEulerAngleY ?? 0).abs() < 15;

  bool get isLookingLeft => (headEulerAngleY ?? 0) > 20;

  bool get isLookingRight => (headEulerAngleY ?? 0) < -20;

  bool get isGoodQuality => (faceQualityScore ?? 0) > 0.7;

  // Get landmark count for display
  int get landmarkCount => landmarkPositions.length;

  @override
  String toString() {
    return 'EnhancedFaceFeatures('
        'quality: ${faceQualityScore?.toStringAsFixed(2)}, '
        'landmarks: $landmarkCount, '
        'headPose: [${headEulerAngleX?.toStringAsFixed(1)}, '
        '${headEulerAngleY?.toStringAsFixed(1)}, '
        '${headEulerAngleZ?.toStringAsFixed(1)}], '
        'eyesOpen: [${leftEyeOpenProbability?.toStringAsFixed(2)}, '
        '${rightEyeOpenProbability?.toStringAsFixed(2)}]'
        ')';
  }
}
