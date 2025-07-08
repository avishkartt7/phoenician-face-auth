// lib/dashboard/dashboard_view.dart

// ADD this import at the top of dashboard_view.dart file

import 'dart:convert';
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:geodesy/geodesy.dart';
import 'package:flutter/material.dart';
import 'package:phoenician_face_auth/services/overtime_approver_service.dart';
import 'package:flutter/foundation.dart';
import 'package:phoenician_face_auth/services/overtime_approver_service.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phoenician_face_auth/constants/theme.dart';
import 'package:phoenician_face_auth/pin_entry/pin_entry_view.dart';
import 'package:phoenician_face_auth/dashboard/user_profile_page.dart';
import 'package:phoenician_face_auth/common/utils/custom_snackbar.dart';
import 'package:phoenician_face_auth/utils/geofence_util.dart';
import 'package:phoenician_face_auth/authenticate_face/authenticate_face_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:phoenician_face_auth/overtime/create_overtime_view.dart';
import 'package:phoenician_face_auth/overtime/pending_overtime_view.dart';
import 'package:phoenician_face_auth/utils/overtime_setup_utility.dart';
import 'package:phoenician_face_auth/repositories/overtime_repository.dart';
import 'package:phoenician_face_auth/dashboard/my_attendance_view.dart';
import 'package:geodesy/geodesy.dart' as geo;
import 'dart:math';
import 'package:phoenician_face_auth/debug/debug_data_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:phoenician_face_auth/admin/notification_admin_view.dart';
import 'package:geodesy/geodesy.dart' as geodesy_pkg;
import 'package:phoenician_face_auth/services/database_helper.dart';
import 'package:phoenician_face_auth/services/database_helper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phoenician_face_auth/model/location_model.dart';
import 'package:phoenician_face_auth/dashboard/team_management_view.dart';
import 'package:phoenician_face_auth/dashboard/checkout_handler.dart';
import 'package:phoenician_face_auth/checkout_request/manager_pending_requests_view.dart';
import 'package:phoenician_face_auth/checkout_request/request_history_view.dart';
import 'package:phoenician_face_auth/repositories/check_out_request_repository.dart';
import 'package:phoenician_face_auth/services/notification_service.dart';
import 'package:phoenician_face_auth/services/connectivity_service.dart';
import 'package:phoenician_face_auth/common/widgets/connectivity_banner.dart';
import 'package:phoenician_face_auth/repositories/attendance_repository.dart';
import 'package:phoenician_face_auth/repositories/location_repository.dart';
import 'package:phoenician_face_auth/services/sync_service.dart';
import 'package:phoenician_face_auth/services/service_locator.dart';
import 'package:phoenician_face_auth/test/offline_test_view.dart';
import 'package:phoenician_face_auth/dashboard/check_in_out_handler.dart';
import 'package:phoenician_face_auth/services/fcm_token_service.dart';
import 'package:phoenician_face_auth/utils/enhanced_geofence_util.dart';
import 'package:phoenician_face_auth/model/polygon_location_model.dart';
import 'package:phoenician_face_auth/repositories/polygon_location_repository.dart';
import 'package:phoenician_face_auth/admin/geojson_importer_view.dart';
import 'package:phoenician_face_auth/admin/polygon_map_view.dart';
import 'package:phoenician_face_auth/admin/map_navigation.dart';
import 'package:phoenician_face_auth/overtime/employee_list_management_view.dart';
import 'package:phoenician_face_auth/leave/apply_leave_view.dart';
import 'package:phoenician_face_auth/leave/leave_history_view.dart';
import 'package:phoenician_face_auth/leave/manager_leave_approval_view.dart';
import 'package:phoenician_face_auth/services/leave_application_service.dart';
import 'package:phoenician_face_auth/repositories/leave_application_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:phoenician_face_auth/services/firebase_auth_service.dart';

// ✅ ADD THIS MISSING IMPORT:
import 'package:phoenician_face_auth/services/secure_face_storage_service.dart';

// Then the rest of your DashboardView class remains the same...


class DashboardView extends StatefulWidget {
  final String employeeId;

