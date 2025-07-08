// lib/pin_entry/pin_entry_view.dart - FIXED WITH USER PROFILE FLOW

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phoenician_face_auth/common/utils/custom_snackbar.dart';
import 'package:phoenician_face_auth/constants/theme.dart';
import 'package:phoenician_face_auth/dashboard/dashboard_view.dart';
import 'package:phoenician_face_auth/pin_entry/user_profile_view.dart'; // ✅ ADDED BACK
import 'package:phoenician_face_auth/model/user_model.dart';
import 'package:phoenician_face_auth/admin/admin_login_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PinEntryView extends StatefulWidget {
  const PinEntryView({Key? key}) : super(key: key);

  @override
  State<PinEntryView> createState() => _PinEntryViewState();
}

class _PinEntryViewState extends State<PinEntryView> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(
    4,
        (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    4,
        (index) => FocusNode(),
  );

  bool _isLoading = false;
  bool _isPinEntered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation for the verification button
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Set up listeners for the PIN fields
    for (int i = 0; i < 4; i++) {
      _focusNodes[i].addListener(() {
        setState(() {});
      });

      _controllers[i].addListener(() {
        // Check if all PIN fields are filled
        _checkPinCompletion();

        // Auto advance to next field
        if (_controllers[i].text.length == 1 && i < 3) {
          FocusScope.of(context).requestFocus(_focusNodes[i + 1]);
        }
      });
    }
  }

  void _checkPinCompletion() {
    bool allFilled = true;
    for (var controller in _controllers) {
      if (controller.text.isEmpty) {
        allFilled = false;
        break;
      }
    }

    if (allFilled != _isPinEntered) {
      setState(() {
        _isPinEntered = allFilled;
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  String get _pin => _controllers.map((e) => e.text).join();

  void _clearPin() {
    for (var controller in _controllers) {
      controller.clear();
    }
    setState(() {
      _isPinEntered = false;
    });
    FocusScope.of(context).requestFocus(_focusNodes[0]);
  }

  // ✅ FIXED: Back to original flow with User Profile
  Future<void> _verifyPin() async {
    if (_pin.length != 4) {
      _showError("Please enter a 4-digit PIN");
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      debugPrint("🔐 Verifying PIN: $_pin");

      // Check if this is the admin PIN
      if (_pin == "9999") {
        setState(() => _isLoading = false);
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AdminLoginView(),
            ),
          );
        }
        return;
      }

      // ✅ STEP 1: Find employee by PIN
      final querySnapshot = await FirebaseFirestore.instance
          .collection("employees")
          .where("pin", isEqualTo: _pin)
          .limit(1)
          .get();

      setState(() => _isLoading = false);

      if (querySnapshot.docs.isEmpty) {
        _showError("Invalid PIN. Please try again.");
        _animateErrorShake();
        return;
      }

      // ✅ STEP 2: Get employee data and create UserModel
      final employeeDoc = querySnapshot.docs.first;
      final employeeData = employeeDoc.data();
      final employeeId = employeeDoc.id;

      debugPrint("✅ Employee found: ${employeeData['name']} ($employeeId)");

      // ✅ STEP 3: Save authentication data (but not mark as fully authenticated yet)
      await _saveAuthenticationData(employeeId, employeeData);

      // ✅ STEP 4: Create UserModel
      final employee = UserModel(
        id: employeeId,
        name: employeeData['name'] ?? 'Employee',
        // Add other fields as needed
      );

      // ✅ STEP 5: Determine if user is new or returning
      bool isNewUser = _determineIfNewUser(employeeData);

      debugPrint("🔍 User status: ${isNewUser ? 'New User' : 'Returning User'}");
      debugPrint("📊 Registration status: ${employeeData.toString()}");

      // ✅ STEP 6: Navigate to User Profile View (like the old working version)
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UserProfileView(
              employeePin: _pin,
              user: employee,
              isNewUser: isNewUser,
            ),
          ),
        );
      }

    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("❌ PIN verification error: $e");
      _showError("Error verifying PIN: $e");
      _animateErrorShake();
    }
  }

  // ✅ DETERMINE IF USER IS NEW OR RETURNING
  bool _determineIfNewUser(Map<String, dynamic> employeeData) {
    // Check multiple fields to determine user status
    bool profileCompleted = employeeData['profileCompleted'] ?? false;
    bool registrationCompleted = employeeData['registrationCompleted'] ?? false;
    bool faceRegistered = employeeData['faceRegistered'] ?? false;
    bool enhancedRegistration = employeeData['enhancedRegistration'] ?? false;

    debugPrint("📋 Profile Status:");
    debugPrint("   - profileCompleted: $profileCompleted");
    debugPrint("   - registrationCompleted: $registrationCompleted");
    debugPrint("   - faceRegistered: $faceRegistered");
    debugPrint("   - enhancedRegistration: $enhancedRegistration");

    // User is considered "new" if they haven't completed the full registration process
    // This includes profile setup AND face registration
    bool isFullyRegistered = profileCompleted &&
        registrationCompleted &&
        (faceRegistered || enhancedRegistration);

    return !isFullyRegistered;
  }

  // ✅ SAVE AUTHENTICATION DATA (but not mark as fully authenticated)
  Future<void> _saveAuthenticationData(String employeeId, Map<String, dynamic> employeeData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save basic authentication data
      await prefs.setString('authenticated_user_id', employeeId);
      await prefs.setString('authenticated_employee_pin', _pin);
      // ✅ DON'T mark as fully authenticated until registration is complete
      await prefs.setBool('is_authenticated', false);
      await prefs.setInt('authentication_timestamp', DateTime.now().millisecondsSinceEpoch);

      // Save employee data
      Map<String, dynamic> dataToSave = Map<String, dynamic>.from(employeeData);
      dataToSave.forEach((key, value) {
        if (value is Timestamp) {
          dataToSave[key] = value.toDate().toIso8601String();
        }
      });

      await prefs.setString('user_data_$employeeId', jsonEncode(dataToSave));
      await prefs.setString('user_name_$employeeId', employeeData['name'] ?? 'User');
      await prefs.setBool('user_exists_$employeeId', true);

      debugPrint("💾 Basic authentication data saved for: $employeeId");
    } catch (e) {
      debugPrint("❌ Error saving authentication data: $e");
    }
  }

  void _showError(String message) {
    if (CustomSnackBar.context != null) {
      CustomSnackBar.errorSnackBar(message);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _animateErrorShake() {
    // Simple shake animation for incorrect PIN
    final shakeCount = 3;
    final shakeDuration = 50;
    for (var i = 0; i < shakeCount * 2; i++) {
      Future.delayed(Duration(milliseconds: i * shakeDuration), () {
        if (mounted) {
          // Animate container left/right slightly
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialize context here as well for safety
    if (CustomSnackBar.context == null) {
      CustomSnackBar.context = context;
    }

    return Scaffold(
      // Ensure we have a clean layout without any debug banners
      resizeToAvoidBottomInset: false,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scaffoldTopGradientClr,
              scaffoldBottomGradientClr,
            ],
          ),
        ),
        child: SafeArea(
          // Make sure content stays within safe area bounds
          maintainBottomViewPadding: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              // App logo or icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 40,
                ),
              ),

              const SizedBox(height: 30),

              // Title and instruction
              const Text(
                "Employee Authentication",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  "Enter your 4-digit PIN to continue",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 40),

              // PIN input fields
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    4,
                        (index) => _buildPinField(index),
                  ),
                ),
              ),

              // Conditional verification UI
              if (_isPinEntered) ...[
                const SizedBox(height: 40),
                SvgPicture.asset(
                  'assets/images/pin_success.svg', // Your confirmation SVG
                  height: 120,
                  width: 120,
                ),
                const SizedBox(height: 20),
                const Text(
                  "PIN entered successfully",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 40),
                SvgPicture.asset(
                  'assets/images/pin_entry_image.svg', // Your PIN entry SVG
                  height: 140,
                  width: 140,
                ),
              ],

              const Spacer(),

              // Action buttons
              if (_isLoading)
                const CircularProgressIndicator(color: Colors.white)
              else if (_isPinEntered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Clear button
                      GestureDetector(
                        onTap: _clearPin,
                        child: Container(
                          width: 140,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: const Center(
                            child: Text(
                              "Clear",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 20),

                      // Next button
                      GestureDetector(
                        onTapDown: (_) => _animationController.forward(),
                        onTapUp: (_) {
                          _animationController.reverse();
                          _verifyPin();
                        },
                        onTapCancel: () => _animationController.reverse(),
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: Container(
                            width: 140,
                            height: 50,
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                "Next",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Text(
                    "If you've forgotten your PIN, please contact your administrator",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Admin Login Button
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AdminLoginView(),
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.admin_panel_settings, color: Colors.white70, size: 16),
                        SizedBox(width: 4),
                        Text(
                          "Admin Login",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinField(int index) {
    return Container(
      width: 50,
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _controllers[index].text.isNotEmpty
            ? Colors.white
            : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        obscureText: true,
        style: TextStyle(
          color: _controllers[index].text.isNotEmpty
              ? accentColor
              : Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
        ),
        onChanged: (value) {
          if (value.isEmpty && index > 0) {
            FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
          }
        },
      ),
    );
  }
}