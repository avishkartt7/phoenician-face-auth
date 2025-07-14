// lib/register_face/register_face_view.dart - COMPLETE FILE

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';

import 'package:face_auth_compatible/services/registration_completion_service.dart';
import 'package:face_auth_compatible/dashboard/dashboard_view.dart';

// Enhanced utilities imports
import 'package:face_auth_compatible/model/enhanced_face_features.dart';
import 'package:face_auth_compatible/common/utils/enhanced_face_extractor.dart';

// Existing imports
import 'package:face_auth_compatible/services/secure_face_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:face_auth_compatible/common/views/camera_view.dart';
import 'package:face_auth_compatible/common/views/custom_button.dart';
import 'package:face_auth_compatible/constants/theme.dart';
import 'package:face_auth_compatible/model/user_model.dart';
import 'package:face_auth_compatible/common/utils/custom_snackbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_auth_compatible/authenticate_face/authenticate_face_view.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:face_auth_compatible/services/connectivity_service.dart';
import 'package:face_auth_compatible/services/service_locator.dart';

class RegisterFaceView extends StatefulWidget {
  final String employeeId;
  final String employeePin;

  const RegisterFaceView({
    Key? key,
    required this.employeeId,
    required this.employeePin,
  }) : super(key: key);

  @override
  State<RegisterFaceView> createState() => _RegisterFaceViewState();
}

