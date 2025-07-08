// lib/authenticate_face/authenticate_face_view.dart - ENHANCED CROSS-PLATFORM COMPATIBLE VERSION

import 'dart:convert';
import 'dart:developer';
import 'dart:math';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'package:phoenician_face_auth/services/secure_face_storage_service.dart';


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phoenician_face_auth/authenticate_face/scanning_animation/animated_view.dart';
import 'package:phoenician_face_auth/authenticate_face/user_password_setup_view.dart';
import 'package:phoenician_face_auth/authenticate_face/authentication_success_screen.dart';
import 'package:phoenician_face_auth/common/utils/custom_snackbar.dart';
import 'package:phoenician_face_auth/common/utils/extensions/size_extension.dart';
import 'package:phoenician_face_auth/common/utils/extract_face_feature.dart';
import 'package:phoenician_face_auth/common/views/camera_view.dart';
import 'package:phoenician_face_auth/common/views/custom_button.dart';
import 'package:phoenician_face_auth/constants/theme.dart';
import 'package:phoenician_face_auth/model/user_model.dart';
import 'package:phoenician_face_auth/services/connectivity_service.dart';
import 'package:phoenician_face_auth/services/service_locator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_face_api/face_api.dart' as regula;

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// Enhanced face detection imports
import 'package:phoenician_face_auth/model/enhanced_face_features.dart';
import 'package:phoenician_face_auth/common/utils/enhanced_face_extractor.dart';

/// Enhanced Face Authentication View with Cross-Platform Support
/// Provides modern UI with real-time feedback and seamless user experience
class AuthenticateFaceView extends StatefulWidget {
  final String? employeeId;
  final String? employeePin;
  final bool isRegistrationValidation;
  final Function(bool success)? onAuthenticationComplete;
  final String? actionType; // "check_in" or "check_out"

  const AuthenticateFaceView({
    Key? key,
    this.employeeId,
    this.employeePin,
    this.isRegistrationValidation = false,
    this.onAuthenticationComplete,
    this.actionType,
  }) : super(key: key);

  @override
  State<AuthenticateFaceView> createState() => _AuthenticateFaceViewState();
}

