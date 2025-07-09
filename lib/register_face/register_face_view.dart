// lib/register_face/register_face_view.dart - iOS COMPATIBLE VERSION

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';

import 'package:phoenician_face_auth/services/registration_completion_service.dart';
import 'package:phoenician_face_auth/dashboard/dashboard_view.dart';

// Enhanced utilities imports
import 'package:phoenician_face_auth/model/enhanced_face_features.dart';
import 'package:phoenician_face_auth/common/utils/enhanced_face_extractor.dart';

// Existing imports
import 'package:phoenician_face_auth/services/secure_face_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phoenician_face_auth/common/views/camera_view.dart';
import 'package:phoenician_face_auth/common/views/custom_button.dart';
import 'package:phoenician_face_auth/constants/theme.dart';
import 'package:phoenician_face_auth/model/user_model.dart';
import 'package:phoenician_face_auth/common/utils/custom_snackbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phoenician_face_auth/authenticate_face/authenticate_face_view.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:phoenician_face_auth/services/connectivity_service.dart';
import 'package:phoenician_face_auth/services/service_locator.dart';

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

    // ✅ iOS-specific: Log platform info
    debugPrint("📱 Platform: ${Platform.isIOS ? 'iOS' : 'Android'}");
    debugPrint("🔧 Face registration initialized for: ${widget.employeeId}");
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
        title: Text(
          "Face Registration ${Platform.isIOS ? '(iOS)' : '(Android)'}",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
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
                
                // ✅ iOS Debug Info
                if (Platform.isIOS) _buildiOSDebugInfo(),
                
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

  // ✅ iOS-specific debug info
  Widget _buildiOSDebugInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            "iOS Debug Info",
            style: TextStyle(
              color: Colors.blue,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Quality: ${_currentQuality.toStringAsFixed(2)} | "
            "Ready: $_isReadyForCapture | "
            "Features: ${_enhancedFaceFeatures != null}",
            style: TextStyle(
              color: Colors.blue,
              fontSize: 8,
            ),
          ),
        ],
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
                debugPrint("📸 Image captured: ${image.length} bytes");
                setState(() {
                  _image = base64Encode(image);
                });
                _testImageQuality(_image!);
              },
              onInputImage: (inputImage) async {
                debugPrint("🔍 Processing input image for face detection...");
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
            Text(
              Platform.isIOS ? "Tap to Start Camera (iOS)" : "Tap to Start Camera",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              Platform.isIOS 
                  ? "iOS: Ensure good lighting and steady hands"
                  : "Make sure you have good lighting",
              style: const TextStyle(
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
            Expanded(
              child: Text(
                Platform.isIOS 
                    ? "Registering your face (iOS)..."
                    : "Registering your face...",
                style: const TextStyle(
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

    // ✅ iOS-specific: Show register button more easily
    bool canRegister = _canRegisterFace();
    
    if (canRegister && _isCameraActive) {
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
                  Text(
                    Platform.isIOS 
                        ? "iOS: Ready to register!"
                        : "Perfect! Ready to register",
                    style: const TextStyle(
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
                child: Text(
                  Platform.isIOS 
                      ? "Register Face (iOS)"
                      : "Register My Face",
                  style: const TextStyle(
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
            Platform.isIOS 
                ? "iOS: Follow the guidance above"
                : "Follow the guidance above",
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
              Platform.isIOS 
                  ? "iOS Quality: ${(_currentQuality * 100).toInt()}% (need 30%+)"
                  : "Quality: ${(_currentQuality * 100).toInt()}% (need 50%+)",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ],
      )
          : Text(
        Platform.isIOS 
            ? "iOS: Start the camera to begin face registration"
            : "Start the camera to begin face registration",
        style: const TextStyle(
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

  // ✅ iOS-specific: More lenient registration check
  bool _canRegisterFace() {
    // Basic requirements
    if (_image == null) return false;
    if (!_isCameraActive) return false;
    
    // iOS-specific: More lenient requirements
    if (Platform.isIOS) {
      // For iOS, just check that we have some face features and basic quality
      bool hasFeatures = _enhancedFaceFeatures != null;
      bool hasMinQuality = _currentQuality > 0.25; // Very low threshold for iOS
      
      debugPrint("🍎 iOS Registration Check:");
      debugPrint("   Has Features: $hasFeatures");
      debugPrint("   Quality: $_currentQuality (need >0.25)");
      debugPrint("   Can Register: ${hasFeatures && hasMinQuality}");
      
      return hasFeatures && hasMinQuality;
    } else {
      // For Android, use the original stricter requirements
      return _isReadyForCapture && _enhancedFaceFeatures != null;
    }
  }

  // Enhanced real-time feedback processing
  Future<void> _processRealTimeFeedback(InputImage inputImage, double screenWidth, double screenHeight) async {
    if (_isProcessingRealTime || !_isCameraActive) return;

    setState(() {
      _isProcessingRealTime = true;
    });

    try {
      debugPrint("🔍 Processing real-time feedback...");
      
      EnhancedFaceFeatures? features = await EnhancedFaceExtractor.extractForRealTime(
        inputImage,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );

      debugPrint("📊 Face features extracted: ${features != null}");
      if (features != null) {
        debugPrint("📊 Quality: ${features.faceQualityScore}");
        debugPrint("📊 Eyes open: ${features.areEyesOpen}");
      }

      if (mounted) {
        setState(() {
          _enhancedFaceFeatures = features;

          // Update status flags
          _isFaceDetected = features != null;
          
          // ✅ iOS-specific: More lenient eye detection
          if (Platform.isIOS) {
            _areEyesOpen = features?.leftEyeOpenProbability != null || 
                          features?.rightEyeOpenProbability != null;
          } else {
            _areEyesOpen = features?.areEyesOpen ?? false;
          }
          
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

          // Check readiness - iOS specific
          bool wasReady = _isReadyForCapture;
          _isReadyForCapture = _isReadyForRegistration(features);

          if (_isReadyForCapture && !wasReady && features != null) {
            _captureHighQualityFeatures(features);
          }

          _isProcessingRealTime = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error in real-time processing: $e");
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

    // ✅ iOS-specific: More lenient quality requirements
    double minQuality = Platform.isIOS ? 0.2 : 0.3;

    // For iOS, be more encouraging
    if (Platform.isIOS) {
      if ((features.faceQualityScore ?? 0) > 0.3) {
        return "✅ Great! iOS face detected";
      } else if ((features.faceQualityScore ?? 0) > 0.15) {
        return "🔄 iOS: Almost ready...";
      }
    }

    // Use existing logic for detailed feedback
    if ((features.faceQualityScore ?? 0) < minQuality) {
      return "Move to better lighting";
    }

    if ((features.faceQualityScore ?? 0) > 0.4) {
      return "Perfect! Hold this position";
    }

    return "Almost there - hold steady";
  }

  Color _getFeedbackColorAdvanced(EnhancedFaceFeatures? features) {
    if (features == null) return Colors.red;

    // ✅ iOS-specific: More lenient color coding
    if (Platform.isIOS) {
      if ((features.faceQualityScore ?? 0) > 0.25) {
        return const Color(0xFF4CAF50);
      } else if ((features.faceQualityScore ?? 0) > 0.1) {
        return const Color(0xFFFF9800);
      } else {
        return Colors.red;
      }
    }

    // Original Android logic
    if ((features.faceQualityScore ?? 0) > 0.5) {
      return const Color(0xFF4CAF50);
    } else if ((features.faceQualityScore ?? 0) > 0.3) {
      return const Color(0xFFFF9800);
    } else {
      return Colors.red;
    }
  }

  bool _isReadyForRegistration(EnhancedFaceFeatures? features) {
    if (features == null) return false;

    // ✅ iOS-specific: Much more lenient requirements
    if (Platform.isIOS) {
      bool hasMinQuality = (features.faceQualityScore ?? 0) > 0.25;
      bool hasEyeData = features.leftEyeOpenProbability != null || 
                       features.rightEyeOpenProbability != null;
      
      return hasMinQuality && hasEyeData;
    }

    // Original Android logic
    bool eyesOpen = features.areEyesOpen;
    bool goodQuality = (features.faceQualityScore ?? 0) > 0.5;
    bool reasonablyPositioned = features.isFaceCentered ||
        features.isProperDistance ||
        features.hasGoodLighting;

    return eyesOpen && goodQuality && reasonablyPositioned;
  }

  void _captureHighQualityFeatures(EnhancedFaceFeatures features) {
    // Features captured for registration
    debugPrint("📸 High quality features captured for registration");
  }

  void _testImageQuality(String base64Image) {
    // Image quality testing logic
    debugPrint("🧪 Testing image quality: ${base64Image.length} chars");
  }

  void _registerEnhancedFace(BuildContext context) async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Platform.isIOS 
              ? "iOS: Please capture your face first"
              : "Please capture your face with good quality first"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // ✅ iOS-specific: More lenient feature requirements
    if (Platform.isIOS) {
      // For iOS, just check that we have some face features
      if (_enhancedFaceFeatures == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("iOS: No face features detected. Please try again."),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    } else {
      // For Android, use stricter requirements
      if (_enhancedFaceFeatures == null || !_isReadyForCapture) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please capture your face with good quality first"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
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
        debugPrint("✅ Image decoded successfully: ${decodedImage.length} bytes");
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
              'platform': Platform.isIOS ? 'iOS' : 'Android',
              'registrationType': 'enhanced',
            },
          };

          await FirebaseFirestore.instance
              .collection('employees')
              .doc(widget.employeeId)
              .update(faceData);

          debugPrint("✅ Face data backed up to cloud successfully");
        } catch (e) {
          debugPrint("⚠️ Cloud backup failed: $e");
        }
      }

      // ✅ STEP 4: Mark registration complete
      await RegistrationCompletionService.markRegistrationComplete(widget.employeeId);

      setState(() {
        _isRegistering = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Platform.isIOS 
                ? "iOS: Face registered successfully!"
                : "Face registered successfully!"),
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