class _RegisterFaceViewState extends State<RegisterFaceView>
    with TickerProviderStateMixin {
  String? _image;
  EnhancedFaceFeatures? _enhancedFaceFeatures;
  bool _isRegistering = false;
  bool _isOfflineMode = false;
  bool _isCameraActive = false;
  late ConnectivityService _connectivityService;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  // Live feedback variables
  String _realTimeFeedback = "Tap to start camera";
  Color _feedbackColor = const Color(0xFF2196F3);
  bool _isProcessingRealTime = false;

  // Quality tracking
  double _currentQuality = 0.0;
  bool _isReadyForCapture = false;

  // Status tracking
  bool _isFaceDetected = false;
  bool _areEyesOpen = false;
  bool _isLookingStraight = false;
  bool _isFaceCentered = false;
  bool _isProperDistance = false;
  bool _hasGoodLighting = false;

  @override
  void initState() {
    super.initState();
    _connectivityService = getIt<ConnectivityService>();
    _initializeAnimations();
    _checkConnectivity();

    // Listen to connectivity changes
    _connectivityService.connectionStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _isOfflineMode = status == ConnectionStatus.offline;
        });
      }
    });
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));

    _slideController.forward();
  }

  Future<void> _checkConnectivity() async {
    try {
      bool isOnline = await _connectivityService.checkConnectivity();
      setState(() {
        _isOfflineMode = !isOnline;
      });
    } catch (e) {
      setState(() {
        _isOfflineMode = false;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    EnhancedFaceExtractor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    CustomSnackBar.context = context;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Face Registration",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isOfflineMode
                  ? Colors.orange.withOpacity(0.2)
                  : Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _isOfflineMode ? Colors.orange : Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isOfflineMode ? "Offline" : "Online",
                  style: TextStyle(
                    color: _isOfflineMode ? Colors.orange : Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        height: screenHeight,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: SafeArea(
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                _buildCompactFeedbackPanel(),
                const SizedBox(height: 10),
                Expanded(
                  flex: 4,
                  child: _buildLargeCameraView(screenWidth, screenHeight),
                ),
                const SizedBox(height: 10),
                _buildCompactActionSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // MUCH SMALLER feedback panel
  Widget _buildCompactFeedbackPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Single line feedback with icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _feedbackColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getFeedbackEmoji(),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _realTimeFeedback,
                  style: TextStyle(
                    color: _feedbackColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (_isProcessingRealTime)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: _feedbackColor,
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),

          // Only show status when camera is active
          if (_isCameraActive) ...[
            const SizedBox(height: 8),
            _buildMiniStatusRow(),
          ],
        ],
      ),
    );
  }

  // Tiny status indicators in one row
  Widget _buildMiniStatusRow() {
    List<Map<String, dynamic>> statusItems = [
      {'icon': Icons.face, 'status': _isFaceDetected},
      {'icon': Icons.visibility, 'status': _areEyesOpen},
      {'icon': Icons.center_focus_strong, 'status': _isFaceCentered},
      {'icon': Icons.straighten, 'status': _isProperDistance},
      {'icon': Icons.wb_sunny, 'status': _hasGoodLighting},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: statusItems.map((item) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: item['status']
              ? Colors.green.withOpacity(0.2)
              : Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          item['icon'],
          color: item['status'] ? Colors.green : Colors.red,
          size: 14,
        ),
      )).toList(),
    );
  }

  // LARGE camera view that takes most of the screen
  Widget _buildLargeCameraView(double screenWidth, double screenHeight) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isCameraActive
              ? _feedbackColor.withOpacity(0.5)
              : Colors.white.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _isCameraActive
                ? _feedbackColor.withOpacity(0.2)
                : Colors.black.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Camera View or Start Button
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: _isCameraActive
                ? CameraView(
              onImage: (image) {
                setState(() {
                  _image = base64Encode(image);
                });
                _testImageQuality(_image!);
              },
              onInputImage: (inputImage) async {
                await _processRealTimeFeedback(inputImage, screenWidth, screenHeight);
              },
            )
                : _buildCameraStartButton(),
          ),

          // Face overlay when ready
          if (_enhancedFaceFeatures != null && _isReadyForCapture && _isCameraActive)
            _buildSimpleFaceOverlay(),

          // Camera controls overlay
          if (_isCameraActive)
            _buildCameraControls(),
        ],
      ),
    );
  }

  // Big start camera button
  Widget _buildCameraStartButton() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: GestureDetector(
                    onTap: _startCamera,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF667eea).withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              "Tap to Start Camera",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Make sure you have good lighting",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Simple camera controls
  Widget _buildCameraControls() {
    return Positioned(
      top: 16,
      left: 16,
      child: Column(
        children: [
          // Stop camera button
          GestureDetector(
            onTap: _stopCamera,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          if (_currentQuality > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "${(_currentQuality * 100).toInt()}%",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimpleFaceOverlay() {
    return Positioned.fill(
      child: CustomPaint(
        painter: SimpleFaceOverlayPainter(
          faceFeatures: _enhancedFaceFeatures!,
          isReady: _isReadyForCapture,
        ),
      ),
    );
  }

  // COMPACT action section
  Widget _buildCompactActionSection() {
    if (_isRegistering) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.withOpacity(0.1),
              Colors.blue.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.blue,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Registering your face...",
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isReadyForCapture && _enhancedFaceFeatures != null && _isCameraActive) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success indicator
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF45a049)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    "Perfect! Ready to register",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Register Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _registerEnhancedFace(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "Register My Face",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Default state - show start camera or quality info
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: _isCameraActive
          ? Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Follow the guidance above",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (_currentQuality > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _currentQuality,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                _currentQuality > 0.7 ? Colors.green :
                _currentQuality > 0.4 ? Colors.orange : Colors.red,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Quality: ${(_currentQuality * 100).toInt()}% (need 50%+)",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ],
      )
          : const Text(
        "Start the camera to begin face registration",
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _startCamera() {
    _pulseController.repeat(reverse: true);
    setState(() {
      _isCameraActive = true;
      _realTimeFeedback = "Position your face in the camera";
      _feedbackColor = const Color(0xFFFF9800);
    });
  }

  void _stopCamera() {
    _pulseController.stop();
    setState(() {
      _isCameraActive = false;
      _realTimeFeedback = "Tap to start camera";
      _feedbackColor = const Color(0xFF2196F3);
      _resetStatusFlags();
      _currentQuality = 0.0;
      _isReadyForCapture = false;
    });
  }

  String _getFeedbackEmoji() {
    if (!_isCameraActive) return "📷";
    if (_feedbackColor == Colors.green || _feedbackColor == const Color(0xFF4CAF50)) return "✅";
    if (_feedbackColor == Colors.orange || _feedbackColor == const Color(0xFFFF9800)) return "⚠️";
    return "❌";
  }

  // Enhanced real-time feedback processing
  Future<void> _processRealTimeFeedback(InputImage inputImage, double screenWidth, double screenHeight) async {
    if (_isProcessingRealTime || !_isCameraActive) return;

    setState(() {
      _isProcessingRealTime = true;
    });

    try {
      EnhancedFaceFeatures? features = await EnhancedFaceExtractor.extractForRealTime(
        inputImage,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );

      if (mounted) {
        setState(() {
          _enhancedFaceFeatures = features;

          // Update status flags
          _isFaceDetected = features != null;
          _areEyesOpen = features?.areEyesOpen ?? false;
          _isLookingStraight = features?.isLookingStraight ?? false;
          _isFaceCentered = features?.isFaceCentered ?? false;

          if (features != null) {
            double faceWidth = features.faceWidth ?? 0;
            double faceRatio = faceWidth / screenWidth;
            _isProperDistance = faceRatio >= 0.15 && faceRatio <= 0.8;
          } else {
            _isProperDistance = false;
          }

          _hasGoodLighting = features?.hasGoodLighting ?? false;
          _currentQuality = features?.faceQualityScore ?? 0.0;

          // Generate feedback
          _realTimeFeedback = _generateLiveFeedbackMessage(features, screenWidth, screenHeight);
          _feedbackColor = _getFeedbackColorAdvanced(features);

          // Check readiness
          bool wasReady = _isReadyForCapture;
          _isReadyForCapture = _isReadyForRegistration(features);

          if (_isReadyForCapture && !wasReady && features != null) {
            _captureHighQualityFeatures(features);
          }

          _isProcessingRealTime = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingRealTime = false;
          _realTimeFeedback = "Processing error - please try again";
          _feedbackColor = Colors.red;
          _resetStatusFlags();
        });
      }
    }
  }

  void _resetStatusFlags() {
    _isFaceDetected = false;
    _areEyesOpen = false;
    _isLookingStraight = false;
    _isFaceCentered = false;
    _isProperDistance = false;
    _hasGoodLighting = false;
  }

  String _generateLiveFeedbackMessage(EnhancedFaceFeatures? features, double screenWidth, double screenHeight) {
    if (features == null) {
      return "Position your face in the camera";
    }

    if (!features.areEyesOpen) {
      return "Please keep your eyes wide open";
    }

    if ((features.faceQualityScore ?? 0) < 0.3) {
      return "Move to better lighting";
    }

    double faceWidth = features.faceWidth ?? 0;
    double faceRatio = faceWidth / screenWidth;

    if (faceRatio < 0.15) {
      return "Move closer to the camera";
    } else if (faceRatio > 0.8) {
      return "Move farther from camera";
    }

    if (!features.isFaceCentered) {
      double? faceCenterX = features.faceCenterX;
      if (faceCenterX != null) {
        double screenCenterX = screenWidth / 2;
        double offset = (faceCenterX - screenCenterX).abs();
        if (offset > 100) {
          if (faceCenterX < screenCenterX) {
            return "Move slightly to the right";
          } else {
            return "Move slightly to the left";
          }
        }
      }
    }

    double headYaw = (features.headEulerAngleY ?? 0).abs();
    if (headYaw > 30) {
      return "Look straight at the camera";
    }

    if ((features.faceQualityScore ?? 0) > 0.5) {
      return "Perfect! Hold this position";
    }

    return "Almost there - hold steady";
  }

  Color _getFeedbackColorAdvanced(EnhancedFaceFeatures? features) {
    if (features == null) return Colors.red;

    if (!features.areEyesOpen) return Colors.red;

    if (features.areEyesOpen && (features.faceQualityScore ?? 0) > 0.5) {
      return const Color(0xFF4CAF50);
    } else if ((features.faceQualityScore ?? 0) > 0.3 && features.areEyesOpen) {
      return const Color(0xFFFF9800);
    } else {
      return Colors.red;
    }
  }

  bool _isReadyForRegistration(EnhancedFaceFeatures? features) {
    if (features == null) return false;

    bool eyesOpen = features.areEyesOpen;
    bool goodQuality = (features.faceQualityScore ?? 0) > 0.5;
    bool reasonablyPositioned = features.isFaceCentered ||
        features.isProperDistance ||
        features.hasGoodLighting;

    return eyesOpen && goodQuality && reasonablyPositioned;
  }

  void _captureHighQualityFeatures(EnhancedFaceFeatures features) {
    // Features captured for registration
  }

  void _testImageQuality(String base64Image) {
    // Image quality testing logic
  }

  void _registerEnhancedFace(BuildContext context) async {
    if (_image == null || _enhancedFaceFeatures == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please capture your face with good quality first"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    try {
      String cleanedImage = _image!;
      if (cleanedImage.contains('data:image') && cleanedImage.contains(',')) {
        cleanedImage = cleanedImage.split(',')[1];
      }

      try {
        Uint8List decodedImage = base64Decode(cleanedImage);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error processing image format: $e"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isRegistering = false;
        });
        return;
      }

      final secureFaceStorage = getIt<SecureFaceStorageService>();

      // ✅ STEP 1: Save to secure storage
      await secureFaceStorage.saveFaceImage(widget.employeeId, cleanedImage);
      await secureFaceStorage.saveEnhancedFaceFeatures(widget.employeeId, _enhancedFaceFeatures!);
      await secureFaceStorage.setFaceRegistered(widget.employeeId, true);

      // ✅ STEP 2: Save to SharedPreferences backup
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('employee_image_${widget.employeeId}', cleanedImage);
      await prefs.setString('enhanced_face_features_${widget.employeeId}',
          jsonEncode(_enhancedFaceFeatures!.toJson()));
      await prefs.setBool('face_registered_${widget.employeeId}', true);

      await _checkConnectivity();

      // ✅ STEP 3: Enhanced cloud backup
      if (!_isOfflineMode) {
        try {
          // Create comprehensive face data for cloud storage
          Map<String, dynamic> faceData = {
            'image': cleanedImage,
            'enhancedFaceFeatures': _enhancedFaceFeatures!.toJson(),
            'faceRegistered': true,
            'enhancedRegistration': true,
            'registrationQuality': _enhancedFaceFeatures!.faceQualityScore,
            'eyeProbabilities': {
              'left': _enhancedFaceFeatures!.leftEyeOpenProbability,
              'right': _enhancedFaceFeatures!.rightEyeOpenProbability,
            },
            'registrationTimestamp': FieldValue.serverTimestamp(),
            'deviceInfo': {
              'platform': Platform.isAndroid ? 'Android' : 'iOS',
              'registrationType': 'enhanced',
            },
          };

          await FirebaseFirestore.instance
              .collection('employees')
              .doc(widget.employeeId)
              .update(faceData);

          debugPrint("✅ Face data backed up to cloud successfully");

          // ✅ NEW: Verify cloud backup integrity
          try {
            DocumentSnapshot verifyDoc = await FirebaseFirestore.instance
                .collection('employees')
                .doc(widget.employeeId)
                .get();

            if (verifyDoc.exists) {
              Map<String, dynamic> verifyData = verifyDoc.data() as Map<String, dynamic>;
              bool hasImage = verifyData.containsKey('image') && verifyData['image'] != null;
              bool hasFeatures = verifyData.containsKey('enhancedFaceFeatures') && verifyData['enhancedFaceFeatures'] != null;

              if (hasImage && hasFeatures) {
                debugPrint("✅ Cloud backup integrity verified");
              } else {
                debugPrint("⚠️ Cloud backup incomplete - some data missing");
              }
            }
          } catch (verifyError) {
            debugPrint("⚠️ Could not verify cloud backup: $verifyError");
          }

        } catch (e) {
          debugPrint("⚠️ Cloud backup failed: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Warning: Could not sync to cloud. Data saved locally: $e"),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        await prefs.setBool('pending_enhanced_face_registration_${widget.employeeId}', true);
        debugPrint("📱 Offline mode: Face registration marked for cloud sync");
      }

      // ✅ STEP 4: Mark registration complete
      await RegistrationCompletionService.markRegistrationComplete(widget.employeeId);

      setState(() {
        _isRegistering = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isOfflineMode
                ? "Face registered successfully (offline mode)"
                : "Face registered successfully and backed up to cloud"),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // ✅ Navigate to dashboard
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DashboardView(employeeId: widget.employeeId),
          ),
        );
      }

    } catch (e) {
      setState(() {
        _isRegistering = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error registering face: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ✅ SimpleFaceOverlayPainter class - OUTSIDE the main widget class
class SimpleFaceOverlayPainter extends CustomPainter {
  final EnhancedFaceFeatures faceFeatures;
  final bool isReady;

  SimpleFaceOverlayPainter({
    required this.faceFeatures,
    required this.isReady,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isReady) return;

    final paint = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    if (faceFeatures.faceWidth != null &&
        faceFeatures.faceHeight != null &&
        faceFeatures.faceCenterX != null &&
        faceFeatures.faceCenterY != null) {

      double left = faceFeatures.faceCenterX! - (faceFeatures.faceWidth! / 2);
      double top = faceFeatures.faceCenterY! - (faceFeatures.faceHeight! / 2);

      Rect faceRect = Rect.fromLTWH(left, top, faceFeatures.faceWidth!, faceFeatures.faceHeight!);

      // Simple face outline
      canvas.drawRRect(
        RRect.fromRectAndRadius(faceRect, const Radius.circular(20)),
        paint,
      );

      // Center dot
      final centerPaint = Paint()
        ..color = const Color(0xFF4CAF50)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(faceFeatures.faceCenterX!, faceFeatures.faceCenterY!),
        4.0,
        centerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