class _AuthenticateFaceViewState extends State<AuthenticateFaceView>
    with TickerProviderStateMixin {

  // ================ CORE SERVICES & CONTROLLERS ================
  
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  // Face detection variables
  FaceFeatures? _faceFeatures;
  EnhancedFaceFeatures? _enhancedFaceFeatures;
  var image1 = regula.MatchFacesImage();
  var image2 = regula.MatchFacesImage();

  // UI controllers
  final TextEditingController _pinController = TextEditingController();

  // ================ AUTHENTICATION STATE ================
  String _similarity = "0.0";
  bool _canAuthenticate = false;
  Map<String, dynamic>? employeeData;
  bool isMatching = false;
  int trialNumber = 1;
  bool _isOfflineMode = false;
  bool _offlineModeChecked = false;
  bool _isCameraActive = false;

  // Animation controllers for smooth UI transitions
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _rotateController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotateAnimation;

  // Storage and data management
  bool _hasStoredFace = false;
  String _lastAuthResult = "Not attempted";
  bool _isLoading = false;
  bool _hasAuthenticated = false;

  // ================ LIVE FEEDBACK SYSTEM ================
  String _realTimeFeedback = "Tap to start camera";
  Color _feedbackColor = const Color(0xFF2196F3);
  bool _isProcessingRealTime = false;

  // Quality and readiness tracking
  double _currentQuality = 0.0;
  bool _isReadyForCapture = false;

  // Face detection status flags
  bool _isFaceDetected = false;
  bool _areEyesOpen = false;
  bool _isLookingStraight = false;
  bool _isFaceCentered = false;
  bool _isProperDistance = false;
  bool _hasGoodLighting = false;

  // Authentication state management
  bool _isAuthenticating = false;
  DateTime? _lastAuthenticationAttempt;

  // Services
  late ConnectivityService _connectivityService;

  @override
  void initState() {
    super.initState();
    _resetAuthenticationState();
    _connectivityService = getIt<ConnectivityService>();
    _initializeAnimations();
    _checkConnectivity();
    _setupConnectivityListener();
    _checkStoredImage();
    _fetchEmployeeDataIfNeeded();
  }

  // ================ INITIALIZATION METHODS ================

  /// Initialize smooth animations for better user experience
  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));

    _rotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.easeInOut),
    );

    _slideController.forward();
  }

  /// Reset all authentication-related state variables
  void _resetAuthenticationState() {
    _hasAuthenticated = false;
    _similarity = "0.0";
    _lastAuthResult = "Not attempted";
    _faceFeatures = null;
    _enhancedFaceFeatures = null;
    isMatching = false;
    _canAuthenticate = false;
    image1 = regula.MatchFacesImage();
    image2 = regula.MatchFacesImage();
    _isAuthenticating = false;
    _lastAuthenticationAttempt = null;
    _realTimeFeedback = "Tap to start camera";
    _feedbackColor = const Color(0xFF2196F3);
    _resetStatusFlags();
  }

  /// Reset face detection status flags
  void _resetStatusFlags() {
    _isFaceDetected = false;
    _areEyesOpen = false;
    _isLookingStraight = false;
    _isFaceCentered = false;
    _isProperDistance = false;
    _hasGoodLighting = false;
  }

  /// Check if face image is stored for offline authentication
  Future<void> _checkStoredImage() async {
    try {
      if (widget.employeeId == null) return;

      final prefs = await SharedPreferences.getInstance();
      String? storedImage = prefs.getString('employee_image_${widget.employeeId}');

      setState(() {
        _hasStoredFace = storedImage != null && storedImage.isNotEmpty;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  /// Check network connectivity status
  Future<void> _checkConnectivity() async {
    bool isOnline = await _connectivityService.checkConnectivity();
    if (mounted) {
      setState(() {
        _isOfflineMode = !isOnline;
        _offlineModeChecked = true;
      });
    }
  }

  /// Setup connectivity status listener
  void _setupConnectivityListener() {
    _connectivityService.connectionStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _isOfflineMode = status == ConnectionStatus.offline;
          _offlineModeChecked = true;
        });
      }
    });
  }

  /// Fetch employee data if employee ID is provided
  void _fetchEmployeeDataIfNeeded() {
    if (widget.employeeId != null) {
      _fetchEmployeeData(widget.employeeId!);
    }
  }

  @override
  void dispose() {
    _faceDetector.close();
    // Audio player disposed (removed for compatibility)
    _pinController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  // ================ MAIN UI BUILD METHOD ================

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Set context for snackbar notifications
    CustomSnackBar.context = context;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1419), // Dark professional background
      appBar: _buildModernAppBar(),
      body: Container(
        height: screenHeight,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F1419),
              Color(0xFF1A1F2E),
              Color(0xFF0F1419),
            ],
          ),
        ),
        child: SafeArea(
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                // Status feedback panel
                _buildStatusFeedbackPanel(),

                const SizedBox(height: 16),

                // Main camera view section
                Expanded(
                  flex: 4,
                  child: _buildCameraViewSection(screenWidth, screenHeight),
                ),

                const SizedBox(height: 16),

                // Action controls section
                _buildActionControlsSection(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================ UI COMPONENT BUILDERS ================

  /// Build modern app bar with professional styling
  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        widget.isRegistrationValidation ? "Verify Your Face" : "Face Authentication",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isOfflineMode
                ? Colors.orange.withOpacity(0.2)
                : Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isOfflineMode ? Colors.orange : Colors.green,
              width: 1,
            ),
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
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build status feedback panel with real-time guidance
  Widget _buildStatusFeedbackPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: _feedbackColor.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Status icon with animated feedback
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _feedbackColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _feedbackColor.withOpacity(0.3)),
            ),
            child: _isProcessingRealTime
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: _feedbackColor,
                strokeWidth: 2,
              ),
            )
                : Icon(
              _getFeedbackIcon(),
              color: _feedbackColor,
              size: 20,
            ),
          ),

          const SizedBox(width: 16),

          // Feedback text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _realTimeFeedback,
                  style: TextStyle(
                    color: _feedbackColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),

                if (_currentQuality > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _currentQuality,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _currentQuality > 0.7 ? Colors.green :
                              _currentQuality > 0.4 ? Colors.orange : Colors.red,
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${(_currentQuality * 100).toInt()}%",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build main camera view section with professional styling
  Widget _buildCameraViewSection(double screenWidth, double screenHeight) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isCameraActive
              ? _feedbackColor.withOpacity(0.5)
              : Colors.white.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _isCameraActive
                ? _feedbackColor.withOpacity(0.2)
                : Colors.black.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Camera view or start button
            _isCameraActive
                ? CameraView(
              onImage: (image) => _setImage(image),
              onInputImage: (inputImage) async {
                await _processRealTimeFeedback(inputImage, screenWidth, screenHeight);
              },
            )
                : _buildCameraStartScreen(),

            // Camera controls overlay
            if (_isCameraActive) _buildCameraControlsOverlay(),

            // Processing overlay during authentication
            if (isMatching && _isCameraActive) _buildProcessingOverlay(),
          ],
        ),
      ),
    );
  }

  /// Build camera start screen with professional design
  Widget _buildCameraStartScreen() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.black.withOpacity(0.7),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated camera button
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: GestureDetector(
                    onTap: _startCamera,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF667eea),
                            const Color(0xFF764ba2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF667eea).withOpacity(0.4),
                            blurRadius: 25,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Instructions
            Text(
              widget.isRegistrationValidation
                  ? "Tap to Verify Your Face"
                  : "Tap to Start Authentication",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            Text(
              "Ensure good lighting and position your face clearly",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build camera controls overlay
  Widget _buildCameraControlsOverlay() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close camera button
          GestureDetector(
            onTap: _stopCamera,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),

          // Quality indicator
          if (_currentQuality > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Text(
                "Quality: ${(_currentQuality * 100).toInt()}%",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build processing overlay during authentication
  Widget _buildProcessingOverlay() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.black.withOpacity(0.8),
      ),
      child: const Center(
        child: AnimatedView(), // Your existing scanning animation
      ),
    );
  }

  /// Build action controls section
  Widget _buildActionControlsSection() {
    if (isMatching) {
      return _buildProcessingIndicator();
    }

    if (_isReadyForCapture && _enhancedFaceFeatures != null && _isCameraActive && _canAuthenticate) {
      return _buildAuthenticationButton();
    }

    return _buildInstructionsPanel();
  }

  /// Build processing indicator during authentication
  Widget _buildProcessingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Colors.blue,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            widget.isRegistrationValidation
                ? "Verifying your face..."
                : "Authenticating...",
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build authentication button when ready
  Widget _buildAuthenticationButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ready indicator
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF4CAF50), const Color(0xFF45a049)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.isRegistrationValidation
                      ? "Perfect! Ready to verify"
                      : "Perfect! Ready to authenticate",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Authentication button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _canStartAuthentication() ? _startAuthentication : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canStartAuthentication()
                    ? const Color(0xFF667eea)
                    : Colors.grey.withOpacity(0.5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: _canStartAuthentication() ? 8 : 0,
                shadowColor: const Color(0xFF667eea).withOpacity(0.4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.fingerprint_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.isRegistrationValidation ? "VERIFY FACE" : "AUTHENTICATE",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build instructions panel when not ready
  Widget _buildInstructionsPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isCameraActive
                ? "Follow the guidance above to proceed"
                : widget.isRegistrationValidation
                ? "Start the camera to verify your registered face"
                : "Start the camera to begin authentication",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),

          if (_currentQuality > 0 && _isCameraActive) ...[
            const SizedBox(height: 12),
            Text(
              "Quality: ${(_currentQuality * 100).toInt()}% (need 50%+)",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  // ================ CAMERA CONTROL METHODS ================

  /// Start camera with smooth animation
  void _startCamera() {
    _pulseController.repeat(reverse: true);
    setState(() {
      _isCameraActive = true;
      _realTimeFeedback = "Position your face in the camera";
      _feedbackColor = const Color(0xFFFF9800);
    });
  }

  /// Stop camera and reset state
  void _stopCamera() {
    _pulseController.stop();
    setState(() {
      _isCameraActive = false;
      _realTimeFeedback = "Tap to start camera";
      _feedbackColor = const Color(0xFF2196F3);
      _resetStatusFlags();
      _currentQuality = 0.0;
      _isReadyForCapture = false;
      _canAuthenticate = false;
    });
  }

  // ================ REAL-TIME FACE PROCESSING ================

  /// Process real-time feedback from camera input
  Future<void> _processRealTimeFeedback(InputImage inputImage, double screenWidth, double screenHeight) async {
    if (_isProcessingRealTime || !_isCameraActive) return;

    setState(() {
      _isProcessingRealTime = true;
    });

    try {
      _faceFeatures = await extractFaceFeatures(inputImage, _faceDetector);
      _enhancedFaceFeatures = await EnhancedFaceExtractor.extractForRealTime(
        inputImage,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );

      if (mounted) {
        setState(() {
          _updateFaceDetectionStatus();
          _updateFeedbackMessage();
          _updateReadinessState();
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
          _faceFeatures = null;
          _enhancedFaceFeatures = null;
        });
      }
    }
  }

  /// Update face detection status flags
  void _updateFaceDetectionStatus() {
    _isFaceDetected = _enhancedFaceFeatures != null;
    _areEyesOpen = _enhancedFaceFeatures?.areEyesOpen ?? false;
    _isLookingStraight = _enhancedFaceFeatures?.isLookingStraight ?? false;
    _isFaceCentered = _enhancedFaceFeatures?.isFaceCentered ?? false;

    if (_enhancedFaceFeatures != null) {
      double faceWidth = _enhancedFaceFeatures!.faceWidth ?? 0;
      double screenWidth = MediaQuery.of(context).size.width;
      double faceRatio = faceWidth / screenWidth;
      _isProperDistance = faceRatio >= 0.15 && faceRatio <= 0.8;
    } else {
      _isProperDistance = false;
    }

    _hasGoodLighting = _enhancedFaceFeatures?.hasGoodLighting ?? false;
    _currentQuality = _enhancedFaceFeatures?.faceQualityScore ?? 0.0;
  }

  /// Update real-time feedback message
  void _updateFeedbackMessage() {
    _realTimeFeedback = _generateLiveFeedbackMessage(_enhancedFaceFeatures);
    _feedbackColor = _getFeedbackColor(_enhancedFaceFeatures);
  }

  /// Update readiness state for authentication
  void _updateReadinessState() {
    bool wasReady = _isReadyForCapture;
    _isReadyForCapture = _isReadyForAuthentication(_enhancedFaceFeatures);

    if (_isReadyForCapture && !wasReady && _enhancedFaceFeatures != null) {
      _captureHighQualityFeatures(_enhancedFaceFeatures!);
    }
  }

  /// Generate live feedback message based on face analysis
  String _generateLiveFeedbackMessage(EnhancedFaceFeatures? features) {
    if (features == null) {
      return "Position your face in the camera";
    }

    if (!features.areEyesOpen) {
      return "Please keep your eyes open";
    }

    if ((features.faceQualityScore ?? 0) < 0.3) {
      return "Move to better lighting";
    }

    double faceWidth = features.faceWidth ?? 0;
    double screenWidth = MediaQuery.of(context).size.width;
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

  /// Determine readiness for authentication
  bool _isReadyForAuthentication(EnhancedFaceFeatures? features) {
    if (features == null) return false;
    bool eyesOpen = features.areEyesOpen;
    bool goodQuality = (features.faceQualityScore ?? 0) > 0.4;
    return eyesOpen && goodQuality;
  }

  /// Get feedback color based on face analysis
  Color _getFeedbackColor(EnhancedFaceFeatures? features) {
    if (features == null) return Colors.red;

    if (!features.areEyesOpen) return Colors.red;

    if (features.areEyesOpen && (features.faceQualityScore ?? 0) > 0.4) {
      return const Color(0xFF4CAF50);
    } else if ((features.faceQualityScore ?? 0) > 0.2 && features.areEyesOpen) {
      return const Color(0xFFFF9800);
    } else {
      return Colors.red;
    }
  }

  /// Get appropriate feedback icon
  IconData _getFeedbackIcon() {
    if (!_isCameraActive) return Icons.camera_alt_rounded;
    if (_feedbackColor == const Color(0xFF4CAF50)) return Icons.check_circle_rounded;
    if (_feedbackColor == const Color(0xFFFF9800)) return Icons.warning_amber_rounded;
    return Icons.error_rounded;
  }

  /// Capture high-quality features for authentication
  void _captureHighQualityFeatures(EnhancedFaceFeatures features) {
    // Features captured for authentication
  }

  // ================ IMAGE CAPTURE & AUTHENTICATION ================

  /// Set captured image for authentication
  Future<void> _setImage(Uint8List imageToAuthenticate) async {
    setState(() {
      _hasAuthenticated = false;
      _lastAuthResult = "New image captured";
      _similarity = "0.0";
    });

    image2.bitmap = base64Encode(imageToAuthenticate);
    image2.imageType = regula.ImageType.PRINTED;

    setState(() {
      _canAuthenticate = true;
    });
  }

  /// Check if authentication can be started
  bool _canStartAuthentication() {
    if (_isAuthenticating) return false;

    if (_lastAuthenticationAttempt != null) {
      final now = DateTime.now();
      final timeDiff = now.difference(_lastAuthenticationAttempt!);
      if (timeDiff.inSeconds < 2) return false;
    }

    return _isReadyForCapture && _canAuthenticate && !isMatching;
  }

  /// Start authentication process
  void _startAuthentication() async {
    if (_isAuthenticating || isMatching) {
      return;
    }

    setState(() {
      _isAuthenticating = true;
      isMatching = true;
      _hasAuthenticated = false;
      _lastAuthenticationAttempt = DateTime.now();
    });

    // Start scanning audio (removed)

    // Verify face detection
    if (_faceFeatures == null) {
      int attempts = 0;
      while (_faceFeatures == null && attempts < 20) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
    }

    bool hasFace = await _verifyFaceDetected();
    if (!hasFace) {
      // Stop audio playback (removed)
      CustomSnackBar.errorSnackBar("No face detected in camera image. Please position your face in the camera and try again.");
      setState(() {
        isMatching = false;
        _isAuthenticating = false;
      });
      return;
    }

    await _checkConnectivity();

    if (_isOfflineMode) {
      _handleOfflineAuthentication();
    } else if (widget.employeeId != null) {
      _matchFaceWithStored();
    } else {
      _promptForPin();
    }
  }

  /// Verify that face is detected in captured image
  Future<bool> _verifyFaceDetected() async {
    if (image2.bitmap == null || image2.bitmap!.isEmpty) {
      return false;
    }
    bool hasFace = _faceFeatures != null;
    return hasFace;
  }

  // ================ AUTHENTICATION METHODS ================

  /// Handle successful authentication with navigation to success screen
  void _handleSuccessfulAuthentication() {
    // Stop scanning audio and play success sound (removed)

    setState(() {
      trialNumber = 1;
      isMatching = false;
      _isAuthenticating = false;
      _hasAuthenticated = true;
    });

    // Navigate to success screen with proper employee information
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      if (widget.isRegistrationValidation) {
        // Registration validation flow
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UserPasswordSetupView(
              employeeId: widget.employeeId!,
              employeePin: widget.employeePin!,
            ),
          ),
        );
      } else {
        // Navigate to enhanced success screen with complete information
        _navigateToSuccessScreen();
      }
    });
  }

  /// Navigate to success screen with complete employee information
  void _navigateToSuccessScreen() {
    try {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => AuthenticationSuccessScreen(
              employeeName: employeeData?['name'] ?? 'User',
              employeeId: widget.employeeId ?? '',
              actionType: widget.actionType ?? 'authentication',
              similarityScore: _similarity,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        ).then((_) {
          // Success callback
        }).catchError((error) {
          _showSimpleSuccessDialog();
        });

        // Call completion callback
        if (widget.onAuthenticationComplete != null) {
          widget.onAuthenticationComplete!(true);
        }
      }
    } catch (e) {
      _showSimpleSuccessDialog();
    }
  }

  /// Show simple success dialog as fallback
  void _showSimpleSuccessDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              widget.actionType?.toLowerCase() == 'check_in'
                  ? Icons.login
                  : widget.actionType?.toLowerCase() == 'check_out'
                  ? Icons.logout
                  : Icons.check_circle,
              color: Colors.green,
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.actionType?.toLowerCase() == 'check_in'
                    ? 'Check-In Successful!'
                    : widget.actionType?.toLowerCase() == 'check_out'
                    ? 'Check-Out Successful!'
                    : 'Authentication Successful!',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.actionType?.toLowerCase() == 'check_in'
                  ? "Welcome to work, ${employeeData?['name'] ?? 'User'}!"
                  : widget.actionType?.toLowerCase() == 'check_out'
                  ? "Have a great day, ${employeeData?['name'] ?? 'User'}!"
                  : "Welcome, ${employeeData?['name'] ?? 'User'}!",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              "Time: ${DateFormat('MMM dd, yyyy - hh:mm:ss a').format(DateTime.now())}",
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
            const SizedBox(height: 4),
            Text(
              "Match: $_similarity%",
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to previous screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Continue",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (widget.onAuthenticationComplete != null) {
      widget.onAuthenticationComplete!(true);
    }
  }

  // ================ EMPLOYEE DATA MANAGEMENT ================

  /// Fetch employee data from storage or network
  Future<void> _fetchEmployeeData(String employeeId) async {
    try {
      // First try to get from local storage
      Map<String, dynamic>? localData = await _getUserDataLocally(employeeId);

      if (localData != null) {
        setState(() {
          employeeData = localData;
          _isLoading = false;
        });
      }

      // If online, try to get fresh data from Firestore
      if (!_isOfflineMode) {
        try {
          DocumentSnapshot snapshot = await FirebaseFirestore.instance
              .collection('employees')
              .doc(employeeId)
              .get()
              .timeout(const Duration(seconds: 5));

          if (snapshot.exists) {
            Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

            // Save the data locally for future offline access
            await _saveUserDataLocally(employeeId, data);

            // Also save the face image separately if it exists
            if (data.containsKey('image') && data['image'] != null) {
              await _saveEmployeeImageLocally(employeeId, data['image']);
              _checkStoredImage(); // Update stored image status
            }

            setState(() {
              employeeData = data;
            });
          } else {
            CustomSnackBar.errorSnackBar("Employee data not found");
          }
        } catch (e) {
          // Handle network error silently
        }
      }
    } catch (e) {
      Map<String, dynamic>? localData = await _getUserDataLocally(employeeId);
      if (localData != null) {
        setState(() {
          employeeData = localData;
        });
      } else {
        CustomSnackBar.errorSnackBar("Error: $e");
      }
    }
  }

  /// Save user data locally for offline access
  Future<void> _saveUserDataLocally(String userId, Map<String, dynamic> userData) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      Map<String, dynamic> dataCopy = Map<String, dynamic>.from(userData);

      dataCopy.forEach((key, value) {
        if (value is Timestamp) {
          dataCopy[key] = value.toDate().toIso8601String();
        }
      });

      await prefs.setString('user_data_$userId', jsonEncode(dataCopy));
      await prefs.setString('user_name_$userId', userData['name'] ?? 'User');
      await prefs.setString('user_designation_$userId', userData['designation'] ?? '');
      await prefs.setString('user_department_$userId', userData['department'] ?? '');

      if (userData.containsKey('image') && userData['image'] != null) {
        await prefs.setString('user_image_$userId', userData['image']);
        Map<String, dynamic> dataWithoutImage = Map<String, dynamic>.from(userData);
        dataWithoutImage.remove('image');
        await prefs.setString('user_data_no_image_$userId', jsonEncode(dataWithoutImage));
      }
    } catch (e) {
      // Handle error silently
    }
  }

  /// Get locally stored user data
  Future<Map<String, dynamic>?> _getUserDataLocally(String userId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      String? completeUserData = prefs.getString('user_data_$userId');
      if (completeUserData != null) {
        return jsonDecode(completeUserData) as Map<String, dynamic>;
      }

      String? userName = prefs.getString('user_name_$userId');
      if (userName != null) {
        Map<String, dynamic> reconstructedData = {
          'name': userName,
          'designation': prefs.getString('user_designation_$userId') ?? '',
          'department': prefs.getString('user_department_$userId') ?? '',
        };

        String? userImage = prefs.getString('user_image_$userId');
        if (userImage != null) {
          reconstructedData['image'] = userImage;
        }

        return reconstructedData;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Save employee image for offline face authentication
  Future<void> _saveEmployeeImageLocally(String employeeId, String imageBase64) async {
    try {
      String cleanedImage = imageBase64;

      if (cleanedImage.contains('data:image') && cleanedImage.contains(',')) {
        cleanedImage = cleanedImage.split(',')[1];
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('employee_image_$employeeId', cleanedImage);
      await prefs.setString('employee_image_last_updated_$employeeId', DateTime.now().toIso8601String());

      setState(() {
        _hasStoredFace = true;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  // ================ PIN AUTHENTICATION ================

  /// Prompt user for PIN when employee ID is not provided
  void _promptForPin() {
    // Stop audio playback (removed)
    setState(() {
      isMatching = false;
      _isAuthenticating = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Enter Your PIN",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "4-digit PIN",
              hintStyle: TextStyle(color: Colors.grey[400]),
              counterText: "",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[600]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[600]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: accentColor),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  isMatching = false;
                  _isAuthenticating = false;
                });
              },
              child: Text("Cancel", style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton(
              onPressed: () {
                if (_pinController.text.length != 4) {
                  CustomSnackBar.errorSnackBar("Please enter a 4-digit PIN");
                  return;
                }
                Navigator.of(context).pop();
                setState(() {
                  isMatching = true;
                  _isAuthenticating = true;
                });
                _fetchEmployeeByPin(_pinController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                "Verify",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Fetch employee data by PIN
  Future<void> _fetchEmployeeByPin(String pin) async {
    try {
      if (!_isOfflineMode) {
        final QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('employees')
            .where('pin', isEqualTo: pin)
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) {
          setState(() {
            isMatching = false;
            _isAuthenticating = false;
          });
          // Play failed audio (removed)
          CustomSnackBar.errorSnackBar("Invalid PIN. Please try again.");
          return;
        }

        final DocumentSnapshot employeeDoc = snapshot.docs.first;
        final String employeeId = employeeDoc.id;
        final Map<String, dynamic> data = employeeDoc.data() as Map<String, dynamic>;

        await _saveUserDataLocally(employeeId, data);
        if (data.containsKey('image') && data['image'] != null) {
          await _saveEmployeeImageLocally(employeeId, data['image']);
        }

        setState(() {
          employeeData = data;
        });

        _matchFaceWithStored();
      } else {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        Set<String> keys = prefs.getKeys();

        String? matchedEmployeeId;
        Map<String, dynamic>? matchedData;

        for (String key in keys) {
          if (key.startsWith('user_data_')) {
            String? userData = prefs.getString(key);
            if (userData != null) {
              Map<String, dynamic> data = jsonDecode(userData) as Map<String, dynamic>;
              if (data['pin'] == pin) {
                matchedEmployeeId = key.replaceFirst('user_data_', '');
                matchedData = data;
                break;
              }
            }
          }
        }

        if (matchedEmployeeId == null || matchedData == null) {
          setState(() {
            isMatching = false;
            _isAuthenticating = false;
          });
          // Play failed audio (removed)
          CustomSnackBar.errorSnackBar("Invalid PIN or no cached data available");
          return;
        }

        setState(() {
          employeeData = matchedData;
        });

        _matchFaceWithStored();
      }
    } catch (e) {
      setState(() {
        isMatching = false;
        _isAuthenticating = false;
      });
      // Play failed audio (removed)
      CustomSnackBar.errorSnackBar("Error verifying PIN: $e");
    }
  }

  // ================ FACE MATCHING LOGIC ================

  /// Match captured face with stored face data
  // REPLACE the existing _matchFaceWithStored method with this enhanced version

  /// Enhanced face matching with cloud recovery fallback
  Future<void> _matchFaceWithStored() async {
    setState(() {
      _hasAuthenticated = false;
    });

    String? storedImage;
    bool hasImageData = false;

    try {
      final secureFaceStorage = getIt<SecureFaceStorageService>();

      // ✅ STEP 1: Try to get local face data (existing logic)
      if (!_isOfflineMode && widget.employeeId != null) {
        try {
          DocumentSnapshot snapshot = await FirebaseFirestore.instance
              .collection('employees')
              .doc(widget.employeeId)
              .get()
              .timeout(const Duration(seconds: 5));

          if (snapshot.exists) {
            Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

            if (data.containsKey('image') && data['image'] != null) {
              storedImage = data['image'];
              if (storedImage!.contains('data:image') && storedImage!.contains(',')) {
                storedImage = storedImage!.split(',')[1];
              }
              hasImageData = true;
              setState(() {
                _hasStoredFace = true;
              });

              secureFaceStorage.saveFaceImage(widget.employeeId!, storedImage!)
                  .catchError((e) {});
            }
          }
        } catch (e) {
          debugPrint("⚠️ Could not fetch from Firestore: $e");
        }
      }

      // ✅ STEP 2: Try secure storage if no image from network
      if (!hasImageData && widget.employeeId != null) {
        try {
          storedImage = await secureFaceStorage.getFaceImage(widget.employeeId!);

          if (storedImage != null && storedImage.isNotEmpty) {
            hasImageData = true;
            setState(() {
              _hasStoredFace = true;
            });
          }
        } catch (e) {
          if (e.toString().contains("Permission denied") ||
              e.toString().contains("errno = 13")) {
            setState(() {
              _lastAuthResult = "Failed - Storage permission denied";
            });
            _showStoragePermissionErrorDialog();
            return;
          }
        }
      }

      // ✅ STEP 3: Try SharedPreferences as fallback
      if (!hasImageData && widget.employeeId != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          storedImage = prefs.getString('employee_image_${widget.employeeId}');

          if (storedImage != null && storedImage.isNotEmpty) {
            hasImageData = true;
            if (storedImage.contains('data:image') && storedImage.contains(',')) {
              storedImage = storedImage.split(',')[1];
            }
            setState(() {
              _hasStoredFace = true;
            });

            secureFaceStorage.saveFaceImage(widget.employeeId!, storedImage)
                .catchError((e) {});
          }
        } catch (e) {
          debugPrint("⚠️ Error reading from SharedPreferences: $e");
        }
      }

      // ✅ STEP 4: Try employee data as last resort
      if (!hasImageData && employeeData != null) {
        if (employeeData!.containsKey('image') && employeeData!['image'] != null) {
          storedImage = employeeData!['image'];
          if (storedImage!.contains('data:image') && storedImage!.contains(',')) {
            storedImage = storedImage!.split(',')[1];
          }
          hasImageData = true;
          setState(() {
            _hasStoredFace = true;
          });

          if (widget.employeeId != null) {
            secureFaceStorage.saveFaceImage(widget.employeeId!, storedImage!)
                .catchError((e) {});
          }
        }
      }

      // 🔥 NEW STEP 5: Cloud Recovery Attempt
      if (!hasImageData && widget.employeeId != null && !_isOfflineMode) {
        debugPrint("🌐 No local face data found, attempting cloud recovery...");

        setState(() {
          _realTimeFeedback = "Recovering face data from cloud...";
          _feedbackColor = Colors.orange;
        });

        try {
          bool recovered = await secureFaceStorage.downloadFaceDataFromCloud(widget.employeeId!);

          if (recovered) {
            debugPrint("✅ Face data recovered from cloud, retrying...");

            // Retry getting the recovered data
            storedImage = await secureFaceStorage.getFaceImage(widget.employeeId!);

            if (storedImage != null && storedImage.isNotEmpty) {
              hasImageData = true;
              setState(() {
                _hasStoredFace = true;
                _realTimeFeedback = "Face data recovered successfully";
                _feedbackColor = Colors.green;
              });

              debugPrint("🎉 Successfully recovered and loaded face data");
            }
          } else {
            debugPrint("❌ Cloud recovery failed");
            setState(() {
              _realTimeFeedback = "Could not recover face data";
              _feedbackColor = Colors.red;
            });
          }
        } catch (e) {
          debugPrint("❌ Error during cloud recovery: $e");
          setState(() {
            _realTimeFeedback = "Face data recovery failed";
            _feedbackColor = Colors.red;
          });
        }
      }

      // ✅ FINAL CHECK: If still no data, show error
      if (!hasImageData || storedImage == null) {
        setState(() {
          _lastAuthResult = "Failed - No stored image";
          isMatching = false;
          _isAuthenticating = false;
        });
        // Play failed audio (removed)

        // Enhanced error message
        String errorMessage = "No registered face found for this employee.";
        if (_isOfflineMode) {
          errorMessage += " Device is offline and no local face data available.";
        } else {
          errorMessage += " Please ensure face registration is complete or try again when online.";
        }

        _showFailureDialog(
          title: "Authentication Error",
          description: errorMessage,
        );

        if (widget.onAuthenticationComplete != null) {
          widget.onAuthenticationComplete!(false);
        }
        return;
      }

      // Continue with existing authentication logic...
      if (!_isOfflineMode) {
        await _performOnlineAuthentication(storedImage);
      } else {
        await _handleOfflineAuthentication();
      }

    } catch (e) {
      setState(() {
        isMatching = false;
        _isAuthenticating = false;
        _lastAuthResult = "Failed - Error: $e";
        _hasAuthenticated = false;
      });
      // Play failed audio (removed)
      _showFailureDialog(
        title: "Authentication Error",
        description: "Error during face matching: $e",
      );

      if (widget.onAuthenticationComplete != null) {
        widget.onAuthenticationComplete!(false);
      }
    }
  }

  /// Perform online authentication using Regula SDK
  Future<void> _performOnlineAuthentication(String storedImage) async {
    try {
      image1.bitmap = storedImage;
      image1.imageType = regula.ImageType.PRINTED;

      var request = regula.MatchFacesRequest();
      request.images = [image1, image2];

      if (_isOfflineMode) {
        _handleOfflineAuthentication();
        return;
      }

      dynamic value;
      try {
        value = await regula.FaceSDK.matchFaces(jsonEncode(request))
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        _handleOfflineAuthentication();
        return;
      }

      var response = regula.MatchFacesResponse.fromJson(json.decode(value));

      if (response == null || response.results == null || response.results!.isEmpty) {
        setState(() {
          isMatching = false;
          _isAuthenticating = false;
          _lastAuthResult = "Failed - No results from SDK";
        });
        // Play failed audio (removed)
        _showFailureDialog(
          title: "Authentication Failed",
          description: "Unable to process face comparison. Please try again with better lighting.",
        );

        if (widget.onAuthenticationComplete != null) {
          widget.onAuthenticationComplete!(false);
        }
        return;
      }

      double thresholdValue = 0.75;

      dynamic str = await regula.FaceSDK.matchFacesSimilarityThresholdSplit(
          jsonEncode(response.results), thresholdValue);

      var split = regula.MatchFacesSimilarityThresholdSplit.fromJson(json.decode(str));

      double similarityThreshold = 85.0;

      setState(() {
        _similarity = split!.matchedFaces.isNotEmpty
            ? (split.matchedFaces[0]!.similarity! * 100).toStringAsFixed(2)
            : "0.0";
      });

      if (_similarity != "0.0" && double.parse(_similarity) > similarityThreshold) {
        setState(() {
          _lastAuthResult = "Success ($_similarity%)";
          _hasAuthenticated = true;
        });
        _handleSuccessfulAuthentication();
      } else {
        setState(() {
          _lastAuthResult = "Failed - Low similarity ($_similarity%)";
          isMatching = false;
          _isAuthenticating = false;
          _hasAuthenticated = false;
        });
        // Play failed audio (removed)
        _showFailureDialog(
          title: "Authentication Failed",
          description: "Face doesn't match. Please ensure good lighting and try again.",
        );

        if (widget.onAuthenticationComplete != null) {
          widget.onAuthenticationComplete!(false);
        }
      }
    } catch (e) {
      _handleOfflineAuthentication();
    }
  }

  /// Handle offline authentication using ML Kit
  Future<void> _handleOfflineAuthentication() async {
    try {
      if (_faceFeatures == null) {
        setState(() {
          isMatching = false;
          _isAuthenticating = false;
        });
        // Play failed audio (removed)
        _showFailureDialog(
          title: "Authentication Failed",
          description: "No face detected. Please try again with better lighting.",
        );
        if (widget.onAuthenticationComplete != null) {
          widget.onAuthenticationComplete!(false);
        }
        return;
      }

      bool currentEyesOpen = true;

      if (_enhancedFaceFeatures != null) {
        currentEyesOpen = (_enhancedFaceFeatures!.leftEyeOpenProbability ?? 0) > 0.5 &&
            (_enhancedFaceFeatures!.rightEyeOpenProbability ?? 0) > 0.5;
      }

      if (!currentEyesOpen) {
        setState(() {
          isMatching = false;
          _isAuthenticating = false;
        });
        // Play failed audio (removed)
        _showFailureDialog(
          title: "Authentication Failed",
          description: "Please keep your eyes open during authentication.",
        );
        if (widget.onAuthenticationComplete != null) {
          widget.onAuthenticationComplete!(false);
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      String? storedFeaturesJson = prefs.getString('enhanced_face_features_${widget.employeeId}');
      bool isEnhancedComparison = true;

      if (storedFeaturesJson == null || storedFeaturesJson.isEmpty) {
        storedFeaturesJson = prefs.getString('employee_face_features_${widget.employeeId}');
        isEnhancedComparison = false;
      }

      if (storedFeaturesJson == null || storedFeaturesJson.isEmpty) {
        setState(() {
          isMatching = false;
          _isAuthenticating = false;
        });
        // Play failed audio (removed)
        _showFailureDialog(
          title: "Authentication Failed",
          description: "No face reference data found for offline authentication.",
        );
        if (widget.onAuthenticationComplete != null) {
          widget.onAuthenticationComplete!(false);
        }
        return;
      }

      double matchPercentage = 0.0;

      if (isEnhancedComparison) {
        try {
          Map<String, dynamic> storedFeaturesMap = json.decode(storedFeaturesJson);
          EnhancedFaceFeatures storedFeatures = EnhancedFaceFeatures.fromJson(storedFeaturesMap);

          if (_enhancedFaceFeatures != null) {
            matchPercentage = _enhancedFaceFeatures!.calculateSimilarityTo(storedFeatures) * 100;
          } else {
            matchPercentage = _compareLandmarksToEnhancedFeatures(storedFeatures);
          }
        } catch (e) {
          isEnhancedComparison = false;
        }
      }

      if (!isEnhancedComparison) {
        try {
          Map<String, dynamic> storedFeaturesMap = json.decode(storedFeaturesJson);
          FaceFeatures storedFeatures = FaceFeatures.fromJson(storedFeaturesMap);

          bool hasMatchingLeftEye = _comparePoints(storedFeatures.leftEye, _faceFeatures!.leftEye, 40);
          bool hasMatchingRightEye = _comparePoints(storedFeatures.rightEye, _faceFeatures!.rightEye, 40);
          bool hasMatchingNose = _comparePoints(storedFeatures.noseBase, _faceFeatures!.noseBase, 35);
          bool hasMatchingMouth = _comparePoints(storedFeatures.leftMouth, _faceFeatures!.leftMouth, 45) &&
              _comparePoints(storedFeatures.rightMouth, _faceFeatures!.rightMouth, 45);

          int matchCount = 0;
          int totalTests = 4;

          if (hasMatchingLeftEye) matchCount++;
          if (hasMatchingRightEye) matchCount++;
          if (hasMatchingNose) matchCount++;
          if (hasMatchingMouth) matchCount++;

          matchPercentage = matchCount / totalTests * 100;
        } catch (e) {
          matchPercentage = 0.0;
        }
      }

      setState(() {
        _similarity = matchPercentage.toStringAsFixed(2);
      });

      double requiredThreshold = isEnhancedComparison ? 80.0 : 70.0;

      if (matchPercentage >= requiredThreshold) {
        setState(() {
          _lastAuthResult = "Success ($_similarity%)";
          _hasAuthenticated = true;
        });
        _handleSuccessfulAuthentication();
      } else {
        setState(() {
          _lastAuthResult = "Failed - Low similarity ($_similarity%)";
          isMatching = false;
          _isAuthenticating = false;
          _hasAuthenticated = false;
        });
        // Play failed audio (removed)
        _showFailureDialog(
          title: "Authentication Failed",
          description: "Face doesn't match. Please try again with good lighting and keep your eyes open.",
        );

        if (widget.onAuthenticationComplete != null) {
          widget.onAuthenticationComplete!(false);
        }
      }
    } catch (e) {
      setState(() {
        isMatching = false;
        _isAuthenticating = false;
      });
      // Play failed audio (removed)
      _showFailureDialog(
        title: "Authentication Failed",
        description: "Error during face matching: $e",
      );

      if (widget.onAuthenticationComplete != null) {
        widget.onAuthenticationComplete!(false);
      }
    }
  }

  /// Compare landmarks to enhanced features for compatibility
  double _compareLandmarksToEnhancedFeatures(EnhancedFaceFeatures storedFeatures) {
    if (_faceFeatures == null) return 0.0;

    double totalScore = 0.0;
    int comparisons = 0;

    Map<String, Points?> legacyPoints = {
      'FaceLandmarkType.leftEye': _faceFeatures!.leftEye,
      'FaceLandmarkType.rightEye': _faceFeatures!.rightEye,
      'FaceLandmarkType.noseBase': _faceFeatures!.noseBase,
      'FaceLandmarkType.leftMouth': _faceFeatures!.leftMouth,
      'FaceLandmarkType.rightMouth': _faceFeatures!.rightMouth,
    };

    for (String landmarkKey in legacyPoints.keys) {
      Points? currentPoint = legacyPoints[landmarkKey];
      Map<String, double>? storedPoint = storedFeatures.landmarkPositions[landmarkKey];

      if (currentPoint != null && storedPoint != null &&
          currentPoint.x != null && currentPoint.y != null) {

        double distance = sqrt(
            (currentPoint.x! - storedPoint['x']!) * (currentPoint.x! - storedPoint['x']!) +
                (currentPoint.y! - storedPoint['y']!) * (currentPoint.y! - storedPoint['y']!)
        );

        double similarity = 1.0 / (1.0 + distance / 50.0);
        totalScore += similarity;
        comparisons++;
      }
    }

    return comparisons > 0 ? (totalScore / comparisons) * 100 : 0.0;
  }

  /// Compare two points with tolerance
  bool _comparePoints(Points? p1, Points? p2, double tolerance) {
    if (p1 == null || p2 == null || p1.x == null || p2.x == null) return false;

    double distance = sqrt(
        (p1.x! - p2.x!) * (p1.x! - p2.x!) +
            (p1.y! - p2.y!) * (p1.y! - p2.y!)
    );

    return distance <= tolerance;
  }

  // ================ ERROR HANDLING ================

  /// Show storage permission error dialog
  void _showStoragePermissionErrorDialog() {
    if (!mounted) return;

    // Play failed audio (removed)
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Storage Permission Error",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "The app couldn't access the secure storage for face data. This is needed for offline authentication.\n\n"
              "Please go to Settings > Apps > PHOENICIAN > Permissions and grant 'Files and media' permission.",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Cancel", style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Open Settings", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    setState(() {
      isMatching = false;
      _isAuthenticating = false;
    });

    if (widget.onAuthenticationComplete != null) {
      widget.onAuthenticationComplete!(false);
    }
  }

  /// Show failure dialog with custom message
  void _showFailureDialog({
    required String title,
    required String description,
  }) {
    // Play failed audio (removed)
    setState(() {
      isMatching = false;
      _isAuthenticating = false;
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            description,
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                "Ok",
                style: TextStyle(color: Colors.white),
              ),
            )
          ],
        );
      },
    );
  }
}