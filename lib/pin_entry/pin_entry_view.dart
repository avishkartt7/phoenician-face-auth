// lib/pin_entry/pin_entry_view.dart - FIXED WITH AUTO-VERIFY AND KEYBOARD HIDE

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phoenician_face_auth/common/utils/custom_snackbar.dart';
import 'package:phoenician_face_auth/constants/theme.dart';
import 'package:phoenician_face_auth/dashboard/dashboard_view.dart';
import 'package:phoenician_face_auth/pin_entry/user_profile_view.dart';
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
  bool _isAutoVerifying = false; // ✅ NEW: Track auto-verification state
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
        // ✅ ENHANCED: Auto-verify when PIN is complete
        _handlePinInput(i);
      });
    }
  }

  // ✅ NEW: Enhanced PIN input handling with auto-verification
  void _handlePinInput(int index) {
    // Auto advance to next field
    if (_controllers[index].text.length == 1 && index < 3) {
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    }

    // Check if all PIN fields are filled
    _checkPinCompletion();

    // ✅ NEW: Auto-verify when 4th digit is entered
    if (index == 3 && _controllers[index].text.length == 1) {
      _handleFourthDigitEntered();
    }
  }

  // ✅ NEW: Handle when 4th digit is entered
  void _handleFourthDigitEntered() async {
    // Small delay to ensure UI updates
    await Future.delayed(const Duration(milliseconds: 100));

    if (_pin.length == 4 && !_isAutoVerifying && !_isLoading) {
      debugPrint("🔐 4th digit entered, auto-verifying PIN: $_pin");
      
      // ✅ Hide keyboard immediately
      FocusScope.of(context).unfocus();
      
      // ✅ Hide keyboard using system method
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      
      // ✅ Auto-verify PIN
      setState(() {
        _isAutoVerifying = true;
      });

      // ✅ Auto-verify after short delay for better UX
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        await _verifyPin();
      }
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
      _isAutoVerifying = false; // ✅ Reset auto-verification state
    });
    FocusScope.of(context).requestFocus(_focusNodes[0]);
  }

  // ✅ ENHANCED: PIN verification with better UX
  Future<void> _verifyPin() async {
    if (_pin.length != 4) {
      _showError("Please enter a 4-digit PIN");
      return;
    }

    // ✅ Prevent multiple simultaneous verifications
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // ✅ Hide keyboard again to be sure
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    
    HapticFeedback.mediumImpact();

    try {
      debugPrint("🔐 Verifying PIN: $_pin");

      // Check if this is the admin PIN
      if (_pin == "9999") {
        setState(() {
          _isLoading = false;
          _isAutoVerifying = false;
        });
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AdminLoginView(),
            ),
          );
        }
        return;
      }

      // ✅ Find employee by PIN
      final querySnapshot = await FirebaseFirestore.instance
          .collection("employees")
          .where("pin", isEqualTo: _pin)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _isAutoVerifying = false;
        });
        _showError("Invalid PIN. Please try again.");
        _animateErrorShake();
        _clearPin(); // ✅ Clear PIN on error
        return;
      }

      // ✅ Get employee data and create UserModel
      final employeeDoc = querySnapshot.docs.first;
      final employeeData = employeeDoc.data();
      final employeeId = employeeDoc.id;

      debugPrint("✅ Employee found: ${employeeData['name']} ($employeeId)");

      // ✅ Save authentication data
      await _saveAuthenticationData(employeeId, employeeData);

      // ✅ Create UserModel
      final employee = UserModel(
        id: employeeId,
        name: employeeData['name'] ?? 'Employee',
      );

      // ✅ Determine if user is new or returning
      bool isNewUser = _determineIfNewUser(employeeData);

      debugPrint("🔍 User status: ${isNewUser ? 'New User' : 'Returning User'}");

      setState(() {
        _isLoading = false;
        _isAutoVerifying = false;
      });

      // ✅ Navigate to User Profile View
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
      setState(() {
        _isLoading = false;
        _isAutoVerifying = false;
      });
      debugPrint("❌ PIN verification error: $e");
      _showError("Error verifying PIN: $e");
      _animateErrorShake();
      _clearPin(); // ✅ Clear PIN on error
    }
  }

  // ✅ DETERMINE IF USER IS NEW OR RETURNING
  bool _determineIfNewUser(Map<String, dynamic> employeeData) {
    bool profileCompleted = employeeData['profileCompleted'] ?? false;
    bool registrationCompleted = employeeData['registrationCompleted'] ?? false;
    bool faceRegistered = employeeData['faceRegistered'] ?? false;
    bool enhancedRegistration = employeeData['enhancedRegistration'] ?? false;

    debugPrint("📋 Profile Status:");
    debugPrint("   - profileCompleted: $profileCompleted");
    debugPrint("   - registrationCompleted: $registrationCompleted");
    debugPrint("   - faceRegistered: $faceRegistered");
    debugPrint("   - enhancedRegistration: $enhancedRegistration");

    bool isFullyRegistered = profileCompleted &&
        registrationCompleted &&
        (faceRegistered || enhancedRegistration);

    return !isFullyRegistered;
  }

  // ✅ SAVE AUTHENTICATION DATA
  Future<void> _saveAuthenticationData(String employeeId, Map<String, dynamic> employeeData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('authenticated_user_id', employeeId);
      await prefs.setString('authenticated_employee_pin', _pin);
      await prefs.setBool('is_authenticated', false);
      await prefs.setInt('authentication_timestamp', DateTime.now().millisecondsSinceEpoch);

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
    // ✅ Enhanced shake animation
    HapticFeedback.heavyImpact();
    
    // Simple shake animation for incorrect PIN
    final shakeCount = 3;
    final shakeDuration = 50;
    for (var i = 0; i < shakeCount * 2; i++) {
      Future.delayed(Duration(milliseconds: i * shakeDuration), () {
        if (mounted) {
          // Could add shake animation here if needed
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (CustomSnackBar.context == null) {
      CustomSnackBar.context = context;
    }

    return Scaffold(
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

              // ✅ ENHANCED: Dynamic instruction text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _isAutoVerifying
                      ? "Verifying your PIN..."
                      : _isPinEntered
                          ? "PIN entered successfully!"
                          : "Enter your 4-digit PIN to continue",
                  style: TextStyle(
                    color: _isAutoVerifying ? Colors.yellow : Colors.white70,
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

              const SizedBox(height: 40),

              // ✅ ENHANCED: Dynamic UI based on state
              if (_isLoading || _isAutoVerifying) ...[
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  _isAutoVerifying ? "Verifying PIN..." : "Processing...",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ] else if (_isPinEntered) ...[
                // ✅ Success state - show success icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "PIN verified successfully!",
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ] else ...[
                // ✅ Default state - show PIN entry instruction
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Enter your 4-digit PIN",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],

              const Spacer(),

              // ✅ ENHANCED: Action buttons (only show if not auto-verifying)
              if (!_isAutoVerifying && !_isLoading && _isPinEntered) ...[
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

                      // Manual Next button (for fallback)
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
                ),
              ] else if (!_isAutoVerifying && !_isLoading) ...[
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
              ],

              // Admin Login Button
              if (!_isAutoVerifying && !_isLoading) ...[
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
        // ✅ Add border for better visual feedback
        border: Border.all(
          color: _controllers[index].text.isNotEmpty
              ? accentColor
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        obscureText: true,
        // ✅ ENHANCED: Input formatters to ensure only numbers
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
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
