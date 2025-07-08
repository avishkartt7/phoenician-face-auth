// lib/leave/manager_leave_approval_view.dart - MODERN UI/UX DESIGN

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phoenician_face_auth/model/leave_application_model.dart';
import 'package:phoenician_face_auth/services/leave_application_service.dart';
import 'package:phoenician_face_auth/services/service_locator.dart';
import 'package:phoenician_face_auth/repositories/leave_application_repository.dart';
import 'package:phoenician_face_auth/services/connectivity_service.dart';
import 'package:phoenician_face_auth/common/utils/custom_snackbar.dart';

class ManagerLeaveApprovalView extends StatefulWidget {
  final String managerId;
  final String managerName;

  const ManagerLeaveApprovalView({
    Key? key,
    required this.managerId,
    required this.managerName,
  }) : super(key: key);

  @override
  State<ManagerLeaveApprovalView> createState() => _ManagerLeaveApprovalViewState();
}

class _ManagerLeaveApprovalViewState extends State<ManagerLeaveApprovalView>
    with SingleTickerProviderStateMixin {

  // Animation Controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // Service and State
  late LeaveApplicationService _leaveService;
  List<LeaveApplicationModel> _pendingApplications = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isDarkMode = false;

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

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadDarkModePreference();
    _initializeService();
    _loadPendingApplications();
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

  Future<void> _loadDarkModePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initializeService() {
    final repository = getIt<LeaveApplicationRepository>();
    final connectivityService = getIt<ConnectivityService>();

    _leaveService = LeaveApplicationService(
      repository: repository,
      connectivityService: connectivityService,
    );
  }

  Future<void> _loadPendingApplications() async {
    try {
      setState(() => _isLoading = true);

      final applications = await _leaveService.getPendingApplicationsForManager(widget.managerId);

      setState(() {
        _pendingApplications = applications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      CustomSnackBar.errorSnackBar("Error loading applications: $e");
    }
  }

  Future<void> _refreshApplications() async {
    try {
      setState(() => _isRefreshing = true);

      final applications = await _leaveService.getPendingApplicationsForManager(widget.managerId);

      setState(() {
        _pendingApplications = applications;
        _isRefreshing = false;
      });

      CustomSnackBar.successSnackBar("Applications refreshed");
    } catch (e) {
      setState(() => _isRefreshing = false);
      CustomSnackBar.errorSnackBar("Error refreshing: $e");
    }
  }

  // Modern Theme Builders (same as dashboard)
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

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        brightness: Brightness.dark,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: const Color(0xFF1E293B),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
    );
  }

  // Loading Screen (same as dashboard)
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
              'Loading leave applications...',
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

  // Modern Header Section
  Widget _buildModernHeader() {
    int totalDays = _pendingApplications.fold<int>(0, (sum, app) => sum + app.totalDays);
    int withCertificates = _pendingApplications.where((app) => app.certificateUrl != null).length;

    return Container(
      margin: responsivePadding,
      padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode
              ? [const Color(0xFF2D3748), const Color(0xFF4A5568)]
              : [const Color(0xFF667EEA), const Color(0xFF764BA2)],
        ),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black.withOpacity(0.3) : const Color(0xFF667EEA).withOpacity(0.3),
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
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.approval,
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
                          "Leave Approvals",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${_pendingApplications.length} Pending",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: (isTablet ? 32 : 28) * responsiveFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Refresh button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isRefreshing ? null : _refreshApplications,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.all(isTablet ? 12 : 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: _isRefreshing
                            ? SizedBox(
                          width: isTablet ? 24 : 20,
                          height: isTablet ? 24 : 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: isTablet ? 24 : 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: isTablet ? 24 : 20),

              // Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.pending_actions,
                      value: _pendingApplications.length.toString(),
                      label: "Applications",
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.calendar_today,
                      value: totalDays.toString(),
                      label: "Total Days",
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.attachment,
                      value: withCertificates.toString(),
                      label: "Certificates",
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: (isTablet ? 24 : 20) * responsiveFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
            ),
          ),
        ],
      ),
    );
  }

  // Modern Application Card
  Widget _buildApplicationCard(LeaveApplicationModel application) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Container(
            margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: _isDarkMode ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showApprovalDialog(application),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 20 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _getLeaveTypeColor(application.leaveType).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getLeaveTypeColor(application.leaveType).withOpacity(0.3),
                              ),
                            ),
                            child: Icon(
                              _getLeaveTypeIcon(application.leaveType),
                              color: _getLeaveTypeColor(application.leaveType),
                              size: isTablet ? 24 : 20,
                            ),
                          ),
                          SizedBox(width: isTablet ? 16 : 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  application.employeeName,
                                  style: TextStyle(
                                    fontSize: (isTablet ? 20 : 18) * responsiveFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: _isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  application.leaveType.displayName,
                                  style: TextStyle(
                                    color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                    fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Status badges
                          Column(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isTablet ? 12 : 10,
                                  vertical: isTablet ? 6 : 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                ),
                                child: Text(
                                  'PENDING',
                                  style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontSize: (isTablet ? 12 : 10) * responsiveFontSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (application.certificateUrl != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 8 : 6,
                                    vertical: isTablet ? 4 : 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.attachment,
                                        size: isTablet ? 14 : 12,
                                        color: Colors.green.shade700,
                                      ),
                                      SizedBox(width: isTablet ? 4 : 2),
                                      Text(
                                        'Certificate',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontSize: (isTablet ? 10 : 8) * responsiveFontSize,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),

                      SizedBox(height: isTablet ? 20 : 16),

                      // Details Section
                      Container(
                        padding: EdgeInsets.all(isTablet ? 16 : 14),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    application.dateRange,
                                    style: TextStyle(
                                      fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                                      fontWeight: FontWeight.w600,
                                      color: _isDarkMode ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 12 : 10,
                                    vertical: isTablet ? 6 : 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${application.totalDays} days',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Applied: ${DateFormat('dd/MM/yyyy').format(application.applicationDate)}',
                                  style: TextStyle(
                                    color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                    fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                                  ),
                                ),
                              ],
                            ),
                            if (application.isAlreadyTaken) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.orange.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Already taken leave',
                                    style: TextStyle(
                                      color: Colors.orange.shade600,
                                      fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      SizedBox(height: isTablet ? 16 : 12),

                      // Reason
                      Text(
                        'Reason:',
                        style: TextStyle(
                          fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        application.reason,
                        style: TextStyle(
                          fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                          color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),

                      SizedBox(height: isTablet ? 20 : 16),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _processDecision(application, false, ''),
                              icon: Icon(
                                Icons.close,
                                size: isTablet ? 20 : 16,
                              ),
                              label: Text(
                                'Reject',
                                style: TextStyle(fontSize: (isTablet ? 16 : 14) * responsiveFontSize),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: EdgeInsets.symmetric(vertical: isTablet ? 12 : 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: isTablet ? 16 : 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showApprovalDialog(application),
                              icon: Icon(
                                Icons.visibility,
                                size: isTablet ? 20 : 16,
                              ),
                              label: Text(
                                'Review',
                                style: TextStyle(fontSize: (isTablet ? 16 : 14) * responsiveFontSize),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: isTablet ? 12 : 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Enhanced approval dialog with modern design
  Future<void> _showApprovalDialog(LeaveApplicationModel application) async {
    final TextEditingController commentsController = TextEditingController();
    bool? approved;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: isTablet ? 600 : double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.85,
          ),
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(isTablet ? 24 : 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.approval,
                        color: Colors.white,
                        size: isTablet ? 24 : 20,
                      ),
                    ),
                    SizedBox(width: isTablet ? 16 : 12),
                    Expanded(
                      child: Text(
                        'Review Leave Application',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: (isTablet ? 22 : 20) * responsiveFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isTablet ? 24 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Employee info
                      Container(
                        padding: EdgeInsets.all(isTablet ? 16 : 14),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow('Employee', application.employeeName),
                            _buildDetailRow('Leave Type', application.leaveType.displayName),
                            _buildDetailRow('Dates', application.dateRange),
                            _buildDetailRow('Total Days', '${application.totalDays} days'),
                            _buildDetailRow('Applied On', DateFormat('dd/MM/yyyy HH:mm').format(application.applicationDate)),
                          ],
                        ),
                      ),

                      SizedBox(height: isTablet ? 20 : 16),

                      // Reason section
                      Text(
                        'Reason:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(height: isTablet ? 12 : 8),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isTablet ? 16 : 14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          application.reason,
                          style: TextStyle(
                            fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                            color: _isDarkMode ? Colors.white : Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),

                      // Certificate section
                      if (application.certificateUrl != null) ...[
                        SizedBox(height: isTablet ? 20 : 16),
                        _buildCertificateSection(application),
                      ],

                      // Already taken notice
                      if (application.isAlreadyTaken) ...[
                        SizedBox(height: isTablet ? 16 : 12),
                        Container(
                          padding: EdgeInsets.all(isTablet ? 16 : 12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: isTablet ? 24 : 20,
                                color: Colors.orange.shade700,
                              ),
                              SizedBox(width: isTablet ? 12 : 8),
                              Expanded(
                                child: Text(
                                  'This is for leave already taken',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: isTablet ? 20 : 16),

                      // Comments section
                      Text(
                        'Comments (Optional)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(height: isTablet ? 12 : 8),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isDarkMode ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: TextField(
                          controller: commentsController,
                          maxLines: isTablet ? 4 : 3,
                          style: TextStyle(
                            fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                            color: _isDarkMode ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add any comments about your decision...',
                            hintStyle: TextStyle(
                              fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                              color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(isTablet ? 16 : 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action buttons
              Container(
                padding: EdgeInsets.all(isTablet ? 24 : 20),
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                          side: BorderSide(
                            color: _isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300,
                          ),
                          padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(fontSize: (isTablet ? 16 : 14) * responsiveFontSize),
                        ),
                      ),
                    ),
                    SizedBox(width: isTablet ? 16 : 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          approved = false;
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Reject',
                          style: TextStyle(fontSize: (isTablet ? 16 : 14) * responsiveFontSize),
                        ),
                      ),
                    ),
                    SizedBox(width: isTablet ? 16 : 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          approved = true;
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Approve',
                          style: TextStyle(fontSize: (isTablet ? 16 : 14) * responsiveFontSize),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (approved != null) {
      await _processDecision(application, approved!, commentsController.text);
    }
  }

  // Certificate section with modern design
  Widget _buildCertificateSection(LeaveApplicationModel application) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.attachment,
                  size: isTablet ? 20 : 16,
                  color: Colors.green.shade700,
                ),
              ),
              SizedBox(width: isTablet ? 12 : 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Certificate Attached',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (application.certificateFileName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        application.certificateFileName!,
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: isTablet ? 16 : 12),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _viewCertificate(application.certificateUrl!),
                  icon: Icon(
                    Icons.visibility,
                    size: isTablet ? 18 : 16,
                  ),
                  label: Text(
                    'View Certificate',
                    style: TextStyle(fontSize: (isTablet ? 14 : 12) * responsiveFontSize),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isTablet ? 12 : 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              SizedBox(width: isTablet ? 12 : 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _downloadCertificate(application.certificateUrl!, application.certificateFileName),
                  icon: Icon(
                    Icons.download,
                    size: isTablet ? 18 : 16,
                  ),
                  label: Text(
                    'Download',
                    style: TextStyle(fontSize: (isTablet ? 14 : 12) * responsiveFontSize),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade700,
                    side: BorderSide(color: Colors.green.shade400),
                    padding: EdgeInsets.symmetric(vertical: isTablet ? 12 : 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTablet ? 8 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isTablet ? 120 : 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Empty state with modern design
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 32 : 24),
            decoration: BoxDecoration(
              color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: isTablet ? 80 : 64,
              color: _isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ),
          SizedBox(height: isTablet ? 24 : 20),
          Text(
            'All Caught Up!',
            style: TextStyle(
              fontSize: (isTablet ? 24 : 20) * responsiveFontSize,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: isTablet ? 12 : 8),
          Text(
            'No pending leave applications to review',
            style: TextStyle(
              color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isTablet ? 32 : 24),
          ElevatedButton.icon(
            onPressed: _refreshApplications,
            icon: Icon(
              Icons.refresh,
              size: isTablet ? 24 : 20,
            ),
            label: Text(
              'Refresh',
              style: TextStyle(fontSize: (isTablet ? 16 : 14) * responsiveFontSize),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 32 : 24,
                vertical: isTablet ? 16 : 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Future<void> _viewCertificate(String certificateUrl) async {
    try {
      final Uri url = Uri.parse(certificateUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        CustomSnackBar.errorSnackBar("Cannot open certificate. URL may be invalid.");
      }
    } catch (e) {
      CustomSnackBar.errorSnackBar("Error opening certificate: $e");
    }
  }

  Future<void> _downloadCertificate(String certificateUrl, String? fileName) async {
    try {
      final Uri url = Uri.parse(certificateUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        CustomSnackBar.successSnackBar("Certificate download started");
      } else {
        CustomSnackBar.errorSnackBar("Cannot download certificate. URL may be invalid.");
      }
    } catch (e) {
      CustomSnackBar.errorSnackBar("Error downloading certificate: $e");
    }
  }

  Future<void> _processDecision(
      LeaveApplicationModel application,
      bool isApproved,
      String comments,
      ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(height: isTablet ? 20 : 16),
                Text(
                  'Processing decision...',
                  style: TextStyle(
                    fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      bool success;
      if (isApproved) {
        success = await _leaveService.approveLeaveApplication(
          application.id!,
          widget.managerId,
          comments: comments.isNotEmpty ? comments : null,
        );
      } else {
        success = await _leaveService.rejectLeaveApplication(
          application.id!,
          widget.managerId,
          comments: comments.isNotEmpty ? comments : null,
        );
      }

      Navigator.pop(context); // Close loading dialog

      if (success) {
        CustomSnackBar.successSnackBar(
            'Application ${isApproved ? 'approved' : 'rejected'} successfully'
        );

        setState(() {
          _pendingApplications.removeWhere((app) => app.id == application.id);
        });
      } else {
        CustomSnackBar.errorSnackBar('Failed to process decision');
      }
    } catch (e) {
      Navigator.pop(context);
      CustomSnackBar.errorSnackBar('Error: $e');
    }
  }

  Color _getLeaveTypeColor(LeaveType type) {
    switch (type) {
      case LeaveType.annual:
        return Colors.blue;
      case LeaveType.sick:
        return Colors.red;
      case LeaveType.maternity:
        return Colors.pink;
      case LeaveType.paternity:
        return Colors.indigo;
      case LeaveType.emergency:
        return Colors.orange;
      case LeaveType.compensate:
        return Colors.green;
      case LeaveType.unpaid:
        return Colors.grey;
    }
  }

  IconData _getLeaveTypeIcon(LeaveType type) {
    switch (type) {
      case LeaveType.annual:
        return Icons.beach_access;
      case LeaveType.sick:
        return Icons.local_hospital;
      case LeaveType.maternity:
        return Icons.child_care;
      case LeaveType.paternity:
        return Icons.family_restroom;
      case LeaveType.emergency:
        return Icons.emergency;
      case LeaveType.compensate:
        return Icons.schedule;
      case LeaveType.unpaid:
        return Icons.money_off;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set context for snackbar
    if (CustomSnackBar.context == null) {
      CustomSnackBar.context = context;
    }

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
              child: SafeArea(
                child: Column(
                  children: [
                    // Back button
                    Padding(
                      padding: responsivePadding,
                      child: Row(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: EdgeInsets.all(isTablet ? 12 : 10),
                                decoration: BoxDecoration(
                                  color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
                                  ),
                                ),
                                child: Icon(
                                  Icons.arrow_back,
                                  color: _isDarkMode ? Colors.white : Colors.black87,
                                  size: isTablet ? 24 : 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Header
                    _buildModernHeader(),

                    SizedBox(height: responsivePadding.vertical),

                    // Applications list
                    Expanded(
                      child: _pendingApplications.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                        onRefresh: _refreshApplications,
                        color: Theme.of(context).colorScheme.primary,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: responsivePadding.horizontal),
                          itemCount: _pendingApplications.length,
                          itemBuilder: (context, index) {
                            final application = _pendingApplications[index];
                            return _buildApplicationCard(application);
                          },
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
}