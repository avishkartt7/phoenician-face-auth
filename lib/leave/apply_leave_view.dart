// lib/leave/apply_leave_view.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:phoenician_face_auth/model/leave_application_model.dart';
import 'package:phoenician_face_auth/model/leave_balance_model.dart';
import 'package:phoenician_face_auth/services/leave_application_service.dart';
import 'package:phoenician_face_auth/services/service_locator.dart';
import 'package:phoenician_face_auth/repositories/leave_application_repository.dart';
import 'package:phoenician_face_auth/services/connectivity_service.dart';
import 'package:phoenician_face_auth/common/utils/custom_snackbar.dart';

class ApplyLeaveView extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final String employeePin;
  final Map<String, dynamic> userData;

  const ApplyLeaveView({
    Key? key,
    required this.employeeId,
    required this.employeeName,
    required this.employeePin,
    required this.userData,
  }) : super(key: key);

  @override
  State<ApplyLeaveView> createState() => _ApplyLeaveViewState();
}

class _ApplyLeaveViewState extends State<ApplyLeaveView>
    with TickerProviderStateMixin {

  // Animation Controllers
  late AnimationController _animationController;
  late AnimationController _submitController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;

  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  // Form fields
  LeaveType _selectedLeaveType = LeaveType.annual;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isAlreadyTaken = false;
  File? _certificateFile;
  String? _certificateFileName;

  // State management
  bool _isSubmitting = false;
  bool _isLoadingBalance = true;
  LeaveBalance? _leaveBalance;
  late LeaveApplicationService _leaveService;
  bool _isDarkMode = false;

  // Calculated values
  int _totalDays = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeService();
    _loadLeaveBalance();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _submitController = AnimationController(
      duration: const Duration(milliseconds: 300),
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

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _submitController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _submitController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  // Responsive design helpers
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

  void _initializeService() {
    final repository = getIt<LeaveApplicationRepository>();
    final connectivityService = getIt<ConnectivityService>();

    _leaveService = LeaveApplicationService(
      repository: repository,
      connectivityService: connectivityService,
    );
  }

  Future<void> _loadLeaveBalance() async {
    try {
      setState(() => _isLoadingBalance = true);

      final balance = await _leaveService.getLeaveBalance(widget.employeeId);

      setState(() {
        _leaveBalance = balance;
        _isLoadingBalance = false;
      });
    } catch (e) {
      setState(() => _isLoadingBalance = false);
      debugPrint("Error loading leave balance: $e");
    }
  }

  void _calculateTotalDays() {
    if (_startDate != null && _endDate != null) {
      setState(() {
        _totalDays = _leaveService.calculateTotalDays(_startDate!, _endDate!);
      });
      _submitController.forward().then((_) => _submitController.reverse());
    }
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: _isAlreadyTaken ? DateTime(2020) : DateTime.now(),
      lastDate: DateTime(2030),
      helpText: _isAlreadyTaken ? 'Select past start date' : 'Select start date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
          _totalDays = 0;
        } else {
          _calculateTotalDays();
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? (_isAlreadyTaken ? DateTime(2020) : DateTime.now()),
      lastDate: DateTime(2030),
      helpText: _isAlreadyTaken ? 'Select past end date' : 'Select end date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
        _calculateTotalDays();
      });
    }
  }

  Future<void> _pickCertificate() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _certificateFile = File(result.files.single.path!);
          _certificateFileName = result.files.single.name;
        });

        CustomSnackBar.successSnackBar("Certificate selected: ${result.files.single.name}");
      }
    } catch (e) {
      CustomSnackBar.errorSnackBar("Error selecting certificate: $e");
    }
  }

  void _removeCertificate() {
    setState(() {
      _certificateFile = null;
      _certificateFileName = null;
    });
  }

  bool _isCertificateRequired() {
    return _leaveService.isCertificateRequired(_selectedLeaveType, _isAlreadyTaken);
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (_startDate == null) {
      CustomSnackBar.errorSnackBar("Please select start date");
      return false;
    }

    if (_endDate == null) {
      CustomSnackBar.errorSnackBar("Please select end date");
      return false;
    }

    if (_startDate!.isAfter(_endDate!)) {
      CustomSnackBar.errorSnackBar("Start date cannot be after end date");
      return false;
    }

    if (!_isAlreadyTaken && !_leaveService.validateLeaveDates(_startDate!, _endDate!)) {
      CustomSnackBar.errorSnackBar("Leave dates cannot be in the past");
      return false;
    }

    if (_isAlreadyTaken && !_leaveService.areDatesInPast(_startDate!, _endDate!)) {
      CustomSnackBar.errorSnackBar("For already taken leave, dates must be in the past");
      return false;
    }

    if (_isCertificateRequired() && _certificateFile == null) {
      String reason = '';
      if (_selectedLeaveType == LeaveType.sick) {
        reason = 'medical certificate for sick leave';
      } else if (_isAlreadyTaken) {
        reason = 'certificate for already taken leave';
      }
      CustomSnackBar.errorSnackBar("Please upload $reason");
      return false;
    }

    if (_leaveBalance != null && !_leaveBalance!.hasEnoughBalance(_selectedLeaveType.name, _totalDays)) {
      final remaining = _leaveBalance!.getRemainingDays(_selectedLeaveType.name);
      CustomSnackBar.errorSnackBar("Insufficient leave balance. Available: $remaining days, Requested: $_totalDays days");
      return false;
    }

    return true;
  }

  Future<void> _submitApplication() async {
    if (!_validateForm()) return;

    setState(() => _isSubmitting = true);

    try {
      final applicationId = await _leaveService.submitLeaveApplication(
        employeeId: widget.employeeId,
        employeeName: widget.employeeName,
        employeePin: widget.employeePin,
        leaveType: _selectedLeaveType,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text.trim(),
        isAlreadyTaken: _isAlreadyTaken,
        certificateFile: _certificateFile,
      );

      if (applicationId != null) {
        CustomSnackBar.successSnackBar("Leave application submitted successfully!");
        Navigator.of(context).pop(true);
      } else {
        CustomSnackBar.errorSnackBar("Failed to submit leave application");
      }
    } catch (e) {
      CustomSnackBar.errorSnackBar("Error: $e");
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _buildLightTheme(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SafeArea(
                child: Column(
                  children: [
                    _buildModernHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              SizedBox(height: responsivePadding.vertical),
                              _buildBalanceCard(),
                              SizedBox(height: responsivePadding.vertical),
                              _buildLeaveTypeSection(),
                              SizedBox(height: responsivePadding.vertical),
                              _buildAlreadyTakenSection(),
                              SizedBox(height: responsivePadding.vertical),
                              _buildDateSelectionSection(),
                              SizedBox(height: responsivePadding.vertical),
                              if (_totalDays > 0) _buildDaysCalculationCard(),
                              if (_totalDays > 0) SizedBox(height: responsivePadding.vertical),
                              _buildReasonSection(),
                              SizedBox(height: responsivePadding.vertical),
                              if (_isCertificateRequired()) _buildCertificateSection(),
                              if (_isCertificateRequired()) SizedBox(height: responsivePadding.vertical),
                              _buildSubmitButton(),
                              SizedBox(height: responsivePadding.vertical + 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        brightness: Brightness.light,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      margin: responsivePadding,
      padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.all(isTablet ? 12 : 10),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.2),
                  ),
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: Colors.black87,
                  size: isTablet ? 24 : 20,
                ),
              ),
            ),
          ),
          SizedBox(width: isTablet ? 20 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Apply for Leave",
                  style: TextStyle(
                    fontSize: (isTablet ? 24 : 20) * responsiveFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Submit your leave application",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.event_available,
              color: Theme.of(context).colorScheme.primary,
              size: isTablet ? 28 : 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Container(
            margin: responsivePadding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF667EEA),
                  const Color(0xFF764BA2),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667EEA).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 28 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leave Balance (${DateTime.now().year})',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (isTablet ? 22 : 18) * responsiveFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: isTablet ? 20 : 16),
                    if (_isLoadingBalance)
                      Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    else if (_leaveBalance != null)
                      _buildBalanceGrid()
                    else
                      Text(
                        'Unable to load balance',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalanceGrid() {
    final summary = _leaveBalance!.getSummary();
    final displayTypes = ['annual', 'sick', 'emergency', 'maternity', 'paternity', 'compensate'];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 3 : 2,
        childAspectRatio: isTablet ? 2.2 : 2.0,
        crossAxisSpacing: isTablet ? 16 : 12,
        mainAxisSpacing: isTablet ? 16 : 12,
      ),
      itemCount: displayTypes.length,
      itemBuilder: (context, index) {
        final type = displayTypes[index];
        final balance = summary[type];
        final remaining = balance?['remaining'] ?? 0;
        final total = balance?['total'] ?? 0;
        final pending = balance?['pending'] ?? 0;

        return Container(
          padding: EdgeInsets.all(isTablet ? 16 : 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type.toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: (isTablet ? 12 : 10) * responsiveFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '$remaining/$total',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                pending > 0 ? '($pending pending)' : 'available',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: (isTablet ? 11 : 9) * responsiveFontSize,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernCard({required Widget child}) {
    return Container(
      margin: responsivePadding,
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildLeaveTypeSection() {
    return _buildModernCard(
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
                  Icons.category_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Leave Type',
                style: TextStyle(
                  fontSize: (isTablet ? 20 : 18) * responsiveFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 20 : 16),
          DropdownButtonFormField<LeaveType>(
            value: _selectedLeaveType,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 20 : 16,
              ),
            ),
            items: LeaveType.values.map((type) {
              return DropdownMenuItem<LeaveType>(
                value: type,
                child: Text(
                  type.displayName,
                  style: TextStyle(
                    fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
            onChanged: (LeaveType? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedLeaveType = newValue;
                  if (!_isCertificateRequired()) {
                    _certificateFile = null;
                    _certificateFileName = null;
                  }
                });
              }
            },
            validator: (value) {
              if (value == null) return 'Please select leave type';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyTakenSection() {
    return _buildModernCard(
      child: Row(
        children: [
          Transform.scale(
            scale: isTablet ? 1.3 : 1.1,
            child: Checkbox(
              value: _isAlreadyTaken,
              onChanged: (bool? value) {
                setState(() {
                  _isAlreadyTaken = value ?? false;
                  _startDate = null;
                  _endDate = null;
                  _totalDays = 0;
                  if (!_isCertificateRequired()) {
                    _certificateFile = null;
                    _certificateFileName = null;
                  }
                });
              },
              activeColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This is for leave already taken',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: isTablet ? 8 : 4),
                Text(
                  'Check this if you\'re applying for leave that has already been taken',
                  style: TextStyle(
                    fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelectionSection() {
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.date_range,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Leave Dates',
                style: TextStyle(
                  fontSize: (isTablet ? 20 : 18) * responsiveFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 20 : 16),
          if (isTablet)
            Row(
              children: [
                Expanded(child: _buildDateField('Start Date', _startDate, _selectStartDate)),
                const SizedBox(width: 20),
                Expanded(child: _buildDateField('End Date', _endDate, _selectEndDate)),
              ],
            )
          else
            Column(
              children: [
                _buildDateField('Start Date', _startDate, _selectStartDate),
                const SizedBox(height: 16),
                _buildDateField('End Date', _endDate, _selectEndDate),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDateField(String label, DateTime? date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: isTablet ? 10 : 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(isTablet ? 18 : 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey.shade50,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: isTablet ? 20 : 18,
                    color: date != null ? Theme.of(context).colorScheme.primary : Colors.grey.shade600,
                  ),
                  SizedBox(width: isTablet ? 12 : 10),
                  Expanded(
                    child: Text(
                      date != null ? DateFormat('dd/MM/yyyy').format(date) : 'Select date',
                      style: TextStyle(
                        color: date != null ? Colors.black87 : Colors.grey.shade600,
                        fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                        fontWeight: date != null ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDaysCalculationCard() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: responsivePadding,
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.indigo.shade500],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.calculate_outlined,
                    color: Colors.white,
                    size: isTablet ? 32 : 28,
                  ),
                ),
                SizedBox(width: isTablet ? 20 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Days: $_totalDays',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: (isTablet ? 22 : 18) * responsiveFontSize,
                        ),
                      ),
                      if (_leaveBalance != null) ...[
                        SizedBox(height: isTablet ? 8 : 4),
                        Text(
                          'Remaining ${_selectedLeaveType.displayName}: ${_leaveBalance!.getRemainingDays(_selectedLeaveType.name)} days',
                          style: TextStyle(
                            fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReasonSection() {
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.edit_note,
                  color: Colors.orange.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Reason for Leave',
                style: TextStyle(
                  fontSize: (isTablet ? 20 : 18) * responsiveFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 20 : 16),
          TextFormField(
            controller: _reasonController,
            maxLines: isTablet ? 5 : 4,
            style: TextStyle(fontSize: (isTablet ? 16 : 14) * responsiveFontSize),
            decoration: InputDecoration(
              hintText: 'Please provide a detailed reason for your leave (minimum 10 characters)...',
              hintStyle: TextStyle(
                fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                color: Colors.grey.shade500,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: EdgeInsets.all(isTablet ? 20 : 16),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please provide a reason for leave';
              }
              if (value.trim().length < 10) {
                return 'Please provide a more detailed reason (minimum 10 characters)';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateSection() {
    String requirement = '';
    if (_selectedLeaveType == LeaveType.sick) {
      requirement = 'Medical certificate is required for sick leave';
    } else if (_isAlreadyTaken) {
      requirement = 'Certificate is required for already taken leave';
    }

    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.attach_file,
                  color: Colors.red.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Certificate Upload',
                  style: TextStyle(
                    fontSize: (isTablet ? 20 : 18) * responsiveFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 12 : 10,
                  vertical: isTablet ? 6 : 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Required',
                  style: TextStyle(
                    fontSize: (isTablet ? 12 : 10) * responsiveFontSize,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 16 : 12),
          Text(
            requirement,
            style: TextStyle(
              fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: isTablet ? 20 : 16),
          if (_certificateFile == null)
            SizedBox(
              width: double.infinity,
              height: isTablet ? 60 : 50,
              child: OutlinedButton.icon(
                onPressed: _pickCertificate,
                icon: Icon(
                  Icons.cloud_upload_outlined,
                  size: isTablet ? 24 : 20,
                ),
                label: Text(
                  'Upload Certificate',
                  style: TextStyle(
                    fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: isTablet ? 28 : 24,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _certificateFileName ?? 'Selected file',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                            fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                          ),
                        ),
                        Text(
                          'Certificate uploaded successfully',
                          style: TextStyle(
                            fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _removeCertificate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.close,
                          color: Colors.red.shade600,
                          size: isTablet ? 24 : 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      margin: responsivePadding,
      child: SizedBox(
        width: double.infinity,
        height: isTablet ? 64 : 56,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitApplication,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isSubmitting
                ? Colors.grey.withOpacity(0.5)
                : Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: _isSubmitting ? 0 : 8,
            shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
          child: _isSubmitting
              ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: isTablet ? 24 : 20,
                height: isTablet ? 24 : 20,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Text(
                'Submitting Application...',
                style: TextStyle(
                  fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.send_rounded,
                size: isTablet ? 24 : 20,
              ),
              SizedBox(width: isTablet ? 12 : 8),
              Text(
                'Submit Application',
                style: TextStyle(
                  fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}