  const DashboardView({Key? key, required this.employeeId}) : super(key: key);

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView>
    with SingleTickerProviderStateMixin, TickerProviderStateMixin {

  // Animation Controllers
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  // Existing state variables
  bool _isLoading = true;
  bool _isDarkMode = false;
  Map<String, dynamic>? _userData;
  bool _isCheckedIn = false;
  DateTime? _checkInTime;
  String _formattedDate = '';
  String _currentTime = '';
  String _greetingMessage = '';
  List<Map<String, dynamic>> _todaysActivity = []; // Changed from _recentActivity
  LocationModel? _nearestLocation;
  List<LocationModel> _availableLocations = [];
  bool _isLineManager = false;
  String? _lineManagerDocumentId;
  Map<String, dynamic>? _lineManagerData;
  int _pendingApprovalRequests = 0;
  int _pendingOvertimeRequests = 0;
  int _pendingLeaveApprovals = 0;
  bool _isLoadingLeaveData = false;
  late LeaveApplicationService _leaveService;

  // New variables for today's activity tracking
  bool _hasTodaysAttendance = false;
  bool _hasTodaysLeaveApplication = false;
  bool _isAbsentToday = false;

  // Geofencing related variables
  bool _isCheckingLocation = false;
  bool _isWithinGeofence = false;
  double? _distanceToOffice;

  // Authentication related variables
  bool _isAuthenticating = false;
  bool _isOvertimeApprover = false;
  Map<String, dynamic>? _approverInfo;
  bool _checkingApproverStatus = true;

  // Offline support
  late ConnectivityService _connectivityService;
  late AttendanceRepository _attendanceRepository;
  late LocationRepository _locationRepository;
  late SyncService _syncService;
  bool _needsSync = false;
  late AppLifecycleObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadDarkModePreference();
    _initializeLeaveService();
    _initializeNotifications();
    _setupOvertimeApproverIfNeeded();
    _checkOvertimeApproverStatus();


    final notificationService = getIt<NotificationService>();
    notificationService.notificationStream.listen(_handleNotification);

    _connectivityService = getIt<ConnectivityService>();
    _attendanceRepository = getIt<AttendanceRepository>();
    _locationRepository = getIt<LocationRepository>();
    _syncService = getIt<SyncService>();

    if (widget.employeeId == 'EMP1289') {
      _setupOvertimeApproverNotifications();
      _loadPendingOvertimeRequests();
    }

    _connectivityService.connectionStatusStream.listen((status) {
      debugPrint("Connectivity status changed: $status");
      if (status == ConnectionStatus.online && _needsSync) {
        _syncService.syncData().then((_) {
          _fetchUserData();
          if (_isLineManager) {
            _loadPendingApprovalRequests();
            _loadPendingLeaveApprovals();
          }
          _fetchAttendanceStatus();
          _fetchTodaysActivity(); // Changed from _fetchRecentActivity
          setState(() {
            _needsSync = false;
          });
        });
      }
    });

    Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted && _isOvertimeApprover) {
        _loadPendingOvertimeRequests();
      } else if (!mounted) {
        timer.cancel();
      }
    });

    _lifecycleObserver = AppLifecycleObserver(
      onResume: () async {
        debugPrint("App resumed - refreshing dashboard");
        await _refreshDashboard();
      },
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);

    _fetchUserData();
    _fetchAttendanceStatus();
    _fetchTodaysActivity(); // Changed from _fetchRecentActivity
    _checkGeofenceStatus();
    _updateDateTime();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _updateDateTime();
    });
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

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _syncService.dispose();
    super.dispose();
  }

  // Responsive design helpers methods
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

  // Updated time-based greeting logic without emojis
  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    String greeting;

    if (hour >= 5 && hour < 12) {
      greeting = "Good Morning";
    } else if (hour >= 12 && hour < 17) {
      greeting = "Good Afternoon";
    } else if (hour >= 17 && hour < 21) {
      greeting = "Good Evening";
    } else {
      greeting = "Good Night";
    }

    return greeting; // Removed emoji
  }

  // Load dark mode preference
  Future<void> _loadDarkModePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  // Save dark mode preference
  Future<void> _saveDarkModePreference(bool isDarkMode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }






  void _initializeLeaveService() {
    try {
      final repository = getIt<LeaveApplicationRepository>();
      final connectivityService = getIt<ConnectivityService>();

      _leaveService = LeaveApplicationService(
        repository: repository,
        connectivityService: connectivityService,
      );

      debugPrint("Leave service initialized successfully");
    } catch (e) {
      debugPrint("Error initializing leave service: $e");
    }
  }

  Future<void> _loadPendingLeaveApprovals() async {
    if (!_isLineManager) return;

    try {
      setState(() => _isLoadingLeaveData = true);

      final pendingApplications = await _leaveService.getPendingApplicationsForManager(widget.employeeId);

      setState(() {
        _pendingLeaveApprovals = pendingApplications.length;
        _isLoadingLeaveData = false;
      });

      debugPrint("Loaded ${_pendingLeaveApprovals} pending leave approvals");
    } catch (e) {
      setState(() => _isLoadingLeaveData = false);
      debugPrint("Error loading pending leave approvals: $e");
    }
  }

  void _updateDateTime() {
    if (mounted) {
      setState(() {
        final now = DateTime.now();
        _formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(now);
        _currentTime = DateFormat('h:mm a').format(now);
        _greetingMessage = _getTimeBasedGreeting();
      });

      Future.delayed(const Duration(minutes: 1), _updateDateTime);
    }
  }

  // New method to fetch today's activity including attendance and leave applications
  Future<void> _fetchTodaysActivity() async {
    try {
      List<Map<String, dynamic>> todaysActivity = [];
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      bool hasAttendance = false;
      bool hasLeaveApplication = false;

      // Fetch today's attendance
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        try {
          DocumentSnapshot attendanceDoc = await FirebaseFirestore.instance
              .collection('employees')
              .doc(widget.employeeId)
              .collection('attendance')
              .doc(today)
              .get();

          if (attendanceDoc.exists) {
            Map<String, dynamic> data = attendanceDoc.data() as Map<String, dynamic>;
            todaysActivity.add({
              'type': 'attendance',
              'date': data['date'] ?? today,
              'checkIn': data['checkIn'],
              'checkOut': data['checkOut'],
              'workStatus': data['workStatus'] ?? 'In Progress',
              'totalHours': data['totalHours'],
              'location': data['location'] ?? 'Unknown',
              'isSynced': true,
            });
            hasAttendance = true;
            debugPrint("Found today's attendance record");
          }
        } catch (e) {
          debugPrint("Error fetching today's attendance: $e");
        }

        // Fetch today's leave applications
        try {
          QuerySnapshot leaveSnapshot = await FirebaseFirestore.instance
              .collection('leave_applications')
              .where('employeeId', isEqualTo: widget.employeeId)
              .where('applicationDate', isEqualTo: today)
              .get();

          for (var doc in leaveSnapshot.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            todaysActivity.add({
              'type': 'leave',
              'applicationId': doc.id,
              'date': today,
              'leaveType': data['leaveType'] ?? 'Leave',
              'fromDate': data['fromDate'],
              'toDate': data['toDate'],
              'totalDays': data['totalDays'] ?? 0,
              'status': data['status'] ?? 'pending',
              'reason': data['reason'] ?? '',
              'appliedAt': data['appliedAt'],
              'isSynced': true,
            });
            hasLeaveApplication = true;
            debugPrint("Found today's leave application");
          }
        } catch (e) {
          debugPrint("Error fetching today's leave applications: $e");
        }
      } else {
        // Offline mode - check local data
        final localAttendance = await _attendanceRepository.getTodaysAttendance(widget.employeeId);
        if (localAttendance != null) {
          todaysActivity.add(localAttendance.rawData);
          hasAttendance = true;
          debugPrint("Using local attendance data");
        }
      }

      setState(() {
        _todaysActivity = todaysActivity;
        _hasTodaysAttendance = hasAttendance;
        _hasTodaysLeaveApplication = hasLeaveApplication;
        _isAbsentToday = !hasAttendance && !hasLeaveApplication && !_isCheckedIn;
      });

      debugPrint("Today's activity loaded: ${todaysActivity.length} items");
      debugPrint("Has attendance: $hasAttendance, Has leave: $hasLeaveApplication, Is absent: $_isAbsentToday");

    } catch (e) {
      debugPrint("Error fetching today's activity: $e");
      setState(() {
        _todaysActivity = [];
        _isAbsentToday = !_isCheckedIn;
      });
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
              child: Column(
                children: [
                  // Connectivity banners
                  ConnectivityBanner(connectivityService: _connectivityService),
                  if (_needsSync && _connectivityService.currentStatus == ConnectionStatus.online)
                    _buildSyncBanner(),

                  // Main content
                  Expanded(
                    child: SafeArea(
                      child: Column(
                        children: [
                          _buildModernHeader(),
                          _buildDateTimeSection(),
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                children: [
                                  _buildModernStatusCard(),
                                  SizedBox(height: responsivePadding.vertical),
                                  _buildQuickActionsSection(),
                                  SizedBox(height: responsivePadding.vertical),
                                  _buildTodaysActivitySection(), // Updated method name
                                  SizedBox(height: 100), // Space for FAB
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        floatingActionButton: _buildModernFloatingActionButtons(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  // Modern Theme Builders
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

  // Loading Screen
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
              'Loading your dashboard...',
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

  // Sync Banner
  Widget _buildSyncBanner() {
    return GestureDetector(
      onTap: _manualSync,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade400, Colors.orange.shade500],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sync, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'Tap to synchronize pending data',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13 * responsiveFontSize,
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
    String name = _userData?['name'] ?? 'User';
    String designation = _userData?['designation'] ?? 'Employee';
    String? imageBase64 = _userData?['image'];

    int totalNotificationCount = _pendingApprovalRequests + _pendingOvertimeRequests + _pendingLeaveApprovals;

    return Container(
      margin: responsivePadding,
      padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Profile Image with modern design
          Hero(
            tag: 'profile_${widget.employeeId}',
            child: GestureDetector(
              onTap: () {
                if (_userData != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => UserProfilePage(
                        employeeId: widget.employeeId,
                        userData: _userData!,
                      ),
                    ),
                  );
                } else {
                  CustomSnackBar.errorSnackBar(context, "User data not available");
                }
              },
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: CircleAvatar(
                    radius: isTablet ? 35 : 28,
                    backgroundColor: _isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                    backgroundImage: imageBase64 != null
                        ? MemoryImage(base64Decode(imageBase64))
                        : null,
                    child: imageBase64 == null
                        ? Icon(
                      Icons.person,
                      color: _isDarkMode ? Colors.grey.shade300 : Colors.grey,
                      size: isTablet ? 35 : 28,
                    )
                        : null,
                  ),
                ),
              ),
            ),
          ),

          SizedBox(width: isTablet ? 20 : 16),

          // User info with greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greetingMessage, // Now without emoji
                  style: TextStyle(
                    color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name.split(' ').first, // Show first name only for space
                  style: TextStyle(
                    fontSize: (isTablet ? 24 : 20) * responsiveFontSize,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  designation,
                  style: TextStyle(
                    color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Notification button
              _buildHeaderActionButton(
                icon: Icons.notifications_outlined,
                badgeCount: totalNotificationCount,
                onTap: () => _showNotificationMenu(context),
              ),

              SizedBox(width: isTablet ? 12 : 8),

              // Settings button
              _buildHeaderActionButton(
                icon: Icons.settings_outlined,
                onTap: () => _showSettingsMenu(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(isTablet ? 12 : 10),
          decoration: BoxDecoration(
            color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
            ),
          ),
          child: Stack(
            children: [
              Icon(
                icon,
                color: _isDarkMode ? Colors.white : Colors.black87,
                size: isTablet ? 24 : 20,
              ),
              if (badgeCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Date Time Section
  Widget _buildDateTimeSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: responsivePadding.horizontal),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formattedDate,
                    style: TextStyle(
                      fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                      color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          Container(
            width: 1,
            height: 24,
            color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.3),
          ),

          const SizedBox(width: 16),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.access_time,
                  size: 16,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _currentTime,
                style: TextStyle(
                  fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                  color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Modern Status Card
  Widget _buildModernStatusCard() {
    final String locationName = _nearestLocation?.name ?? 'office location';

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Header
                  Padding(
                    padding: EdgeInsets.all(isTablet ? 28 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Today's Status",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  AnimatedBuilder(
                                    animation: _pulseAnimation,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: _isCheckedIn ? _pulseAnimation.value : 1.0,
                                        child: Text(
                                          _isCheckedIn ? "Checked In" : "Ready to Start",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: (isTablet ? 32 : 28) * responsiveFontSize,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  if (_isCheckedIn && _checkInTime != null)
                                    Text(
                                      "Since ${DateFormat('h:mm a').format(_checkInTime!)}",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Status indicator
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 16 : 12,
                                vertical: isTablet ? 10 : 8,
                              ),
                              decoration: BoxDecoration(
                                color: _isCheckedIn
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isCheckedIn ? Icons.check_circle : Icons.schedule,
                                    color: Colors.white,
                                    size: isTablet ? 20 : 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isCheckedIn ? "Active" : "Inactive",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Location Status
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 28 : 24,
                      0,
                      isTablet ? 28 : 24,
                      isTablet ? 16 : 12,
                    ),
                    child: Container(
                      padding: EdgeInsets.all(isTablet ? 16 : 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isWithinGeofence
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.red.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _isWithinGeofence ? Icons.location_on : Icons.location_off,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isCheckingLocation
                                      ? "Checking location..."
                                      : _isWithinGeofence
                                      ? "At $locationName"
                                      : "Outside $locationName",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_distanceToOffice != null && !_isWithinGeofence)
                                  Text(
                                    "${_distanceToOffice!.toStringAsFixed(0)}m away",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_isCheckingLocation)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Status badges for offline/sync
                  if (_needsSync || _connectivityService.currentStatus == ConnectionStatus.offline)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        isTablet ? 28 : 24,
                        0,
                        isTablet ? 28 : 24,
                        isTablet ? 16 : 12,
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_needsSync && _isCheckedIn)
                            _buildStatusBadge(
                              icon: Icons.sync_disabled,
                              text: "Pending sync",
                              color: Colors.orange,
                            ),
                          if (_connectivityService.currentStatus == ConnectionStatus.offline)
                            _buildStatusBadge(
                              icon: Icons.wifi_off,
                              text: "Offline Mode",
                              color: Colors.red,
                            ),
                        ],
                      ),
                    ),

                  // Check In/Out Button
                  Padding(
                    padding: EdgeInsets.all(isTablet ? 28 : 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: isTablet ? 60 : 56,
                      child: ElevatedButton(
                        onPressed: _isLoading || _isAuthenticating
                            ? null
                            : _handleCheckInOut,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (!_isCheckedIn && !_isWithinGeofence) || _isLoading || _isAuthenticating
                              ? Colors.grey.withOpacity(0.5)
                              : _isCheckedIn
                              ? const Color(0xFFEC407A)
                              : const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: _isLoading || _isAuthenticating
                            ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isCheckedIn ? Icons.logout : Icons.face,
                              color: Colors.white,
                              size: isTablet ? 28 : 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _isCheckedIn ? "CHECK OUT WITH FACE ID" : "CHECK IN WITH FACE ID",
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 12 : 10,
        vertical: isTablet ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Quick Actions Section
  Widget _buildQuickActionsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: responsivePadding.horizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: isTablet ? 8 : 4, bottom: isTablet ? 20 : 16),
            child: Text(
              "Quick Actions",
              style: TextStyle(
                fontSize: (isTablet ? 24 : 20) * responsiveFontSize,
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),

          // Rest Timing Card (if user has active schedule)
          if (_hasActiveRestTiming())
            _buildRestTimingCard(),
          const SizedBox(height: 16),

          // Grid of quick action cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isTablet ? 4 : 2,
            crossAxisSpacing: isTablet ? 16 : 12,
            mainAxisSpacing: isTablet ? 16 : 12,
            childAspectRatio: isTablet ? 1.2 : 1.1,
            children: [
              _buildQuickActionCard(
                icon: Icons.event_available,
                title: "Apply Leave",
                subtitle: "Request time off",
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ApplyLeaveView(
                        employeeId: widget.employeeId,
                        employeeName: _userData?['name'] ?? 'Employee',
                        employeePin: _userData?['pin'] ?? widget.employeeId,
                        userData: _userData ?? {},
                      ),
                    ),
                  ).then((_) => _refreshDashboard());
                },
              ),

              _buildQuickActionCard(
                icon: Icons.history,
                title: "Leave History",
                subtitle: "View applications",
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LeaveHistoryView(
                        employeeId: widget.employeeId,
                        employeeName: _userData?['name'] ?? 'Employee',
                        employeePin: _userData?['pin'] ?? widget.employeeId,
                        userData: _userData ?? {},
                      ),
                    ),
                  ).then((_) => _refreshDashboard());
                },
              ),

              _buildQuickActionCard(
                icon: Icons.calendar_view_month,
                title: "My Attendance",
                subtitle: "View records",
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MyAttendanceView(
                        employeeId: widget.employeeId,
                        userData: _userData ?? {},
                      ),
                    ),
                  );
                },
              ),

              if (_userData != null &&
                  (_userData!['hasOvertimeAccess'] == true ||
                      _userData!['overtimeAccessGrantedAt'] != null))
                _buildQuickActionCard(
                  icon: Icons.access_time,
                  title: "Overtime",
                  subtitle: "Request overtime",
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateOvertimeView(
                          requesterId: widget.employeeId,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
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
                Container(
                  padding: EdgeInsets.all(isTablet ? 12 : 10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: isTablet ? 28 : 24,
                  ),
                ),

                const Spacer(),

                Text(
                  title,
                  style: TextStyle(
                    fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                    color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestTimingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.withOpacity(0.8), Colors.cyan.withOpacity(0.6)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.schedule,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Rest Timing Schedule",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (isTablet ? 20 : 18) * responsiveFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getRestTimingStatus(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Rest Time",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getRestTimingHours(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.access_time,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasActiveRestTiming() {
    if (_userData == null) return false;

    // Check if user has rest timing data
    if (_userData!['eligibleForRestTiming'] != true) return false;

    final String? startDateStr = _userData!['restTimingStartDate'];
    final String? endDateStr = _userData!['restTimingEndDate'];

    if (startDateStr == null || endDateStr == null) return false;

    try {
      final DateTime startDate = DateTime.parse(startDateStr);
      final DateTime endDate = DateTime.parse(endDateStr);
      final DateTime now = DateTime.now();

      // Check if currently within the rest timing period
      return now.isAfter(startDate.subtract(Duration(days: 1))) &&
          now.isBefore(endDate.add(Duration(days: 1)));
    } catch (e) {
      debugPrint("Error parsing rest timing dates: $e");
      return false;
    }
  }

  String _getRestTimingStatus() {
    if (!_hasActiveRestTiming()) return "No active schedule";

    final String? startDateStr = _userData!['restTimingStartDate'];
    final String? endDateStr = _userData!['restTimingEndDate'];

    if (startDateStr == null || endDateStr == null) return "Invalid schedule";

    try {
      final DateTime startDate = DateTime.parse(startDateStr);
      final DateTime endDate = DateTime.parse(endDateStr);
      final DateTime now = DateTime.now();

      if (now.isBefore(startDate)) {
        return "Scheduled to start ${DateFormat('MMM dd').format(startDate)}";
      } else if (now.isAfter(endDate)) {
        return "Schedule completed";
      } else {
        return "Active until ${DateFormat('MMM dd').format(endDate)}";
      }
    } catch (e) {
      return "Invalid schedule dates";
    }
  }

  String _getRestTimingHours() {
    if (!_hasActiveRestTiming()) return "--:-- - --:--";

    final String? startTime = _userData!['restTimingStartTime'];
    final String? endTime = _userData!['restTimingEndTime'];

    if (startTime == null || endTime == null) return "--:-- - --:--";

    return "$startTime - $endTime";
  }

  // Updated Today's Activity Section
  Widget _buildTodaysActivitySection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: responsivePadding.horizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: isTablet ? 8 : 4, bottom: isTablet ? 20 : 16),
            child: Row(
              children: [
                Icon(
                  Icons.today,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  size: isTablet ? 28 : 24,
                ),
                const SizedBox(width: 12),
                Text(
                  "Today's Activity",
                  style: TextStyle(
                    fontSize: (isTablet ? 24 : 20) * responsiveFontSize,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          _buildTodaysActivityList(),
        ],
      ),
    );
  }

  Widget _buildTodaysActivityList() {
    // Check if user is absent today (no check-in and no leave application)
    if (_isAbsentToday) {
      return _buildAbsentTodayCard();
    }

    if (_todaysActivity.isEmpty) {
      return Container(
        padding: EdgeInsets.all(isTablet ? 48 : 40),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.today_outlined,
                size: isTablet ? 64 : 48,
                color: _isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ),

            SizedBox(height: isTablet ? 24 : 20),

            Text(
              "No activity today",
              style: TextStyle(
                color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: (isTablet ? 20 : 18) * responsiveFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Your today's attendance and leave records will appear here",
              style: TextStyle(
                color: _isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: _todaysActivity.map((activity) => _buildTodaysActivityCard(activity)).toList(),
    );
  }

  // New method to build absent today card with apply leave suggestion
  Widget _buildAbsentTodayCard() {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.withOpacity(0.8),
            Colors.red.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: isTablet ? 32 : 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "You're Absent Today",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (isTablet ? 22 : 20) * responsiveFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "No check-in or leave application found for today",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: isTablet ? 24 : 20),

          Container(
            padding: EdgeInsets.all(isTablet ? 16 : 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Colors.white,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Need time off? Apply for leave to mark today as an official leave day.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: isTablet ? 20 : 16),

          SizedBox(
            width: double.infinity,
            height: isTablet ? 52 : 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ApplyLeaveView(
                      employeeId: widget.employeeId,
                      employeeName: _userData?['name'] ?? 'Employee',
                      employeePin: _userData?['pin'] ?? widget.employeeId,
                      userData: _userData ?? {},
                    ),
                  ),
                ).then((_) => _refreshDashboard());
              },
              icon: const Icon(Icons.event_available, color: Colors.orange),
              label: Text(
                "Apply for Leave",
                style: TextStyle(
                  fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange.shade800,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysActivityCard(Map<String, dynamic> activity) {
    String activityType = activity['type'] ?? 'attendance';

    if (activityType == 'leave') {
      return _buildLeaveActivityCard(activity);
    } else {
      return _buildAttendanceActivityCard(activity);
    }
  }

  Widget _buildAttendanceActivityCard(Map<String, dynamic> activity) {
    DateTime? checkIn;
    if (activity['checkIn'] != null) {
      if (activity['checkIn'] is Timestamp) {
        checkIn = (activity['checkIn'] as Timestamp).toDate();
      } else if (activity['checkIn'] is String) {
        checkIn = DateTime.parse(activity['checkIn']);
      }
    }

    DateTime? checkOut;
    if (activity['checkOut'] != null) {
      if (activity['checkOut'] is Timestamp) {
        checkOut = (activity['checkOut'] as Timestamp).toDate();
      } else if (activity['checkOut'] is String) {
        checkOut = DateTime.parse(activity['checkOut']);
      }
    }

    String status = activity['workStatus'] ?? 'In Progress';
    String location = activity['location'] ?? 'Unknown';
    bool isSynced = activity['isSynced'] ?? true;

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.access_time,
                          color: Colors.blue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Attendance Record",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: (isTablet ? 20 : 18) * responsiveFontSize,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                Row(
                  children: [
                    if (!isSynced)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 10 : 8,
                          vertical: isTablet ? 6 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sync_disabled, color: Colors.orange, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              "Pending",
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: (isTablet ? 12 : 10) * responsiveFontSize,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(width: 8),

                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 12 : 10,
                        vertical: isTablet ? 8 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: isTablet ? 16 : 12),

            Container(
              padding: EdgeInsets.all(isTablet ? 16 : 12),
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeInfo(
                          icon: Icons.login,
                          label: "Check In",
                          time: checkIn != null
                              ? DateFormat('h:mm a').format(checkIn)
                              : 'Not recorded',
                          color: Colors.green,
                        ),
                      ),

                      Container(
                        width: 1,
                        height: 40,
                        color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.3),
                      ),

                      Expanded(
                        child: _buildTimeInfo(
                          icon: Icons.logout,
                          label: "Check Out",
                          time: checkOut != null
                              ? DateFormat('h:mm a').format(checkOut)
                              : 'Not recorded',
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: isTablet ? 12 : 8),

                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(
                            fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                            color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveActivityCard(Map<String, dynamic> activity) {
    String leaveType = activity['leaveType'] ?? 'Leave';
    String status = activity['status'] ?? 'pending';
    int totalDays = activity['totalDays'] ?? 0;
    String reason = activity['reason'] ?? '';
    String applicationId = activity['applicationId'] ?? '';

    DateTime? appliedAt;
    if (activity['appliedAt'] != null) {
      if (activity['appliedAt'] is Timestamp) {
        appliedAt = (activity['appliedAt'] as Timestamp).toDate();
      } else if (activity['appliedAt'] is String) {
        appliedAt = DateTime.parse(activity['appliedAt']);
      }
    }

    Color statusColor = _getLeaveStatusColor(status);

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.event_available,
                          color: statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Leave Application",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: (isTablet ? 20 : 18) * responsiveFontSize,
                                color: _isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              leaveType,
                              style: TextStyle(
                                fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                                color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 12 : 10,
                    vertical: isTablet ? 8 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: isTablet ? 16 : 12),

            Container(
              padding: EdgeInsets.all(isTablet ? 16 : 12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Duration",
                              style: TextStyle(
                                fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                                color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "$totalDays ${totalDays == 1 ? 'day' : 'days'}",
                              style: TextStyle(
                                fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                                color: _isDarkMode ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (appliedAt != null)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Applied At",
                                style: TextStyle(
                                  fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                                  color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('h:mm a').format(appliedAt),
                                style: TextStyle(
                                  fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                                  color: _isDarkMode ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  if (reason.isNotEmpty) ...[
                    SizedBox(height: isTablet ? 12 : 8),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isTablet ? 12 : 10),
                      decoration: BoxDecoration(
                        color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Reason:",
                            style: TextStyle(
                              fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                              color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reason,
                            style: TextStyle(
                              fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                              color: _isDarkMode ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (applicationId.isNotEmpty) ...[
                    SizedBox(height: isTablet ? 8 : 6),
                    Row(
                      children: [
                        Icon(
                          Icons.tag,
                          size: 14,
                          color: _isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "ID: ${applicationId.substring(0, 8)}...",
                          style: TextStyle(
                            fontSize: (isTablet ? 12 : 11) * responsiveFontSize,
                            color: _isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                            fontWeight: FontWeight.w400,
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
      ),
    );
  }

  Widget _buildTimeInfo({
    required IconData icon,
    required String label,
    required String time,
    required Color color,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 12),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: isTablet ? 24 : 20,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
              color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: TextStyle(
              fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
              color: _isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Modern Floating Action Buttons
  Widget _buildModernFloatingActionButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 🐛 DEBUG BUTTON (NEW!)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DebugDataScreen(employeeId: widget.employeeId),
                ),
              );
            },
            tooltip: 'Debug Local Data',
            backgroundColor: Colors.purple,
            heroTag: 'debugButton',
            elevation: 8,
            child: const Icon(Icons.bug_report, color: Colors.white),
          ),
        ),

        // Locations FAB
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: FloatingActionButton(
            onPressed: () => _showLocationMenu(context),
            tooltip: 'View All Locations',
            backgroundColor: Theme.of(context).colorScheme.secondary,
            heroTag: 'locationsButton',
            elevation: 8,
            child: const Icon(Icons.map_outlined, color: Colors.white),
          ),
        ),

        // Sync FAB (if needed)
        if (_needsSync && _connectivityService.currentStatus == ConnectionStatus.online)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: FloatingActionButton(
              onPressed: _manualSync,
              tooltip: 'Sync Data',
              backgroundColor: Colors.orange,
              heroTag: 'syncButton',
              elevation: 8,
              child: const Icon(Icons.sync, color: Colors.white),
            ),
          ),

        // Location refresh FAB
        FloatingActionButton(
          onPressed: _checkGeofenceStatus,
          tooltip: 'Refresh Location',
          backgroundColor: Theme.of(context).colorScheme.primary,
          heroTag: 'locationButton',
          elevation: 8,
          child: const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
      ],
    );
  }

  // Helper methods
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getLeaveStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // All existing methods - keeping functionality intact
  Future<void> _checkGeofenceStatus() async {
    if (!mounted) return;

    setState(() {
      _isCheckingLocation = true;
    });

    try {
      Map<String, dynamic> status = await EnhancedGeofenceUtil.checkGeofenceStatus(context);

      bool withinGeofence = status['withinGeofence'] as bool;
      double? distance = status['distance'] as double?;
      String locationType = status['locationType'] as String? ?? 'unknown';

      if (locationType == 'polygon') {
        debugPrint("Using polygon result for UI update");
        final polygonLocation = status['location'] as PolygonLocationModel?;

        setState(() {
          _isWithinGeofence = withinGeofence;
          _distanceToOffice = distance;

          if (polygonLocation != null) {
            _nearestLocation = LocationModel(
              id: polygonLocation.id,
              name: polygonLocation.name,
              address: polygonLocation.description,
              latitude: polygonLocation.centerLatitude,
              longitude: polygonLocation.centerLongitude,
              radius: 0,
              isActive: polygonLocation.isActive,
            );

            _nearestLocation = LocationModel(
              id: _nearestLocation!.id,
              name: "${_nearestLocation!.name} (Polygon Boundary)",
              address: _nearestLocation!.address,
              latitude: _nearestLocation!.latitude,
              longitude: _nearestLocation!.longitude,
              radius: _nearestLocation!.radius,
              isActive: _nearestLocation!.isActive,
            );
          } else {
            _nearestLocation = null;
          }

          _isCheckingLocation = false;
        });

        debugPrint("Location check result (polygon): within=$withinGeofence, distance=${distance?.toStringAsFixed(1) ?? 'unknown'}m");
      } else {
        debugPrint("Using circular result for UI update");
        final circularLocation = status['location'] as LocationModel?;

        setState(() {
          _isWithinGeofence = withinGeofence;
          _nearestLocation = circularLocation;
          _distanceToOffice = distance;
          _isCheckingLocation = false;
        });

        debugPrint("Location check result (circular): within=$withinGeofence, distance=${distance?.toStringAsFixed(1) ?? 'unknown'}m");
      }

      if (mounted) {
        _fetchAvailableLocations();
      }
    } catch (e) {
      debugPrint('Error checking geofence: $e');
      if (mounted) {
        setState(() {
          _isCheckingLocation = false;
        });
        CustomSnackBar.errorSnackBar(context, "Error checking geofence status: $e");
      }
    }
  }

  Future<void> _fetchAvailableLocations() async {
    try {
      final locationRepository = getIt<LocationRepository>();
      List<LocationModel> circularLocations = await locationRepository.getActiveLocations();

      final polygonRepository = getIt<PolygonLocationRepository>();
      List<PolygonLocationModel> polygonLocations = await polygonRepository.getActivePolygonLocations();

      List<LocationModel> convertedPolygonLocations = polygonLocations.map((poly) =>
          LocationModel(
            id: poly.id,
            name: "${poly.name} (Polygon)",
            address: poly.description,
            latitude: poly.centerLatitude,
            longitude: poly.centerLongitude,
            radius: 0,
            isActive: poly.isActive,
          )
      ).toList();

      List<LocationModel> allLocations = [...circularLocations, ...convertedPolygonLocations];

      if (mounted) {
        setState(() {
          _availableLocations = allLocations;
        });
      }
    } catch (e) {
      debugPrint('Error fetching available locations: $e');
    }
  }

  // FIXED: dashboard_view.dart - _fetchUserData method
// Replace the existing _fetchUserData method with this corrected version

  Future<void> _fetchUserData() async {
    setState(() => _isLoading = true);

    try {
      debugPrint("=== FETCHING USER DATA (WITH FACE DATA VALIDATION) ===");
      debugPrint("Dashboard widget.employeeId: ${widget.employeeId}");

      // ✅ STEP 1: Get cached local data first
      Map<String, dynamic>? localData = await _getUserDataLocally();

      if (localData != null) {
        debugPrint("✅ Found local cached data");
        setState(() {
          _userData = localData;
          _isLoading = false;
        });

        // ✅ NEW: Validate face data in background after loading user data
        _validateFaceDataInBackground();

        // ✅ FIXED: If offline, use local data and return immediately
        if (_connectivityService.currentStatus == ConnectionStatus.offline) {
          debugPrint("📱 OFFLINE MODE: Using cached user data successfully");
          debugPrint("Cached data keys: ${localData.keys.toList()}");
          return; // ✅ Success with local data
        }

        // ✅ FIXED: If online, try to refresh but don't fail if auth fails
        debugPrint("🌐 ONLINE MODE: Local data loaded, attempting to refresh from Firestore...");
      }

      // ✅ STEP 2: If online, try to fetch fresh data (but don't require Firebase Auth)
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        try {
          // ✅ FIXED: Check SharedPreferences for authentication status first
          SharedPreferences prefs = await SharedPreferences.getInstance();
          String? authenticatedUserId = prefs.getString('authenticated_user_id');
          bool isAuthenticated = prefs.getBool('is_authenticated') ?? false;

          if (!isAuthenticated || authenticatedUserId != widget.employeeId) {
            debugPrint("⚠️ User not authenticated via SharedPreferences");

            // ✅ FIXED: If we have local data, continue with it instead of failing
            if (localData != null) {
              debugPrint("✅ Continuing with cached local data");
              return; // ✅ Success with local data
            } else {
              debugPrint("❌ No local data and not authenticated - redirecting to login");
              _redirectToLogin();
              return;
            }
          }

          debugPrint("✅ User authenticated via SharedPreferences: $authenticatedUserId");

          // ✅ STEP 3: Try to fetch fresh data from Firestore (with error handling)
          Map<String, dynamic> combinedData = localData ?? {};

          try {
            // Try to get employee data from Firestore
            DocumentSnapshot employeeDoc = await FirebaseFirestore.instance
                .collection('employees')
                .doc(widget.employeeId)
                .get()
                .timeout(Duration(seconds: 10)); // Add timeout

            if (employeeDoc.exists) {
              Map<String, dynamic> employeeData = employeeDoc.data() as Map<String, dynamic>;
              combinedData.addAll(employeeData);
              debugPrint("✅ Fresh employee data fetched from Firestore");

              // Get the pin for MasterSheet lookup
              String? employeePin = employeeData['pin']?.toString();

              if (employeePin != null && employeePin.isNotEmpty) {
                // Try to fetch MasterSheet data
                try {
                  String masterSheetEmployeeId = employeePin;
                  if (masterSheetEmployeeId.startsWith('EMP')) {
                    masterSheetEmployeeId = masterSheetEmployeeId.substring(3);
                  }

                  int pinNumber = int.parse(masterSheetEmployeeId);
                  masterSheetEmployeeId = 'EMP${pinNumber.toString().padLeft(4, '0')}';

                  DocumentSnapshot masterSheetDoc = await FirebaseFirestore.instance
                      .collection('MasterSheet')
                      .doc('Employee-Data')
                      .collection('employees')
                      .doc(masterSheetEmployeeId)
                      .get()
                      .timeout(Duration(seconds: 5));

                  if (masterSheetDoc.exists) {
                    Map<String, dynamic> masterSheetData = masterSheetDoc.data() as Map<String, dynamic>;
                    combinedData.addAll(masterSheetData);
                    debugPrint("✅ MasterSheet data fetched successfully");

                    // Check for rest timing data
                    if (masterSheetData.containsKey('eligibleForRestTiming') &&
                        masterSheetData['eligibleForRestTiming'] == true) {
                      debugPrint("🕐 Rest timing data found and added");
                      combinedData['hasActiveRestTiming'] = true;
                    }
                  }
                } catch (masterSheetError) {
                  debugPrint("⚠️ Could not fetch MasterSheet data: $masterSheetError");
                  // Continue without MasterSheet data
                }
              }

              // ✅ Save updated data locally
              await _saveUserDataLocally(combinedData);

              setState(() {
                _userData = combinedData;
                _isLoading = false;
              });

              debugPrint("✅ User data updated successfully with fresh data");

              // ✅ NEW: Validate face data after successful data fetch
              _validateFaceDataInBackground();

            } else {
              debugPrint("⚠️ No employee document found in Firestore");

              // ✅ FIXED: Continue with local data if Firestore fetch fails
              if (localData != null) {
                debugPrint("✅ Using cached local data as fallback");
                // Data already set above
              } else {
                debugPrint("❌ No data available anywhere");
                _redirectToLogin();
              }
            }
          } catch (firestoreError) {
            debugPrint("⚠️ Error fetching from Firestore: $firestoreError");

            // ✅ FIXED: Continue with local data if Firestore fails
            if (localData != null) {
              debugPrint("✅ Using cached local data due to Firestore error");
              // Data already set above
            } else {
              debugPrint("❌ No fallback data available");
              _redirectToLogin();
            }
          }

        } catch (connectivityError) {
          debugPrint("⚠️ Connectivity error: $connectivityError");

          // ✅ FIXED: Continue with local data if connectivity fails
          if (localData != null) {
            debugPrint("✅ Using cached local data due to connectivity error");
            // Data already set above
          } else {
            debugPrint("❌ No data available offline");
            setState(() => _isLoading = false);
            CustomSnackBar.errorSnackBar("No cached data available. Please connect to internet and login again.");
          }
        }
      } else {
        // ✅ OFFLINE MODE
        if (localData != null) {
          debugPrint("✅ OFFLINE: Using cached user data successfully");
          // Data already set above
        } else {
          debugPrint("❌ OFFLINE: No cached data available");
          setState(() => _isLoading = false);
          CustomSnackBar.errorSnackBar("No cached data available. Please connect to internet and login.");
        }
      }

    } catch (e) {
      debugPrint("❌ Critical error in _fetchUserData: $e");
      setState(() => _isLoading = false);

      // ✅ FINAL FALLBACK: Try one more time with local data
      Map<String, dynamic>? fallbackData = await _getUserDataLocally();
      if (fallbackData != null) {
        debugPrint("✅ Using fallback local data");
        setState(() {
          _userData = fallbackData;
          _isLoading = false;
        });
      } else {
        CustomSnackBar.errorSnackBar("Error loading user data: $e");
      }
    }

    // ✅ STEP 4: Continue with line manager check (existing logic)
    await _checkLineManagerStatus();

    debugPrint("=== FETCH USER DATA COMPLETE ===");
  }



  // ✅ NEW: Background validation of face data
  Future<void> _validateFaceDataInBackground() async {
    try {
      debugPrint("🔍 Validating face data in background...");

      final secureFaceStorage = getIt<SecureFaceStorageService>();

      // Check if face data is valid
      bool isValid = await secureFaceStorage.validateLocalFaceData(widget.employeeId);

      if (!isValid) {
        debugPrint("⚠️ Face data validation failed, attempting recovery...");

        // Attempt silent recovery
        bool recovered = await secureFaceStorage.ensureFaceDataAvailable(widget.employeeId);

        if (recovered) {
          debugPrint("✅ Face data successfully recovered in background");
          if (mounted) {
            CustomSnackBar.successSnackBar("Face data restored from cloud");
          }
        } else {
          debugPrint("❌ Face data recovery failed");
          // Don't show error for background operation - user might not need face auth immediately
        }
      } else {
        debugPrint("✅ Face data validation passed");
      }

    } catch (e) {
      debugPrint("❌ Error during background face data validation: $e");
      // Don't show error to user for background operations
    }
  }

  // ✅ NEW: Force face data recovery (for manual trigger)
  Future<void> _forceFaceDataRecovery() async {
    try {
      debugPrint("🔄 Forcing face data recovery...");

      setState(() => _isLoading = true);

      final secureFaceStorage = getIt<SecureFaceStorageService>();
      bool recovered = await secureFaceStorage.downloadFaceDataFromCloud(widget.employeeId);

      setState(() => _isLoading = false);

      if (recovered) {
        CustomSnackBar.successSnackBar("Face data successfully recovered from cloud");
      } else {
        CustomSnackBar.errorSnackBar("Failed to recover face data. Please check your connection.");
      }

    } catch (e) {
      setState(() => _isLoading = false);
      CustomSnackBar.errorSnackBar("Error recovering face data: $e");
    }
  }

// ✅ NEW: Helper method to redirect to login
  void _redirectToLogin() {
    setState(() => _isLoading = false);

    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const PinEntryView(),
          ),
              (route) => false,
        );
      }
    });
  }

// ✅ NEW: Separate line manager checking logic
  Future<void> _checkLineManagerStatus() async {
    try {
      String? employeePin = _userData?['pin']?.toString() ?? widget.employeeId;

      debugPrint("=== CHECKING LINE MANAGER STATUS ===");
      debugPrint("Current Employee ID: ${widget.employeeId}");
      debugPrint("Employee PIN: $employeePin");

      bool isLineManager = false;
      Map<String, dynamic>? foundLineManagerData;
      String? lineManagerDocId;

      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        var lineManagersSnapshot = await FirebaseFirestore.instance
            .collection('line_managers')
            .get();

        for (var doc in lineManagersSnapshot.docs) {
          Map<String, dynamic> data = doc.data();
          String managerId = data['managerId'] ?? '';

          if (managerId == widget.employeeId ||
              managerId == 'EMP${widget.employeeId}' ||
              managerId == 'EMP$employeePin' ||
              (employeePin != null && managerId == employeePin)) {
            isLineManager = true;
            lineManagerDocId = doc.id;
            foundLineManagerData = data;
            break;
          }
        }
      }

      setState(() {
        _isLineManager = isLineManager;
        _lineManagerDocumentId = lineManagerDocId;
        _lineManagerData = foundLineManagerData;
      });

      _handleLineManagerStatusDetermined(_isLineManager);

    } catch (e) {
      debugPrint("❌ ERROR checking line manager status: $e");
      setState(() {
        _isLineManager = false;
        _lineManagerData = null;
      });
    }
  }

  Future<void> _saveUserDataLocally(Map<String, dynamic> userData) async {
    try {
      Map<String, dynamic> dataCopy = Map<String, dynamic>.from(userData);

      dataCopy.forEach((key, value) {
        if (value is Timestamp) {
          dataCopy[key] = value.toDate().toIso8601String();
        }
      });

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data_${widget.employeeId}', jsonEncode(dataCopy));
      await prefs.setString('user_name_${widget.employeeId}', userData['name'] ?? '');

      debugPrint("User data saved locally for ID: ${widget.employeeId}");
    } catch (e) {
      debugPrint('Error saving user data locally: $e');
    }
  }

  Future<void> _saveEmployeeImageLocally(String employeeId, String imageBase64) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('employee_image_$employeeId', imageBase64);
      debugPrint("Employee image saved locally for ID: $employeeId");
    } catch (e) {
      debugPrint("Error saving employee image locally: $e");
    }
  }

  Future<Map<String, dynamic>?> _getUserDataLocally() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userData = prefs.getString('user_data_${widget.employeeId}');

      if (userData != null) {
        Map<String, dynamic> data = jsonDecode(userData) as Map<String, dynamic>;
        debugPrint("Retrieved complete user data from local storage");
        return data;
      }

      String? userName = prefs.getString('user_name_${widget.employeeId}');
      if (userName != null && userName.isNotEmpty) {
        return {'name': userName};
      }

      debugPrint("No local user data found for ID: ${widget.employeeId}");
      return null;
    } catch (e) {
      debugPrint('Error getting user data locally: $e');
      return null;
    }
  }

  Future<void> _fetchAttendanceStatus() async {
    try {
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final localAttendance = await _attendanceRepository.getTodaysAttendance(widget.employeeId);

      if (localAttendance != null) {
        setState(() {
          _isCheckedIn = localAttendance.checkIn != null && localAttendance.checkOut == null;
          if (_isCheckedIn && localAttendance.checkIn != null) {
            _checkInTime = DateTime.parse(localAttendance.checkIn!);
          } else {
            _checkInTime = null;
          }
        });

        debugPrint("Loaded attendance from local database: CheckedIn=$_isCheckedIn");
      }

      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        try {
          DocumentSnapshot attendanceDoc = await FirebaseFirestore.instance
              .collection('employees')
              .doc(widget.employeeId)
              .collection('attendance')
              .doc(today)
              .get()
              .timeout(const Duration(seconds: 5));

          if (attendanceDoc.exists) {
            Map<String, dynamic> data = attendanceDoc.data() as Map<String, dynamic>;

            setState(() {
              _isCheckedIn = data['checkIn'] != null && data['checkOut'] == null;
              if (_isCheckedIn && data['checkIn'] != null) {
                _checkInTime = (data['checkIn'] as Timestamp).toDate();
              } else {
                _checkInTime = null;
              }
            });

            await _saveAttendanceStatusLocally(today, data);
            debugPrint("Fetched and cached fresh attendance status from Firestore");
          }
        } catch (e) {
          debugPrint("Network error fetching attendance status: $e");
        }
      }
    } catch (e) {
      debugPrint("Error fetching attendance: $e");
      setState(() {
        _isCheckedIn = false;
        _checkInTime = null;
      });
    }
  }

  Future<void> _saveAttendanceStatusLocally(String date, Map<String, dynamic> data) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (data['checkIn'] != null && data['checkIn'] is Timestamp) {
        data['checkIn'] = (data['checkIn'] as Timestamp).toDate().toIso8601String();
      }
      if (data['checkOut'] != null && data['checkOut'] is Timestamp) {
        data['checkOut'] = (data['checkOut'] as Timestamp).toDate().toIso8601String();
      }
      await prefs.setString('attendance_${widget.employeeId}_$date', jsonEncode(data));
      debugPrint("Attendance status saved locally for date: $date");
    } catch (e) {
      debugPrint('Error saving attendance status locally: $e');
    }
  }

  Future<void> _handleCheckInOut() async {
    if (_isAuthenticating) {
      return;
    }

    await _checkGeofenceStatus();

    if (!_isCheckedIn) {
      setState(() {
        _isAuthenticating = true;
      });

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return WillPopScope(
            onWillPop: () async => false,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.8,
                child: AuthenticateFaceView(
                  employeeId: widget.employeeId,
                  onAuthenticationComplete: (bool success) async {
                    setState(() {
                      _isAuthenticating = false;
                    });

                    Navigator.of(context).pop();

                    if (success) {
                      Position? currentPosition = await GeofenceUtil.getCurrentPosition();

                      await CheckInOutHandler.handleOffLocationAction(
                        context: context,
                        employeeId: widget.employeeId,
                        employeeName: _userData?['name'] ?? 'Employee',
                        isWithinGeofence: _isWithinGeofence,
                        currentPosition: currentPosition,
                        isCheckIn: true,
                        onRegularAction: () async {
                          bool checkInSuccess = await _attendanceRepository.recordCheckIn(
                            employeeId: widget.employeeId,
                            checkInTime: DateTime.now(),
                            locationId: _nearestLocation?.id ?? 'default',
                            locationName: _nearestLocation?.name ?? 'Unknown',
                            locationLat: currentPosition?.latitude ?? _nearestLocation!.latitude,
                            locationLng: currentPosition?.longitude ?? _nearestLocation!.longitude,
                          );

                          if (checkInSuccess) {
                            setState(() {
                              _isCheckedIn = true;
                              _checkInTime = DateTime.now();

                              if (_connectivityService.currentStatus == ConnectionStatus.offline) {
                                _needsSync = true;
                              }
                            });

                            CustomSnackBar.successSnackBar("Checked in successfully at $_currentTime");

                            _fetchTodaysActivity();
                          } else {
                            CustomSnackBar.errorSnackBar("Failed to record check-in. Please try again.");
                          }
                        },
                      );
                    } else {
                      CustomSnackBar.errorSnackBar("Face authentication failed. Check-in canceled.");
                    }
                  },
                ),
              ),
            ),
          );
        },
      ).then((_) {
        if (_isAuthenticating) {
          setState(() {
            _isAuthenticating = false;
          });
        }
      });
    } else {
      setState(() {
        _isAuthenticating = true;
      });

      Position? currentPosition = await GeofenceUtil.getCurrentPosition();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async => false,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.8,
                child: AuthenticateFaceView(
                  employeeId: widget.employeeId,
                  onAuthenticationComplete: (bool success) async {
                    setState(() {
                      _isAuthenticating = false;
                    });

                    Navigator.of(context).pop();

                    if (success) {
                      Position? currentPosition = await GeofenceUtil.getCurrentPosition();

                      await CheckInOutHandler.handleOffLocationAction(
                        context: context,
                        employeeId: widget.employeeId,
                        employeeName: _userData?['name'] ?? 'Employee',
                        isWithinGeofence: _isWithinGeofence,
                        currentPosition: currentPosition,
                        isCheckIn: false,
                        onRegularAction: () async {
                          bool checkOutSuccess = await _attendanceRepository.recordCheckOut(
                            employeeId: widget.employeeId,
                            checkOutTime: DateTime.now(),
                          );

                          if (checkOutSuccess) {
                            setState(() {
                              _isCheckedIn = false;
                              _checkInTime = null;

                              if (_connectivityService.currentStatus == ConnectionStatus.offline) {
                                _needsSync = true;
                              }
                            });

                            CustomSnackBar.successSnackBar("Checked out successfully at $_currentTime");

                            await _fetchAttendanceStatus();
                            await _fetchTodaysActivity();
                          } else {
                            CustomSnackBar.errorSnackBar("Failed to record check-out. Please try again.");
                          }
                        },
                      );
                    } else {
                      CustomSnackBar.errorSnackBar("Face authentication failed. Check-out canceled.");
                    }
                  },
                ),
              ),
            ),
          );
        },
      ).then((_) {
        if (_isAuthenticating) {
          setState(() {
            _isAuthenticating = false;
          });
        }
      });
    }
  }

  Future<void> _refreshDashboard() async {
    await _fetchUserData();
    await _fetchAttendanceStatus();
    await _fetchTodaysActivity(); // Changed from _fetchRecentActivity
    await _checkGeofenceStatus();

    if (_connectivityService.currentStatus == ConnectionStatus.online) {
      final pendingRecords = await _attendanceRepository.getPendingRecords();
      setState(() {
        _needsSync = pendingRecords.isNotEmpty;
      });
    }

    if (_isLineManager) {
      await _loadPendingApprovalRequests();
      await _loadPendingLeaveApprovals();
    }
  }

  Future<void> _manualSync() async {
    if (_connectivityService.currentStatus == ConnectionStatus.offline) {
      CustomSnackBar.errorSnackBar("Cannot sync while offline. Please check your connection.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _syncService.manualSync();

      await _fetchUserData();
      await _fetchAttendanceStatus();
      await _fetchTodaysActivity(); // Changed from _fetchRecentActivity

      setState(() {
        _needsSync = false;
        _isLoading = false;
      });

      CustomSnackBar.successSnackBar("Data synchronized successfully");
    } catch (e) {
      setState(() => _isLoading = false);
      CustomSnackBar.errorSnackBar("Error during sync: $e");
    }
  }

  Future<void> _logout() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Logout",
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Are you sure you want to logout?",
          style: TextStyle(
            color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Logout"),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        if (_needsSync && _connectivityService.currentStatus == ConnectionStatus.online) {
          bool syncFirst = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                "Unsynchronized Data",
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                "You have data that hasn't been synchronized. Would you like to sync before logging out?",
                style: TextStyle(
                  color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text("No", style: TextStyle(color: Colors.grey.shade600)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Yes"),
                ),
              ],
            ),
          ) ?? false;

          if (syncFirst) {
            await _manualSync();
          }
        }

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove('authenticated_user_id');

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const PinEntryView(),
            ),
                (route) => false,
          );
        }
      } catch (e) {
        CustomSnackBar.errorSnackBar("Error during logout: $e");
      }
    }
  }

  // Settings Menu
  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: EdgeInsets.all(isTablet ? 28 : 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.settings,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: (isTablet ? 28 : 24) * responsiveFontSize,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // Settings options
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 28 : 24),
                child: Column(
                  children: [
                    _buildModernSettingsOption(
                      icon: Icons.calendar_view_month,
                      title: 'My Attendance',
                      subtitle: 'View your attendance history and overtime records',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MyAttendanceView(
                              employeeId: widget.employeeId,
                              userData: _userData ?? {},
                            ),
                          ),
                        );
                      },
                    ),

                    _buildModernSettingsOption(
                      icon: Icons.cloud_download,
                      title: 'Recover Face Data',
                      subtitle: 'Download face authentication data from cloud',
                      iconColor: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        _forceFaceDataRecovery();
                      },
                    ),

                    _buildModernSettingsOption(
                      icon: Icons.event_note,
                      title: 'Leave Management',
                      subtitle: 'View leave balance, history, and apply for leave',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LeaveHistoryView(
                              employeeId: widget.employeeId,
                              employeeName: _userData?['name'] ?? 'Employee',
                              employeePin: _userData?['pin'] ?? widget.employeeId,
                              userData: _userData ?? {},
                            ),
                          ),
                        ).then((_) => _refreshDashboard());
                      },
                    ),

                    _buildModernSettingsOption(
                      icon: Icons.dark_mode_outlined,
                      title: 'Dark mode',
                      subtitle: 'Switch between light and dark themes',
                      hasToggle: true,
                      toggleValue: _isDarkMode,
                      onToggleChanged: (value) {
                        setState(() {
                          _isDarkMode = value;
                          _saveDarkModePreference(value);
                        });
                      },
                    ),

                    if (_userData != null &&
                        (_userData!['hasOvertimeAccess'] == true ||
                            _userData!['overtimeAccessGrantedAt'] != null))
                      _buildModernSettingsOption(
                        icon: Icons.people_outline,
                        title: 'Manage Employee List',
                        subtitle: 'Create custom employee list for overtime requests',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EmployeeListManagementView(
                                requesterId: widget.employeeId,
                              ),
                            ),
                          );
                        },
                      ),

                    _buildModernSettingsOption(
                      icon: Icons.history,
                      title: 'Check-Out Request History',
                      subtitle: 'View your remote check-out requests',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => CheckOutRequestHistoryView(
                              employeeId: widget.employeeId,
                            ),
                          ),
                        );
                      },
                    ),

                    if (widget.employeeId == 'EMP1289')
                      _buildModernSettingsOption(
                        icon: Icons.admin_panel_settings,
                        title: 'Admin Panel',
                        subtitle: 'Administrative controls',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NotificationAdminView(
                                userId: widget.employeeId,
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 20),

                    _buildModernSettingsOption(
                      icon: Icons.logout,
                      title: 'Log out',
                      subtitle: 'Sign out of your account',
                      textColor: Colors.red,
                      iconColor: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                        _logout();
                      },
                    ),

                    SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSettingsOption({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool hasToggle = false,
    bool toggleValue = false,
    Function(bool)? onToggleChanged,
    Color? iconColor,
    Color? textColor,
  }) {
    final effectiveIconColor = iconColor ?? (_isDarkMode ? Colors.white70 : Colors.black54);
    final effectiveTextColor = textColor ?? (_isDarkMode ? Colors.white : Colors.black87);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF334155) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasToggle ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: effectiveIconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: effectiveIconColor, size: 20),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                          fontWeight: FontWeight.w600,
                          color: effectiveTextColor,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                            color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (hasToggle)
                  Switch.adaptive(
                    value: toggleValue,
                    onChanged: onToggleChanged,
                    activeColor: Theme.of(context).colorScheme.primary,
                  )
                else if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: _isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Notification Menu
  void _showNotificationMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: EdgeInsets.all(isTablet ? 28 : 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.notifications,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Notifications & Actions',
                    style: TextStyle(
                      fontSize: (isTablet ? 28 : 24) * responsiveFontSize,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // Notification options
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 28 : 24),
                child: Column(
                  children: [
                    // Leave management section
                    _buildNotificationOption(
                      icon: Icons.event_available,
                      title: 'Apply for Leave',
                      subtitle: 'Submit a new leave application',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ApplyLeaveView(
                              employeeId: widget.employeeId,
                              employeeName: _userData?['name'] ?? 'Employee',
                              employeePin: _userData?['pin'] ?? widget.employeeId,
                              userData: _userData ?? {},
                            ),
                          ),
                        ).then((_) => _refreshDashboard());
                      },
                    ),

                    _buildNotificationOption(
                      icon: Icons.history,
                      title: 'Leave History',
                      subtitle: 'View your leave applications and balance',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LeaveHistoryView(
                              employeeId: widget.employeeId,
                              employeeName: _userData?['name'] ?? 'Employee',
                              employeePin: _userData?['pin'] ?? widget.employeeId,
                              userData: _userData ?? {},
                            ),
                          ),
                        ).then((_) => _refreshDashboard());
                      },
                    ),

                    // Leave approvals for line managers
                    if (_isLineManager)
                      _buildNotificationOption(
                        icon: Icons.approval,
                        title: 'Leave Approvals',
                        subtitle: _pendingLeaveApprovals > 0
                            ? '$_pendingLeaveApprovals applications waiting'
                            : 'No pending leave applications',
                        showBadge: _pendingLeaveApprovals > 0,
                        badgeCount: _pendingLeaveApprovals,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ManagerLeaveApprovalView(
                                managerId: widget.employeeId,
                                managerName: _userData?['name'] ?? 'Manager',
                              ),
                            ),
                          ).then((_) => _loadPendingLeaveApprovals());
                        },
                      ),

                    // Overtime section
                    if (_isOvertimeApprover && _approverInfo != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(isTablet ? 20 : 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange.withOpacity(0.8), Colors.red.withOpacity(0.8)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "OVERTIME APPROVER",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (_pendingOvertimeRequests > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _pendingOvertimeRequests.toString(),
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PendingOvertimeView(
                                        approverId: widget.employeeId,
                                      ),
                                    ),
                                  ).then((_) => _loadPendingOvertimeRequests());
                                },
                                icon: const Icon(Icons.visibility),
                                label: Text("Review $_pendingOvertimeRequests Pending Requests"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.red,
                                  padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_userData != null &&
                        (_userData!['hasOvertimeAccess'] == true ||
                            _userData!['overtimeAccessGrantedAt'] != null))
                      _buildNotificationOption(
                        icon: Icons.access_time,
                        title: 'Request Overtime',
                        subtitle: 'Create new overtime request',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateOvertimeView(
                                requesterId: widget.employeeId,
                              ),
                            ),
                          );
                        },
                      ),

                    // Line manager options
                    if (_isLineManager) ...[
                      _buildNotificationOption(
                        icon: Icons.people_outline,
                        title: 'My Team',
                        subtitle: 'View team members and attendance',
                        onTap: () {
                          Navigator.pop(context);
                          if (_lineManagerData != null) {
                            String managerId = _lineManagerData!['managerId'] ?? '';
                            if (managerId.isNotEmpty) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => TeamManagementView(
                                    managerId: managerId,
                                    managerData: _userData!,
                                  ),
                                ),
                              );
                            } else {
                              CustomSnackBar.errorSnackBar(context, "Manager ID not found");
                            }
                          }
                        },
                      ),

                      _buildNotificationOption(
                        icon: Icons.approval,
                        title: 'Pending Check-Out Requests',
                        subtitle: _pendingApprovalRequests > 0
                            ? '$_pendingApprovalRequests requests waiting'
                            : 'No pending requests',
                        showBadge: _pendingApprovalRequests > 0,
                        badgeCount: _pendingApprovalRequests,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ManagerPendingRequestsView(
                                managerId: widget.employeeId,
                              ),
                            ),
                          ).then((_) => _loadPendingApprovalRequests());
                        },
                      ),
                    ],

                    SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationOption({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool showBadge = false,
    int badgeCount = 0,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF334155) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Row(
              children: [
                Stack(
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
                    if (showBadge && badgeCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            badgeCount > 99 ? '99+' : badgeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                          fontWeight: FontWeight.w600,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                            color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: _isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Location Menu
  void _showLocationMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: EdgeInsets.all(isTablet ? 28 : 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Available Locations',
                        style: TextStyle(
                          fontSize: (isTablet ? 28 : 24) * responsiveFontSize,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _checkGeofenceStatus();
                        CustomSnackBar.successSnackBar(context, "Locations refreshed");
                      },
                      icon: Icon(
                        Icons.refresh,
                        color: _isDarkMode ? Colors.white : Colors.black87,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),

              // Locations list
              Expanded(
                child: _availableLocations.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(isTablet ? 24 : 20),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.location_off,
                          size: isTablet ? 64 : 48,
                          color: _isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No locations available",
                        style: TextStyle(
                          color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: (isTablet ? 20 : 18) * responsiveFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(horizontal: isTablet ? 28 : 24),
                  itemCount: _availableLocations.length,
                  itemBuilder: (context, index) {
                    final location = _availableLocations[index];
                    final isNearest = _nearestLocation?.id == location.id;
                    final isWithin = _isWithinGeofence && isNearest;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isWithin
                            ? Colors.green.withOpacity(0.1)
                            : (_isDarkMode ? const Color(0xFF334155) : Colors.grey.shade50),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isWithin
                              ? Colors.green
                              : (_isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2)),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isTablet ? 20 : 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isWithin
                                    ? Colors.green.withOpacity(0.2)
                                    : (_isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isWithin
                                    ? Icons.location_on
                                    : isNearest
                                    ? Icons.location_searching
                                    : Icons.location_on_outlined,
                                color: isWithin
                                    ? Colors.green
                                    : (_isDarkMode ? Colors.white70 : Colors.grey.shade600),
                                size: 24,
                              ),
                            ),

                            const SizedBox(width: 16),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    location.name,
                                    style: TextStyle(
                                      fontWeight: isNearest ? FontWeight.bold : FontWeight.w600,
                                      fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                                      color: _isDarkMode ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    location.address,
                                    style: TextStyle(
                                      color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                      fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (location.radius > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Radius: ${location.radius.toInt()}m',
                                      style: TextStyle(
                                        color: _isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                                        fontSize: (isTablet ? 12 : 11) * responsiveFontSize,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (isWithin)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'CURRENT',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: (isTablet ? 12 : 10) * responsiveFontSize,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else if (isNearest)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'NEAREST',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: (isTablet ? 12 : 10) * responsiveFontSize,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (_distanceToOffice != null && isNearest) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_distanceToOffice!.toStringAsFixed(0)}m',
                                      style: TextStyle(
                                        color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                        fontSize: (isTablet ? 12 : 11) * responsiveFontSize,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // All existing notification and overtime methods remain the same
  Future<void> _initializeNotifications() async {
    try {
      final notificationService = getIt<NotificationService>();
      final fcmTokenService = getIt<FcmTokenService>();
      await fcmTokenService.registerTokenForUser(widget.employeeId);
      await notificationService.subscribeToEmployeeTopic(widget.employeeId);
      debugPrint("Dashboard: Initialized notifications for employee ${widget.employeeId}");
    } catch (e) {
      debugPrint("Dashboard: Error initializing notifications: $e");
    }
  }

  void _handleLineManagerStatusDetermined(bool isManager) {
    if (isManager) {
      try {
        final notificationService = getIt<NotificationService>();
        notificationService.subscribeToManagerTopic('manager_${widget.employeeId}');

        if (widget.employeeId.startsWith('EMP')) {
          notificationService.subscribeToManagerTopic('manager_${widget.employeeId.substring(3)}');
        }

        debugPrint("Dashboard: Subscribed to manager notifications");
        _loadPendingApprovalRequests();
        _loadPendingLeaveApprovals();
      } catch (e) {
        debugPrint("Dashboard: Error subscribing to manager notifications: $e");
      }
    }
  }

  Future<void> _loadPendingApprovalRequests() async {
    if (!_isLineManager) return;

    try {
      final repository = getIt<CheckOutRequestRepository>();
      final requests = await repository.getPendingRequestsForManager(widget.employeeId);

      setState(() {
        _pendingApprovalRequests = requests.length;
      });
    } catch (e) {
      debugPrint('Error loading pending approval requests: $e');
    }
  }

  // All existing overtime methods
  Future<void> _checkOvertimeApproverStatus() async {
    setState(() => _checkingApproverStatus = true);

    try {
      debugPrint("=== CHECKING OVERTIME APPROVER STATUS (SIMPLIFIED) ===");
      debugPrint("Current Employee: ${widget.employeeId}");

      bool isApprover = await OvertimeApproverService.isApprover(widget.employeeId);

      if (isApprover) {
        debugPrint("✅ User IS an overtime approver");

        Map<String, dynamic>? approverInfo = await OvertimeApproverService.getCurrentApprover();
        await _setupApproverNotifications();

        setState(() {
          _isOvertimeApprover = true;
          _approverInfo = approverInfo;
          _checkingApproverStatus = false;
        });

        await _loadPendingOvertimeRequests();
        debugPrint("✅ Approver setup completed successfully");
      } else {
        debugPrint("❌ User is NOT an overtime approver");
        setState(() {
          _isOvertimeApprover = false;
          _approverInfo = null;
          _checkingApproverStatus = false;
        });
      }

    } catch (e) {
      debugPrint("Error checking approver status: $e");
      setState(() {
        _isOvertimeApprover = false;
        _approverInfo = null;
        _checkingApproverStatus = false;
      });
    }
  }

  Future<void> _setupApproverNotifications() async {
    try {
      debugPrint("=== SETTING UP APPROVER NOTIFICATIONS ===");
      debugPrint("Setting up notifications for: ${widget.employeeId}");

      final fcmTokenService = getIt<FcmTokenService>();
      final notificationService = getIt<NotificationService>();

      await fcmTokenService.registerTokenForUser(widget.employeeId);

      if (widget.employeeId.startsWith('EMP')) {
        String altId = widget.employeeId.substring(3);
        await fcmTokenService.registerTokenForUser(altId);
        debugPrint("Also registered FCM for alt ID: $altId");
      }

      await notificationService.subscribeToTopic('overtime_requests');
      await notificationService.subscribeToTopic('overtime_approver_${widget.employeeId}');
      await notificationService.subscribeToTopic('all_overtime_approvers');

      if (widget.employeeId.startsWith('EMP')) {
        String altId = widget.employeeId.substring(3);
        await notificationService.subscribeToTopic('overtime_approver_$altId');
      }

      DocumentSnapshot tokenDoc = await FirebaseFirestore.instance
          .collection('fcm_tokens')
          .doc(widget.employeeId)
          .get();

      if (tokenDoc.exists) {
        debugPrint("✅ FCM token verified in Firestore for ${widget.employeeId}");
        var tokenData = tokenDoc.data() as Map<String, dynamic>;
        debugPrint("Token: ${tokenData['token']?.substring(0, 20) ?? 'null'}...");
      } else {
        debugPrint("⚠️ FCM token NOT found in Firestore, forcing refresh...");
        await fcmTokenService.forceTokenRefresh(widget.employeeId);
      }

      debugPrint("✅ Approver notification setup completed");

    } catch (e) {
      debugPrint("❌ Error setting up approver notifications: $e");
    }
  }

  Future<void> _setupOvertimeApproverIfNeeded() async {
    try {
      debugPrint("=== CHECKING IF USER IS OVERTIME APPROVER ===");
      debugPrint("Current Employee: ${widget.employeeId}");

      bool shouldBeApprover = await _checkIfShouldBeOvertimeApprover();

      if (shouldBeApprover) {
        debugPrint("✅ User should be overtime approver, setting up...");

        final fcmTokenService = getIt<FcmTokenService>();
        await fcmTokenService.forceTokenRefresh(widget.employeeId);

        if (widget.employeeId.startsWith('EMP')) {
          await fcmTokenService.registerTokenForUser(widget.employeeId.substring(3));
        } else {
          await fcmTokenService.registerTokenForUser('EMP${widget.employeeId}');
        }

        await _setupAsOvertimeApprover();

        final notificationService = getIt<NotificationService>();
        await notificationService.subscribeToTopic('overtime_requests');
        await notificationService.subscribeToTopic('overtime_approver_${widget.employeeId}');

        String altId = widget.employeeId.startsWith('EMP')
            ? widget.employeeId.substring(3)
            : 'EMP${widget.employeeId}';
        await notificationService.subscribeToTopic('overtime_approver_$altId');

        await notificationService.subscribeToTopic('all_employees');

        debugPrint("✅ Approver setup completed successfully");
      } else {
        debugPrint("ℹ️ User is not an overtime approver");
      }
    } catch (e) {
      debugPrint("Error in overtime approver setup: $e");
    }
  }

  Future<bool> _checkIfShouldBeOvertimeApprover() async {
    try {
      DocumentSnapshot approverDoc = await FirebaseFirestore.instance
          .collection('overtime_approvers')
          .doc(widget.employeeId)
          .get();

      if (approverDoc.exists) {
        Map<String, dynamic> data = approverDoc.data() as Map<String, dynamic>;
        if (data['isActive'] == true) {
          debugPrint("Found in overtime_approvers collection");
          return true;
        }
      }

      DocumentSnapshot empDoc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .get();

      if (empDoc.exists) {
        Map<String, dynamic> data = empDoc.data() as Map<String, dynamic>;
        if (data['hasOvertimeApprovalAccess'] == true) {
          debugPrint("Found hasOvertimeApprovalAccess in employees collection");
          return true;
        }
      }

      DocumentSnapshot masterDoc = await FirebaseFirestore.instance
          .collection('MasterSheet')
          .doc('Employee-Data')
          .collection('employees')
          .doc(widget.employeeId)
          .get();

      if (masterDoc.exists) {
        Map<String, dynamic> data = masterDoc.data() as Map<String, dynamic>;
        if (data['hasOvertimeApprovalAccess'] == true) {
          debugPrint("Found hasOvertimeApprovalAccess in MasterSheet");
          return true;
        }
      }

      QuerySnapshot managerQuery = await FirebaseFirestore.instance
          .collection('line_managers')
          .where('managerId', isEqualTo: widget.employeeId)
          .where('canApproveOvertime', isEqualTo: true)
          .limit(1)
          .get();

      if (managerQuery.docs.isNotEmpty) {
        debugPrint("Found as line manager with overtime approval");
        return true;
      }

      if (widget.employeeId == 'EMP1289') {
        debugPrint("Default approver EMP1289 detected");
        return true;
      }

      return false;
    } catch (e) {
      debugPrint("Error checking overtime approver status: $e");
      return false;
    }
  }

  Future<void> _setupAsOvertimeApprover() async {
    try {
      debugPrint("Setting up ${widget.employeeId} as overtime approver");

      String employeeName = _userData?['name'] ?? _userData?['employeeName'] ?? 'Overtime Approver';

      final callable = FirebaseFunctions.instance.httpsCallable('setupOvertimeApprover');
      final result = await callable.call({
        'employeeId': widget.employeeId,
        'employeeName': employeeName,
      });

      if (result.data['success'] == true) {
        debugPrint("✅ Overtime approver setup successful");
        await _setupOvertimeNotifications();
        CustomSnackBar.successSnackBar(context, "You are now set up as an overtime approver!");
      } else {
        debugPrint("❌ Overtime approver setup failed");
        CustomSnackBar.errorSnackBar(context, "Failed to set up as overtime approver");
      }
    } catch (e) {
      debugPrint("Error setting up overtime approver: $e");
      CustomSnackBar.errorSnackBar(context, "Error setting up approver: $e");
    }
  }

  Future<void> _setupOvertimeNotifications() async {
    try {
      debugPrint("Setting up overtime notifications for ${widget.employeeId}");

      final notificationService = getIt<NotificationService>();
      final fcmTokenService = getIt<FcmTokenService>();

      await fcmTokenService.registerTokenForUser(widget.employeeId);

      await notificationService.subscribeToTopic('overtime_requests');
      await notificationService.subscribeToTopic('overtime_approver_${widget.employeeId}');

      String altId = widget.employeeId.startsWith('EMP')
          ? widget.employeeId.substring(3)
          : 'EMP${widget.employeeId}';
      await notificationService.subscribeToTopic('overtime_approver_$altId');

      final callable = FirebaseFunctions.instance.httpsCallable('registerOvertimeApproverToken');

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('fcm_token');

      if (token != null) {
        await callable.call({
          'approverId': widget.employeeId,
          'token': token,
          'approverName': _userData?['name'] ?? _userData?['employeeName'] ?? 'Overtime Approver',
        });

        debugPrint("✅ Overtime notification setup completed");
      } else {
        debugPrint("⚠️ No FCM token available for registration");
      }
    } catch (e) {
      debugPrint("Error setting up overtime notifications: $e");
    }
  }

  Future<void> _loadPendingOvertimeRequests() async {
    if (!_isOvertimeApprover) return;

    try {
      debugPrint("=== LOADING PENDING OVERTIME REQUESTS ===");
      debugPrint("Loading for approver: ${widget.employeeId}");

      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('overtime_requests')
          .where('status', isEqualTo: 'pending')
          .where('approverEmpId', whereIn: [
        widget.employeeId,
        'EMP${widget.employeeId}',
        widget.employeeId.startsWith('EMP') ? widget.employeeId.substring(3) : widget.employeeId
      ])
          .get();

      debugPrint("Found ${snapshot.docs.length} pending overtime requests");

      setState(() {
        _pendingOvertimeRequests = snapshot.docs.length;
      });

    } catch (e) {
      debugPrint("Error loading pending overtime requests: $e");
      setState(() {
        _pendingOvertimeRequests = 0;
      });
    }
  }

  Future<void> _setupOvertimeApproverNotifications() async {
    if (widget.employeeId != 'EMP1289') return;

    try {
      print("=== SETTING UP OVERTIME APPROVER NOTIFICATIONS ===");

      final fcmTokenService = getIt<FcmTokenService>();
      await fcmTokenService.registerTokenForUser('EMP1289');
      await fcmTokenService.registerTokenForUser('1289');

      final notificationService = getIt<NotificationService>();
      await notificationService.subscribeToTopic('overtime_approver_EMP1289');
      await notificationService.subscribeToTopic('overtime_approver_1289');
      await notificationService.subscribeToTopic('overtime_requests');
      await notificationService.subscribeToTopic('all_overtime_approvers');

      final tokenDoc = await FirebaseFirestore.instance
          .collection('fcm_tokens')
          .doc('EMP1289')
          .get();

      if (tokenDoc.exists) {
        print("✅ EMP1289 FCM token verified: ${tokenDoc.data()}");
      } else {
        print("❌ EMP1289 FCM token not found, attempting force refresh");
        await fcmTokenService.forceTokenRefresh('EMP1289');
      }

      print("=== OVERTIME APPROVER SETUP COMPLETE ===");
    } catch (e) {
      print("Error setting up overtime approver notifications: $e");
    }
  }

  void _handleNotification(Map<String, dynamic> data) {
    final notificationType = data['type'];
    debugPrint("=== NOTIFICATION RECEIVED ===");
    debugPrint("Type: $notificationType");
    debugPrint("Data: $data");
    debugPrint("Current Employee: ${widget.employeeId}");

    // ===== REST TIMING SCHEDULE NOTIFICATIONS =====
    if (notificationType == 'rest_timing_schedule') {
      debugPrint("⚠️ REST TIMING SCHEDULE NOTIFICATION RECEIVED");

      final String scheduleTitle = data['scheduleTitle'] ?? 'Rest Timing Schedule';
      final String scheduleReason = data['scheduleReason'] ?? '';
      final String startDate = data['startDate'] ?? '';
      final String endDate = data['endDate'] ?? '';
      final String restStartTime = data['restStartTime'] ?? '';
      final String restEndTime = data['restEndTime'] ?? '';
      final String status = data['status'] ?? '';
      final String scheduleId = data['scheduleId'] ?? '';

      // Show different messages based on status
      String title, message;
      Color backgroundColor;
      IconData iconData;

      if (status == 'active') {
        title = "🕐 Rest Timing Active!";
        message = "Your rest timing schedule is now active";
        backgroundColor = Colors.green;
        iconData = Icons.play_circle;
      } else if (status == 'scheduled') {
        title = "📅 Rest Timing Scheduled";
        message = "New rest timing schedule created for you";
        backgroundColor = Colors.blue;
        iconData = Icons.schedule;
      } else {
        title = "Rest Timing Update";
        message = "Rest timing schedule has been updated";
        backgroundColor = Colors.orange;
        iconData = Icons.update;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [backgroundColor, backgroundColor.withOpacity(0.8)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  iconData,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: (isTablet ? 20 : 18) * responsiveFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildNotificationDetailRow("Schedule:", scheduleTitle),
                if (scheduleReason.isNotEmpty)
                  _buildNotificationDetailRow("Reason:", scheduleReason),
                _buildNotificationDetailRow("Period:", "$startDate to $endDate"),
                _buildNotificationDetailRow("Rest Time:", "$restStartTime - $restEndTime"),
                _buildNotificationDetailRow("Status:", status.toUpperCase()),
                if (scheduleId.isNotEmpty)
                  _buildNotificationDetailRow("Schedule ID:", scheduleId.substring(0, 8) + "..."),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: backgroundColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: backgroundColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: backgroundColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            status == 'active' ? "Effective Immediately" : "Schedule Information",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                              fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        status == 'active'
                            ? "This rest timing schedule is now in effect. Please follow the specified rest hours during your work day."
                            : "This rest timing schedule will be effective from the start date. You'll be notified when it becomes active.",
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Later", style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.visibility),
              label: const Text("View Details"),
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _showRestTimingDetails(data);
              },
            ),
          ],
        ),
      );

      // Refresh dashboard to show updated data
      _refreshDashboard();
    }

    // ===== LEAVE APPLICATION NOTIFICATIONS =====
    else if (notificationType == 'leave_application') {
      debugPrint("⚠️ LEAVE APPLICATION NOTIFICATION RECEIVED");

      final String employeeName = data['employeeName'] ?? 'Someone';
      final String leaveType = data['leaveType'] ?? 'leave';
      final String totalDays = data['totalDays'] ?? '0';
      final String applicationId = data['applicationId'] ?? '';

      if (_isLineManager) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.green],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_available, color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "New Leave Application!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (isTablet ? 20 : 18) * responsiveFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildNotificationDetailRow("Employee:", employeeName),
                  _buildNotificationDetailRow("Leave Type:", leaveType),
                  _buildNotificationDetailRow("Duration:", "$totalDays days"),
                  _buildNotificationDetailRow("Application ID:", applicationId),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.timer, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "Action Required",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                                fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "This leave application needs your approval. Please review the details carefully before making a decision.",
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Later", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.visibility),
                label: const Text("Review Now"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManagerLeaveApprovalView(
                        managerId: widget.employeeId,
                        managerName: _userData?['name'] ?? 'Manager',
                      ),
                    ),
                  ).then((_) => _loadPendingLeaveApprovals());
                },
              ),
            ],
          ),
        );

        _loadPendingLeaveApprovals();
      }
    }

    // ===== LEAVE APPLICATION STATUS UPDATE =====
    else if (notificationType == 'leave_application_update') {
      debugPrint("⚠️ LEAVE STATUS UPDATE NOTIFICATION RECEIVED");

      final String status = data['status'] ?? '';
      final String leaveType = data['leaveType'] ?? 'leave';
      final String comments = data['comments'] ?? '';

      final bool isApproved = status == 'approved';

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isApproved ? Icons.check_circle : Icons.cancel,
                color: isApproved ? Colors.green : Colors.red,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isApproved ? "Leave Application Approved!" : "Leave Application Rejected",
                  style: TextStyle(
                    color: isApproved ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isApproved
                    ? "Your $leaveType application has been approved."
                    : "Your $leaveType application has been rejected.",
                style: TextStyle(
                  fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                  color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              if (comments.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isApproved ? Colors.green : Colors.red).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (isApproved ? Colors.green : Colors.red).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Manager Comments:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isApproved ? Colors.green.shade800 : Colors.red.shade800,
                          fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        comments,
                        style: TextStyle(
                          color: isApproved ? Colors.green.shade700 : Colors.red.shade700,
                          fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: isApproved ? Colors.green : Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }

    // ===== CHECK-OUT REQUEST NOTIFICATIONS =====
    else if (notificationType == 'check_out_request_update') {
      final String status = data['status'] ?? '';
      final String requestType = data['requestType'] ?? 'check-out';
      final String message = data['message'] ?? '';

      if (_isLineManager) {
        _loadPendingApprovalRequests();
      }

      final bool isApproved = status == 'approved';
      CustomSnackBar.successSnackBar(
          isApproved
              ? "Your ${requestType.replaceAll('-', ' ')} request has been approved"
              : "Your ${requestType.replaceAll('-', ' ')} request has been rejected${message.isNotEmpty ? ': $message' : ''}"
      );
    }
    else if (notificationType == 'new_check_out_request') {
      final String employeeName = data['employeeName'] ?? 'An employee';
      final String requestType = data['requestType'] ?? 'check-out';

      if (_isLineManager) {
        _loadPendingApprovalRequests();
        CustomSnackBar.successSnackBar(
            "$employeeName has requested to ${requestType.replaceAll('-', ' ')} from an offsite location"
        );

        if (data['fromNotificationTap'] == 'true') {
          _navigateToPendingRequests();
        }
      }
    }

    // ===== OVERTIME NOTIFICATIONS =====
    else if (notificationType == 'overtime_request') {
      debugPrint("⚠️ OVERTIME REQUEST NOTIFICATION RECEIVED");

      if (_isOvertimeApprover) {
        final String projectName = data['projectName'] ?? 'Project';
        final String requesterName = data['requesterName'] ?? 'Someone';
        final String employeeCount = data['employeeCount'] ?? '0';

        CustomSnackBar.successSnackBar(
            "$requesterName requested overtime for $employeeCount employees in $projectName"
        );

        _loadPendingOvertimeRequests();
      }
    }
    else if (notificationType == 'overtime_request_update') {
      final String status = data['status'] ?? '';
      final String projectName = data['projectName'] ?? '';
      final String message = data['message'] ?? '';

      final bool isApproved = status == 'approved';
      CustomSnackBar.successSnackBar(
          isApproved
              ? "Your overtime request for $projectName has been approved"
              : "Your overtime request for $projectName has been rejected${message.isNotEmpty ? ': $message' : ''}"
      );
    }

    // Refresh dashboard for all notifications
    _refreshDashboard();
    debugPrint("=== NOTIFICATION HANDLED ===");
  }





// Helper method to show rest timing details
  void _showRestTimingDetails(Map<String, dynamic> scheduleData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.schedule, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Rest Timing Schedule Details",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontSize: (isTablet ? 20 : 18) * responsiveFontSize,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow("Schedule:", scheduleData['scheduleTitle'] ?? ''),
              _buildDetailRow("Reason:", scheduleData['scheduleReason'] ?? ''),
              _buildDetailRow("Start Date:", scheduleData['startDate'] ?? ''),
              _buildDetailRow("End Date:", scheduleData['endDate'] ?? ''),
              _buildDetailRow("Rest Time:", "${scheduleData['restStartTime']} - ${scheduleData['restEndTime']}"),
              _buildDetailRow("Status:", (scheduleData['status'] ?? '').toUpperCase()),
              if (scheduleData['scheduleId']?.isNotEmpty == true)
                _buildDetailRow("Schedule ID:", scheduleData['scheduleId'].substring(0, 8) + "..."),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text("Refresh Data"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _refreshDashboard();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not specified' : value,
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
                fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: _isDarkMode ? Colors.white : Colors.black87,
                fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPendingRequests() {
    if (_isLineManager) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ManagerPendingRequestsView(
            managerId: widget.employeeId,
          ),
        ),
      ).then((_) => _loadPendingApprovalRequests());
    }
  }
}

// App lifecycle observer class
class AppLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback? onResume;

  AppLifecycleObserver({this.onResume});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && onResume != null) {
      onResume!();
    }
  }
}