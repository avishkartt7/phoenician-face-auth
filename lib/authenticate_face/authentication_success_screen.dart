// lib/authenticate_face/authentication_success_screen.dart - COMPATIBLE WITH GEOLOCATOR 9.0.2

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:phoenician_face_auth/constants/theme.dart';

class AuthenticationSuccessScreen extends StatefulWidget {
  final String employeeName;
  final String employeeId;
  final String actionType; // "check_in", "check_out", "authentication"
  final String similarityScore;

  const AuthenticationSuccessScreen({
    Key? key,
    required this.employeeName,
    required this.employeeId,
    required this.actionType,
    required this.similarityScore,
  }) : super(key: key);

  @override
  State<AuthenticationSuccessScreen> createState() => _AuthenticationSuccessScreenState();
}

class _AuthenticationSuccessScreenState extends State<AuthenticationSuccessScreen>
    with TickerProviderStateMixin {

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  String _currentLocation = "Getting location...";
  String _currentAddress = "";
  double? _latitude;
  double? _longitude;
  bool _isWithinGeofence = false;
  String _geofenceStatus = "Checking location...";
  DateTime _authenticationTime = DateTime.now();

  // Timer for auto-close
  Timer? _autoCloseTimer;
  int _countdownSeconds = 10;

  // Loading state management
  bool _isLoadingLocation = true;
  bool _locationPermissionDenied = false;
  bool _locationTimeout = false;

  // Platform detection
  bool get _isIOS => Platform.isIOS;

  @override
  void initState() {
    super.initState();
    debugPrint("🚀 AuthenticationSuccessScreen initState - Platform: ${_isIOS ? 'iOS' : 'Android'}");

    _initializeAnimations();
    _startLocationWithTimeout();
    _startAutoCloseCountdown();
  }

  void _initializeAnimations() {
    debugPrint("🎨 Initializing animations");

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );

    debugPrint("▶️ Starting animations");
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  void _startAutoCloseCountdown() {
    debugPrint("⏰ Starting auto-close countdown");

    _autoCloseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _countdownSeconds--;
        });

        if (_countdownSeconds <= 0) {
          timer.cancel();
          debugPrint("⏰ Auto-close triggered");
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _startLocationWithTimeout() {
    debugPrint("📍 Starting location request with timeout");

    // Timeout for location request
    int timeoutSeconds = _isIOS ? 6 : 8;

    Timer(Duration(seconds: timeoutSeconds), () {
      if (_isLoadingLocation && mounted) {
        debugPrint("⏰ Location request timed out");
        setState(() {
          _isLoadingLocation = false;
          _locationTimeout = true;
          _currentLocation = "Location timeout";
          _geofenceStatus = "Unable to get location quickly";
        });
      }
    });

    _getCurrentLocationSafely();
  }

  // FIXED: Compatible with geolocator 9.0.2
  Future<void> _getCurrentLocationSafely() async {
    try {
      debugPrint("🔄 Starting location request");

      // Check location services
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(seconds: 2));

      if (!serviceEnabled) {
        debugPrint("❌ Location services disabled");
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
            _currentLocation = "Location services disabled";
            _geofenceStatus = "Enable location services in Settings";
          });
        }
        return;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission()
          .timeout(Duration(seconds: _isIOS ? 3 : 2));

      if (permission == LocationPermission.denied) {
        debugPrint("📍 Requesting location permission");

        permission = await Geolocator.requestPermission()
            .timeout(Duration(seconds: _isIOS ? 8 : 5));

        if (permission == LocationPermission.denied) {
          debugPrint("❌ Location permission denied");
          if (mounted) {
            setState(() {
              _isLoadingLocation = false;
              _locationPermissionDenied = true;
              _currentLocation = "Location permission denied";
              _geofenceStatus = "Grant location permission to verify location";
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("❌ Location permission denied forever");
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
            _locationPermissionDenied = true;
            _currentLocation = "Location permission permanently denied";
            _geofenceStatus = "Enable location permission in Settings";
          });
        }
        return;
      }

      debugPrint("✅ Getting current position");

      // FIXED: Using old geolocator 9.0.2 API
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: _isIOS ? 5 : 4),
      ).timeout(Duration(seconds: _isIOS ? 6 : 5));

      debugPrint("✅ Got position: ${position.latitude}, ${position.longitude}");

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _currentLocation = "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
          _isLoadingLocation = false;
        });
      }

      // Get address in background
      _getAddressInBackground(position.latitude, position.longitude);

      // Check geofence
      _checkGeofence(position.latitude, position.longitude);

    } on TimeoutException catch (e) {
      debugPrint("⏰ Location timeout: $e");
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _locationTimeout = true;
          _currentLocation = "Location request timed out";
          _geofenceStatus = "Location unavailable - timed out";
        });
      }
    } catch (e) {
      debugPrint("❌ Location error: $e");
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _currentLocation = "Unable to get location";
          _geofenceStatus = "Location unavailable";

          if (e.toString().contains('PERMISSION_DENIED') ||
              e.toString().contains('Permission denied')) {
            _locationPermissionDenied = true;
            _currentLocation = "Location permission required";
            _geofenceStatus = "Grant location permission";
          } else if (e.toString().contains('LOCATION_SERVICES_DISABLED') ||
              e.toString().contains('Location services are disabled')) {
            _currentLocation = "Location services disabled";
            _geofenceStatus = "Enable location services";
          }
        });
      }
    }
  }

  void _getAddressInBackground(double latitude, double longitude) async {
    try {
      debugPrint("🏠 Getting address for coordinates");

      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      ).timeout(const Duration(seconds: 5));

      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        String address = _buildAddressString(place);

        setState(() {
          _currentAddress = address.isEmpty ? "Unknown location" : address;
        });

        debugPrint("✅ Address updated: $address");
      }
    } catch (e) {
      debugPrint("⚠️ Address error: $e");
      if (mounted) {
        setState(() {
          _currentAddress = "Address unavailable";
        });
      }
    }
  }

  String _buildAddressString(Placemark place) {
    List<String> addressParts = [];

    if (place.name != null && place.name!.isNotEmpty) {
      addressParts.add(place.name!);
    }
    if (place.street != null && place.street!.isNotEmpty && place.street != place.name) {
      addressParts.add(place.street!);
    }
    if (place.locality != null && place.locality!.isNotEmpty) {
      addressParts.add(place.locality!);
    }
    if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
      addressParts.add(place.administrativeArea!);
    }

    return addressParts.take(3).join(', ');
  }

  void _checkGeofence(double latitude, double longitude) {
    try {
      debugPrint("🎯 Checking geofence");

      // TODO: Replace with your actual office coordinates
      const double officeLatitude = 25.2048; // Dubai example - REPLACE WITH YOUR COORDINATES
      const double officeLongitude = 55.2708; // Dubai example - REPLACE WITH YOUR COORDINATES
      const double geofenceRadius = 500; // 500 meters - ADJUST AS NEEDED

      double distance = Geolocator.distanceBetween(
        latitude,
        longitude,
        officeLatitude,
        officeLongitude,
      );

      if (mounted) {
        setState(() {
          _isWithinGeofence = distance <= geofenceRadius;
          if (_isWithinGeofence) {
            _geofenceStatus = "✅ Within office premises";
          } else {
            _geofenceStatus = "⚠️ Outside office area (${distance.toInt()}m away)";
          }
        });
      }

      debugPrint("📍 Geofence check: ${_isWithinGeofence ? 'Inside' : 'Outside'} (${distance.toInt()}m)");
    } catch (e) {
      debugPrint("⚠️ Geofence error: $e");
      if (mounted) {
        setState(() {
          _geofenceStatus = "Unable to verify location";
        });
      }
    }
  }

  @override
  void dispose() {
    debugPrint("🗑️ AuthenticationSuccessScreen dispose");
    _autoCloseTimer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  String get _actionTitle {
    switch (widget.actionType.toLowerCase()) {
      case 'check_in':
        return 'Check-In Successful!';
      case 'check_out':
        return 'Check-Out Successful!';
      default:
        return 'Authentication Successful!';
    }
  }

  String get _actionMessage {
    switch (widget.actionType.toLowerCase()) {
      case 'check_in':
        return 'Welcome to work, ${widget.employeeName}!';
      case 'check_out':
        return 'Have a great day, ${widget.employeeName}!';
      default:
        return 'Welcome, ${widget.employeeName}!';
    }
  }

  Color get _actionColor {
    switch (widget.actionType.toLowerCase()) {
      case 'check_in':
        return const Color(0xFF4CAF50); // Green
      case 'check_out':
        return const Color(0xFF2196F3); // Blue
      default:
        return const Color(0xFF667eea); // Purple
    }
  }

  IconData get _actionIcon {
    switch (widget.actionType.toLowerCase()) {
      case 'check_in':
        return Icons.login;
      case 'check_out':
        return Icons.logout;
      default:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("🏗️ Building AuthenticationSuccessScreen");

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _actionColor.withOpacity(0.1),
              _actionColor.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Header
                    _buildHeader(),
                    const SizedBox(height: 20),

                    // Success section
                    _buildSuccessSection(),
                    const SizedBox(height: 20),

                    // Info section
                    Expanded(child: _buildInfoSection()),
                    const SizedBox(height: 20),

                    // Action buttons
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            debugPrint("❌ Manual close button pressed");
            Navigator.of(context).pop();
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.close,
              color: Colors.grey[600],
              size: 20,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            "Auto-close in $_countdownSeconds",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessSection() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _actionColor.withOpacity(0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _actionColor.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              _actionIcon,
              size: 60,
              color: _actionColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _actionTitle,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _actionColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _actionMessage,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Time card
          _buildInfoCard(
            icon: Icons.access_time,
            title: "Time",
            content: DateFormat('MMM dd, yyyy - hh:mm:ss a').format(_authenticationTime),
            color: Colors.blue,
          ),

          const SizedBox(height: 12),

          // Location card
          _buildInfoCard(
            icon: _isLoadingLocation
                ? Icons.hourglass_empty
                : _locationPermissionDenied
                ? Icons.location_off
                : _locationTimeout
                ? Icons.location_searching
                : Icons.location_on,
            title: "Location",
            content: _currentAddress.isNotEmpty ? _currentAddress : _currentLocation,
            subtitle: _currentAddress.isNotEmpty ? _currentLocation : null,
            color: _locationPermissionDenied
                ? Colors.red
                : _locationTimeout
                ? Colors.orange
                : Colors.green,
            isLoading: _isLoadingLocation,
          ),

          const SizedBox(height: 12),

          // Geofence status card
          _buildInfoCard(
            icon: _isLoadingLocation
                ? Icons.hourglass_empty
                : _isWithinGeofence
                ? Icons.check_circle
                : _locationPermissionDenied || _locationTimeout
                ? Icons.warning
                : Icons.location_searching,
            title: "Location Status",
            content: _geofenceStatus,
            color: _isLoadingLocation
                ? Colors.blue
                : _isWithinGeofence
                ? Colors.green
                : _locationPermissionDenied
                ? Colors.red
                : Colors.orange,
            isLoading: _isLoadingLocation,
          ),

          const SizedBox(height: 12),

          // Authentication details card
          _buildInfoCard(
            icon: Icons.face,
            title: "Authentication Details",
            content: "Face match: ${widget.similarityScore}%",
            subtitle: "Employee ID: ${widget.employeeId}",
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              debugPrint("✅ Continue button pressed");
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text(
              "Continue",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _actionColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              String debugInfo = """
Platform: ${_isIOS ? 'iOS' : 'Android'}
Geolocator Version: 9.0.2 (Compatible)
Location Loading: $_isLoadingLocation
Permission Denied: $_locationPermissionDenied
Location Timeout: $_locationTimeout
Coordinates: ${_latitude?.toStringAsFixed(4) ?? 'N/A'}, ${_longitude?.toStringAsFixed(4) ?? 'N/A'}
Within Geofence: $_isWithinGeofence
              """.trim();

              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Debug Information"),
                  content: SingleChildScrollView(
                    child: Text(debugInfo),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("Close"),
                    ),
                  ],
                ),
              );
            },
            icon: Icon(Icons.info_outline, color: _actionColor),
            label: Text(
              "Debug Info",
              style: TextStyle(
                color: _actionColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _actionColor),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    String? subtitle,
    required Color color,
    bool isLoading = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: isLoading
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: color,
                strokeWidth: 2,
              ),
            )
                : Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}