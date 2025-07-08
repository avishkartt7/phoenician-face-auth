// lib/leave/leave_history_view.dart - MODERN UI/UX DESIGN WITH OVERFLOW FIXES

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phoenician_face_auth/model/leave_application_model.dart';
import 'package:phoenician_face_auth/model/leave_balance_model.dart';
import 'package:phoenician_face_auth/services/leave_application_service.dart';
import 'package:phoenician_face_auth/services/service_locator.dart';
import 'package:phoenician_face_auth/repositories/leave_application_repository.dart';
import 'package:phoenician_face_auth/services/connectivity_service.dart';
import 'package:phoenician_face_auth/common/utils/custom_snackbar.dart';
import 'package:phoenician_face_auth/leave/apply_leave_view.dart';

class LeaveHistoryView extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final String employeePin;
  final Map<String, dynamic> userData;

  const LeaveHistoryView({
    Key? key,
    required this.employeeId,
    required this.employeeName,
    required this.employeePin,
    required this.userData,
  }) : super(key: key);

  @override
  State<LeaveHistoryView> createState() => _LeaveHistoryViewState();
}

class _LeaveHistoryViewState extends State<LeaveHistoryView>
    with TickerProviderStateMixin {

  // Animation Controllers
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  // Tab Controller
  late TabController _tabController;

  // Service and State
  late LeaveApplicationService _leaveService;
  List<LeaveApplicationModel> _allApplications = [];
  List<LeaveApplicationModel> _pendingApplications = [];
  List<LeaveApplicationModel> _approvedApplications = [];
  List<LeaveApplicationModel> _rejectedApplications = [];
  LeaveBalance? _leaveBalance;
  Map<String, dynamic> _statistics = {};

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
    _tabController = TabController(length: 4, vsync: this);
    _initializeAnimations();
    _loadDarkModePreference();
    _initializeService();
    _loadData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
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

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
    _pulseController.repeat(reverse: true);
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
    _pulseController.dispose();
    _tabController.dispose();
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

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Load all data in parallel
      final futures = await Future.wait([
        _leaveService.getEmployeeLeaveApplications(widget.employeeId),
        _leaveService.getLeaveBalance(widget.employeeId),
        _leaveService.getLeaveStatistics(widget.employeeId),
      ]);

      final applications = futures[0] as List<LeaveApplicationModel>;
      final balance = futures[1] as LeaveBalance?;
      final statistics = futures[2] as Map<String, dynamic>;

      setState(() {
        _allApplications = applications;
        _pendingApplications = applications
            .where((app) => app.status == LeaveStatus.pending)
            .toList();
        _approvedApplications = applications
            .where((app) => app.status == LeaveStatus.approved)
            .toList();
        _rejectedApplications = applications
            .where((app) => app.status == LeaveStatus.rejected)
            .toList();
        _leaveBalance = balance;
        _statistics = statistics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      CustomSnackBar.errorSnackBar("Error loading data: $e");
    }
  }

  Future<void> _refreshData() async {
    try {
      setState(() => _isRefreshing = true);
      await _loadData();
      setState(() => _isRefreshing = false);
      CustomSnackBar.successSnackBar("Data refreshed");
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
              'Loading leave history...',
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

  // Modern Header
  Widget _buildModernHeader() {
    int totalApplications = _statistics['totalApplications'] ?? 0;
    int totalDaysApproved = _statistics['totalDaysApproved'] ?? 0;

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
                      Icons.history,
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
                          "Leave Management",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Track Your Applications",
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
                      onTap: _isRefreshing ? null : _refreshData,
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
                      icon: Icons.description_outlined,
                      value: totalApplications.toString(),
                      label: "Applications",
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.check_circle_outline,
                      value: totalDaysApproved.toString(),
                      label: "Days Approved",
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.pending_actions,
                      value: _pendingApplications.length.toString(),
                      label: "Pending",
                      color: Colors.orange,
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
        mainAxisSize: MainAxisSize.min,
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
              fontSize: (isTablet ? 20 : 16) * responsiveFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: (isTablet ? 12 : 10) * responsiveFontSize,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Leave Balance Card with modern design
  Widget _buildLeaveBalanceCard() {
    if (_leaveBalance == null) {
      return Container(
        margin: responsivePadding,
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          ),
        ),
        child: Center(
          child: Text(
            'Unable to load leave balance',
            style: TextStyle(
              color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
            ),
          ),
        ),
      );
    }

    final summary = _leaveBalance!.getSummary();
    final displayTypes = ['annual', 'sick', 'emergency', 'maternity', 'paternity', 'compensate'];

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
                  Colors.green.shade400,
                  Colors.teal.shade500,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
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
                    GridView.builder(
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                type.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: (isTablet ? 12 : 10) * responsiveFontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
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

  // Modern Tab Bar
  Widget _buildModernTabBar() {
    return Container(
      margin: responsivePadding,
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorPadding: EdgeInsets.all(isTablet ? 8 : 6),
        labelColor: Colors.white,
        unselectedLabelColor: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
        labelStyle: TextStyle(
          fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
          fontWeight: FontWeight.w500,
        ),
        isScrollable: !isTablet,
        tabs: [
          Tab(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12,
                vertical: isTablet ? 12 : 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.dashboard_outlined, size: isTablet ? 20 : 16),
                  if (isTablet) ...[
                    const SizedBox(width: 8),
                    Text('Overview'),
                  ],
                ],
              ),
            ),
          ),
          Tab(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12,
                vertical: isTablet ? 12 : 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pending_outlined, size: isTablet ? 20 : 16),
                  if (isTablet) ...[
                    const SizedBox(width: 8),
                    Text('Pending (${_pendingApplications.length})'),
                  ] else ...[
                    const SizedBox(width: 4),
                    Text('${_pendingApplications.length}'),
                  ],
                ],
              ),
            ),
          ),
          Tab(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12,
                vertical: isTablet ? 12 : 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: isTablet ? 20 : 16),
                  if (isTablet) ...[
                    const SizedBox(width: 8),
                    Text('Approved (${_approvedApplications.length})'),
                  ] else ...[
                    const SizedBox(width: 4),
                    Text('${_approvedApplications.length}'),
                  ],
                ],
              ),
            ),
          ),
          Tab(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12,
                vertical: isTablet ? 12 : 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cancel_outlined, size: isTablet ? 20 : 16),
                  if (isTablet) ...[
                    const SizedBox(width: 8),
                    Text('Rejected (${_rejectedApplications.length})'),
                  ] else ...[
                    const SizedBox(width: 4),
                    Text('${_rejectedApplications.length}'),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Modern Application Card
  Widget _buildApplicationCard(LeaveApplicationModel application, bool canCancel) {
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
                          color: _getStatusColor(application.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor(application.status).withOpacity(0.3),
                          ),
                        ),
                        child: Icon(
                          _getStatusIcon(application.status),
                          color: _getStatusColor(application.status),
                          size: isTablet ? 24 : 20,
                        ),
                      ),
                      SizedBox(width: isTablet ? 16 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              application.leaveType.displayName,
                              style: TextStyle(
                                fontSize: (isTablet ? 20 : 18) * responsiveFontSize,
                                fontWeight: FontWeight.bold,
                                color: _isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              application.dateRange,
                              style: TextStyle(
                                color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 12 : 10,
                          vertical: isTablet ? 6 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(application.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _getStatusColor(application.status).withOpacity(0.3)),
                        ),
                        child: Text(
                          application.status.displayName.toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(application.status),
                            fontSize: (isTablet ? 12 : 10) * responsiveFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                              Icons.access_time,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${application.totalDays} days',
                                style: TextStyle(
                                  fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                                  fontWeight: FontWeight.w600,
                                  color: _isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            Text(
                              'Applied: ${DateFormat('dd/MM/yyyy').format(application.applicationDate)}',
                              style: TextStyle(
                                color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                              ),
                            ),
                          ],
                        ),
                        if (application.certificateUrl != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.attachment,
                                size: 16,
                                color: Colors.green.shade600,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Certificate attached',
                                style: TextStyle(
                                  color: Colors.green.shade600,
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

                  // Manager Comments
                  if (application.reviewComments != null && application.reviewComments!.isNotEmpty) ...[
                    SizedBox(height: isTablet ? 16 : 12),
                    Container(
                      padding: EdgeInsets.all(isTablet ? 16 : 12),
                      decoration: BoxDecoration(
                        color: application.status == LeaveStatus.approved
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: application.status == LeaveStatus.approved
                              ? Colors.green.withOpacity(0.3)
                              : Colors.red.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.comment,
                                size: 16,
                                color: application.status == LeaveStatus.approved
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Manager Comments:',
                                style: TextStyle(
                                  fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: application.status == LeaveStatus.approved
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            application.reviewComments!,
                            style: TextStyle(
                              fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                              color: application.status == LeaveStatus.approved
                                  ? Colors.green.shade600
                                  : Colors.red.shade600,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Cancel button for pending applications
                  if (canCancel && application.status == LeaveStatus.pending) ...[
                    SizedBox(height: isTablet ? 20 : 16),
                    SizedBox(
                      width: double.infinity,
                      height: isTablet ? 50 : 44,
                      child: OutlinedButton.icon(
                        onPressed: () => _showCancelDialog(application),
                        icon: Icon(
                          Icons.cancel_outlined,
                          size: isTablet ? 20 : 16,
                        ),
                        label: Text(
                          'Cancel Application',
                          style: TextStyle(fontSize: (isTablet ? 16 : 14) * responsiveFontSize),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
      },
    );
  }

  // Applications List with proper overflow handling
  Widget _buildApplicationsList(List<LeaveApplicationModel> applications, bool canCancel) {
    if (applications.isEmpty) {
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
                Icons.event_available,
                size: isTablet ? 80 : 64,
                color: _isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ),
            SizedBox(height: isTablet ? 24 : 20),
            Text(
              'No Applications Found',
              style: TextStyle(
                fontSize: (isTablet ? 24 : 20) * responsiveFontSize,
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: isTablet ? 12 : 8),
            Text(
              'Your leave applications will appear here',
              style: TextStyle(
                color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Theme.of(context).colorScheme.primary,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: responsivePadding.horizontal, vertical: 16),
        itemCount: applications.length,
        itemBuilder: (context, index) {
          final application = applications[index];
          return _buildApplicationCard(application, canCancel);
        },
      ),
    );
  }

  // Overview Tab
  Widget _buildOverviewTab() {
    final recentApplications = _allApplications.take(3).toList();

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Theme.of(context).colorScheme.primary,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: responsivePadding.vertical),

            // Leave Balance Card
            _buildLeaveBalanceCard(),

            SizedBox(height: responsivePadding.vertical),

            // Recent Applications Section
            if (recentApplications.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: responsivePadding.horizontal),
                child: Text(
                  'Recent Applications',
                  style: TextStyle(
                    fontSize: (isTablet ? 24 : 20) * responsiveFontSize,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              SizedBox(height: responsivePadding.vertical),
              ...recentApplications.map((app) => Padding(
                padding: EdgeInsets.symmetric(horizontal: responsivePadding.horizontal),
                child: _buildApplicationCard(app, app.status == LeaveStatus.pending),
              )),
            ] else ...[
              Container(
                margin: responsivePadding,
                padding: EdgeInsets.all(isTablet ? 40 : 32),
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_available,
                        size: isTablet ? 80 : 64,
                        color: _isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                      ),
                      SizedBox(height: isTablet ? 20 : 16),
                      Text(
                        'No leave applications yet',
                        style: TextStyle(
                          color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 100), // Space for FAB
          ],
        ),
      ),
    );
  }

  // Navigation and dialogs
  Future<void> _navigateToApplyLeave() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplyLeaveView(
          employeeId: widget.employeeId,
          employeeName: widget.employeeName,
          employeePin: widget.employeePin,
          userData: widget.userData,
        ),
      ),
    );

    if (result == true) {
      await _refreshData();
    }
  }

  Future<void> _showCancelDialog(LeaveApplicationModel application) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: isTablet ? 64 : 48,
                ),
                SizedBox(height: isTablet ? 20 : 16),
                Text(
                  'Cancel Leave Application',
                  style: TextStyle(
                    fontSize: (isTablet ? 22 : 20) * responsiveFontSize,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(height: isTablet ? 16 : 12),
                Text(
                  'Are you sure you want to cancel this leave application?',
                  style: TextStyle(
                    fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                    color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isTablet ? 20 : 16),
                Container(
                  padding: EdgeInsets.all(isTablet ? 16 : 12),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Leave Type: ${application.leaveType.displayName}',
                        style: TextStyle(
                          fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Dates: ${application.dateRange}',
                        style: TextStyle(
                          fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Days: ${application.totalDays}',
                        style: TextStyle(
                          fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isTablet ? 24 : 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
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
                          'No',
                          style: TextStyle(fontSize: (isTablet ? 16 : 14) * responsiveFontSize),
                        ),
                      ),
                    ),
                    SizedBox(width: isTablet ? 16 : 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Yes, Cancel',
                          style: TextStyle(fontSize: (isTablet ? 16 : 14) * responsiveFontSize),
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
    );

    if (confirmed == true) {
      await _cancelApplication(application);
    }
  }

  Future<void> _cancelApplication(LeaveApplicationModel application) async {
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
                  'Cancelling application...',
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

      final success = await _leaveService.cancelLeaveApplication(application.id!);

      Navigator.pop(context); // Close loading dialog

      if (success) {
        CustomSnackBar.successSnackBar("Leave application cancelled successfully");
        await _refreshData();
      } else {
        CustomSnackBar.errorSnackBar("Failed to cancel application");
      }
    } catch (e) {
      Navigator.pop(context);
      CustomSnackBar.errorSnackBar("Error: $e");
    }
  }

  // Helper methods
  Color _getStatusColor(LeaveStatus status) {
    switch (status) {
      case LeaveStatus.approved:
        return Colors.green;
      case LeaveStatus.rejected:
        return Colors.red;
      case LeaveStatus.cancelled:
        return Colors.grey;
      case LeaveStatus.pending:
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(LeaveStatus status) {
    switch (status) {
      case LeaveStatus.approved:
        return Icons.check_circle;
      case LeaveStatus.rejected:
        return Icons.cancel;
      case LeaveStatus.cancelled:
        return Icons.block;
      case LeaveStatus.pending:
      default:
        return Icons.schedule;
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

                    // Tab Bar
                    _buildModernTabBar(),

                    SizedBox(height: responsivePadding.vertical),

                    // Tab Views
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(),
                          _buildApplicationsList(_pendingApplications, true),
                          _buildApplicationsList(_approvedApplications, false),
                          _buildApplicationsList(_rejectedApplications, false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        floatingActionButton: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: FloatingActionButton.extended(
                onPressed: _navigateToApplyLeave,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 8,
                icon: Icon(
                  Icons.add,
                  size: isTablet ? 24 : 20,
                ),
                label: Text(
                  'Apply Leave',
                  style: TextStyle(
                    fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}