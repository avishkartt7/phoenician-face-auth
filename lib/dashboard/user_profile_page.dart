// lib/dashboard/user_profile_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phoenician_face_auth/constants/theme.dart';
import 'package:phoenician_face_auth/common/utils/custom_snackbar.dart';
import 'package:phoenician_face_auth/common/views/custom_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfilePage extends StatefulWidget {
  final String employeeId;
  final Map<String, dynamic> userData;

  const UserProfilePage({
    Key? key,
    required this.employeeId,
    required this.userData,
  }) : super(key: key);

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with SingleTickerProviderStateMixin {
  late TextEditingController _nameController;
  late TextEditingController _designationController;
  late TextEditingController _departmentController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _countryController;
  late TextEditingController _birthdateController;

  // Break time controllers
  late TextEditingController _breakStartTimeController;
  late TextEditingController _breakEndTimeController;
  late TextEditingController _jummaBreakStartController;
  late TextEditingController _jummaBreakEndController;

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  bool _isEditing = false;
  bool _isLoading = false;
  bool _hasJummaBreak = false;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadDarkModePreference();
    _initializeAnimations();
    _initializeControllers();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.userData['name'] ?? '');
    _designationController = TextEditingController(text: widget.userData['designation'] ?? '');
    _departmentController = TextEditingController(text: widget.userData['department'] ?? '');
    _phoneController = TextEditingController(text: widget.userData['phone'] ?? '');
    _emailController = TextEditingController(text: widget.userData['email'] ?? '');
    _countryController = TextEditingController(text: widget.userData['country'] ?? '');
    _birthdateController = TextEditingController(text: widget.userData['birthdate'] ?? '');

    _breakStartTimeController = TextEditingController(text: widget.userData['breakStartTime'] ?? '');
    _breakEndTimeController = TextEditingController(text: widget.userData['breakEndTime'] ?? '');
    _hasJummaBreak = widget.userData['hasJummaBreak'] ?? false;
    _jummaBreakStartController = TextEditingController(text: widget.userData['jummaBreakStart'] ?? '');
    _jummaBreakEndController = TextEditingController(text: widget.userData['jummaBreakEnd'] ?? '');
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _countryController.dispose();
    _birthdateController.dispose();
    _breakStartTimeController.dispose();
    _breakEndTimeController.dispose();
    _jummaBreakStartController.dispose();
    _jummaBreakEndController.dispose();
    super.dispose();
  }

  // Responsive design helper methods
  double get screenWidth => MediaQuery.of(context).size.width;
  double get screenHeight => MediaQuery.of(context).size.height;
  bool get isTablet => screenWidth > 600;
  bool get isSmallScreen => screenWidth < 360;

  EdgeInsets get responsivePadding => EdgeInsets.symmetric(
    horizontal: isTablet ? 24.0 : (isSmallScreen ? 12.0 : 16.0),
    vertical: isTablet ? 20.0 : (isSmallScreen ? 12.0 : 16.0),
  );

  double get responsiveFontSize {
    if (isTablet) return 1.2;
    if (isSmallScreen) return 0.9;
    return 1.0;
  }

  Future<void> _loadDarkModePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        brightness: Brightness.light,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        brightness: Brightness.dark,
      ),
    );
  }

  void _toggleEditing() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: _isDarkMode
                ? ColorScheme.dark(primary: const Color(0xFF6366F1))
                : ColorScheme.light(primary: const Color(0xFF6366F1)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        controller.text = picked.format(context);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      CustomSnackBar.errorSnackBar(context, "Name cannot be empty");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .update({
        'name': _nameController.text.trim(),
        'designation': _designationController.text.trim(),
        'department': _departmentController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'country': _countryController.text.trim(),
        'birthdate': _birthdateController.text.trim(),
        'breakStartTime': _breakStartTimeController.text.trim(),
        'breakEndTime': _breakEndTimeController.text.trim(),
        'hasJummaBreak': _hasJummaBreak,
        'jummaBreakStart': _jummaBreakStartController.text.trim(),
        'jummaBreakEnd': _jummaBreakEndController.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isLoading = false;
        _isEditing = false;
      });

      if (mounted) {
        CustomSnackBar.successSnackBar(context, "Profile updated successfully");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        CustomSnackBar.errorSnackBar(context, "Error updating profile: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _isDarkMode ? _buildDarkTheme() : _buildLightTheme(),
      child: Scaffold(
        backgroundColor: _isDarkMode ? const Color(0xFF0A0E1A) : const Color(0xFFF8FAFC),
        body: _isLoading
            ? _buildLoadingScreen()
            : AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildModernHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: AnimatedBuilder(
                        animation: _slideAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _slideAnimation.value),
                            child: Column(
                              children: [
                                _buildProfileDetailsSection(),
                                const SizedBox(height: 100),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode
              ? [const Color(0xFF0A0E1A), const Color(0xFF1E293B)]
              : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isDarkMode ? Colors.white : Colors.white,
                ),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Updating profile...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16 * responsiveFontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    String? imageBase64 = widget.userData['image'];

    return Container(
      height: isTablet ? 320 : 280,
      width: double.infinity,
      child: Stack(
        children: [
          // Cover Image - LinkedIn/Facebook Style Banner
          Container(
            height: isTablet ? 200 : 160,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isDarkMode
                    ? [
                  const Color(0xFF1a202c),
                  const Color(0xFF2d3748),
                  const Color(0xFF4a5568),
                ]
                    : [
                  const Color(0xFF667eea),
                  const Color(0xFF764ba2),
                  const Color(0xFF6366F1),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Phoenician Logo as Cover Background
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                    ),
                    child: Center(
                      child: Container(
                        width: isTablet ? 280 : 220,
                        height: isTablet ? 120 : 95,
                        child: Image.asset(
                          'assets/images/ptslogo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF667eea),
                                    const Color(0xFF764ba2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'PHOENICIAN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: (isTablet ? 24 : 20) * responsiveFontSize,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // Subtle overlay for better contrast
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.1),
                          Colors.transparent,
                          Colors.black.withOpacity(0.2),
                        ],
                      ),
                    ),
                  ),
                ),

                // Top navigation overlay
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 80,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Navigation Bar
          SafeArea(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: responsivePadding.horizontal,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        if (_isEditing) {
                          _showDiscardDialog();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),

                  const Spacer(),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _isEditing ? "Edit Profile" : "Profile",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const Spacer(),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isEditing ? Icons.save : Icons.edit,
                        color: Colors.white,
                      ),
                      onPressed: _isEditing ? _saveProfile : _toggleEditing,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Profile Section - Overlapping the cover image
          Positioned(
            top: isTablet ? 120 : 100, // Overlap the cover image
            left: 0,
            right: 0,
            child: Container(
              padding: responsivePadding,
              child: Column(
                children: [
                  // Profile Picture with better shadow
                  Hero(
                    tag: 'profile_${widget.employeeId}',
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: isTablet ? 80 : 65,
                            backgroundColor: _isDarkMode
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
                            backgroundImage: imageBase64 != null
                                ? MemoryImage(base64Decode(imageBase64))
                                : null,
                            child: imageBase64 == null
                                ? Icon(
                              Icons.person,
                              color: _isDarkMode
                                  ? Colors.grey.shade300
                                  : Colors.grey,
                              size: isTablet ? 80 : 65,
                            )
                                : null,
                          ),
                          if (_isEditing)
                            Positioned(
                              bottom: 5,
                              right: 5,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.photo_camera,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Name Section
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Name
                        _isEditing
                            ? Container(
                          width: screenWidth * 0.8,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _isDarkMode
                                ? Colors.white.withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isDarkMode
                                  ? Colors.white.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _nameController,
                            style: TextStyle(
                              color: _isDarkMode ? Colors.white : Colors.black87,
                              fontSize: (isTablet ? 28 : 24) * responsiveFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: "Enter your name",
                              hintStyle: TextStyle(
                                color: _isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        )
                            : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: _isDarkMode
                                ? const Color(0xFF1E293B).withOpacity(0.8)
                                : Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            _nameController.text.isNotEmpty
                                ? _nameController.text
                                : "Employee Name",
                            style: TextStyle(
                              color: _isDarkMode ? Colors.white : Colors.black87,
                              fontSize: (isTablet ? 28 : 24) * responsiveFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Designation
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _designationController.text.isNotEmpty
                                ? _designationController.text
                                : "Employee",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
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

  Widget _buildProfileDetailsSection() {
    return Container(
      margin: responsivePadding,
      child: Column(
        children: [
          _buildModernSection(
            title: "Contact Information",
            icon: Icons.contact_phone,
            children: [
              _buildModernInfoField(
                label: "Phone",
                controller: _phoneController,
                icon: Icons.phone,
                isEditing: _isEditing,
                keyboardType: TextInputType.phone,
              ),
              _buildModernInfoField(
                label: "Email",
                controller: _emailController,
                icon: Icons.email,
                isEditing: _isEditing,
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),

          SizedBox(height: responsivePadding.vertical),

          _buildModernSection(
            title: "Work Information",
            icon: Icons.business_center,
            children: [
              _buildModernInfoField(
                label: "Department",
                controller: _departmentController,
                icon: Icons.business,
                isEditing: _isEditing,
              ),
              _buildModernInfoField(
                label: "Designation",
                controller: _designationController,
                icon: Icons.work,
                isEditing: _isEditing,
              ),
            ],
          ),

          SizedBox(height: responsivePadding.vertical),

          _buildModernSection(
            title: "Break Time Information",
            icon: Icons.schedule,
            children: [
              _buildModernTimeField(
                label: "Daily Break Time",
                startController: _breakStartTimeController,
                endController: _breakEndTimeController,
                icon: Icons.coffee,
                isEditing: _isEditing,
              ),

              if (_isEditing) ...[
                const SizedBox(height: 16),
                _buildModernSwitchTile(
                  title: "Friday Prayer Break",
                  subtitle: "Enable if you take Friday prayer break",
                  value: _hasJummaBreak,
                  onChanged: (value) {
                    setState(() {
                      _hasJummaBreak = value;
                      if (!value) {
                        _jummaBreakStartController.clear();
                        _jummaBreakEndController.clear();
                      }
                    });
                  },
                ),
              ],

              if (_hasJummaBreak) ...[
                const SizedBox(height: 16),
                _buildModernTimeField(
                  label: "Friday Prayer Break",
                  startController: _jummaBreakStartController,
                  endController: _jummaBreakEndController,
                  icon: Icons.mosque,
                  isEditing: _isEditing,
                ),
              ],
            ],
          ),

          SizedBox(height: responsivePadding.vertical),

          _buildModernSection(
            title: "Personal Information",
            icon: Icons.person,
            children: [
              _buildModernInfoField(
                label: "Birthdate",
                controller: _birthdateController,
                icon: Icons.cake,
                isEditing: _isEditing,
              ),
              _buildModernInfoField(
                label: "Country",
                controller: _countryController,
                icon: Icons.location_on,
                isEditing: _isEditing,
              ),
            ],
          ),

          if (_isEditing) ...[
            SizedBox(height: responsivePadding.vertical * 2),
            _buildModernSaveButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildModernSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode
                ? Colors.black.withOpacity(0.2)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: (isTablet ? 20 : 18) * responsiveFontSize,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            height: 1,
            color: _isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
          ),
          Padding(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isEditing,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                    fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                isEditing
                    ? TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "Enter $label",
                    hintStyle: TextStyle(
                      color: _isDarkMode
                          ? Colors.grey.shade500
                          : Colors.grey.shade400,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(
                    fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                )
                    : Text(
                  controller.text.isNotEmpty
                      ? controller.text
                      : "Not provided",
                  style: TextStyle(
                    fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                    color: controller.text.isNotEmpty
                        ? (_isDarkMode ? Colors.white : Colors.black87)
                        : (_isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTimeField({
    required String label,
    required TextEditingController startController,
    required TextEditingController endController,
    required IconData icon,
    required bool isEditing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: _isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                  fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTimeSelector(
                  controller: startController,
                  hint: "Start time",
                  isEditing: isEditing,
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "to",
                  style: TextStyle(
                    fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: _buildTimeSelector(
                  controller: endController,
                  hint: "End time",
                  isEditing: isEditing,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector({
    required TextEditingController controller,
    required String hint,
    required bool isEditing,
  }) {
    return GestureDetector(
      onTap: isEditing ? () => _selectTime(controller) : null,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 12,
          vertical: isTablet ? 12 : 10,
        ),
        decoration: BoxDecoration(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time,
              size: 16,
              color: _isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                controller.text.isNotEmpty ? controller.text : hint,
                style: TextStyle(
                  fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                  color: controller.text.isNotEmpty
                      ? (_isDarkMode ? Colors.white : Colors.black87)
                      : (_isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.mosque,
              color: Theme.of(context).colorScheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                    fontWeight: FontWeight.w600,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: (isTablet ? 12 : 11) * responsiveFontSize,
                    color: _isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildModernSaveButton() {
    return Container(
      width: double.infinity,
      height: isTablet ? 60 : 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _saveProfile,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.save,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  "Save Changes",
                  style: TextStyle(
                    fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Discard Changes?",
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Any unsaved changes will be lost. Are you sure you want to continue?",
          style: TextStyle(
            color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "Cancel",
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isEditing = false;
              });
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Discard"),
          ),
        ],
      ),
    );
  }
}