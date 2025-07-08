// lib/dashboard/my_attendance_view.dart - IMPROVED UI/UX VERSION

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:phoenician_face_auth/constants/theme.dart';
import 'package:phoenician_face_auth/common/utils/custom_snackbar.dart';
import 'package:phoenician_face_auth/model/overtime_request_model.dart';
import 'package:phoenician_face_auth/services/employee_overtime_service.dart';
import 'package:phoenician_face_auth/services/service_locator.dart';

class MyAttendanceView extends StatefulWidget {
  final String employeeId;
  final Map<String, dynamic> userData;

  const MyAttendanceView({
    Key? key,
    required this.employeeId,
    required this.userData,
  }) : super(key: key);

  @override
  State<MyAttendanceView> createState() => _MyAttendanceViewState();
}

class _MyAttendanceViewState extends State<MyAttendanceView> with TickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  // Services
  late EmployeeOvertimeService _overtimeService;

  // Attendance data
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _isLoadingAttendance = true;
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());

  // Overtime data
  List<OvertimeRequest> _overtimeHistory = [];
  List<OvertimeRequest> _filteredOvertimeHistory = [];
  List<OvertimeRequest> _todayOvertimeRequests = [];
  bool _isLoadingOvertime = true;
  bool _hasOvertimeAccess = false;
  Map<String, dynamic> _overtimeStatistics = {};

  // Filter and search for overtime
  String _overtimeSearchQuery = '';
  OvertimeRequestStatus? _selectedOvertimeStatus;

  @override
  void initState() {
    super.initState();

    // Initialize with single tab first, will update after checking overtime access
    _tabController = TabController(length: 1, vsync: this);

    // Start initialization process
    _initializeEverything();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ===== INITIALIZATION METHODS =====
  Future<void> _initializeEverything() async {
    try {
      debugPrint("🚀 === INITIALIZING ATTENDANCE VIEW FOR ${widget.employeeId} ===");

      // Step 1: Initialize services
      await _initializeServices();

      // Step 2: Check overtime access
      await _checkOvertimeAccess();

      // Step 3: Fetch initial data
      await _fetchInitialData();

    } catch (e) {
      debugPrint("❌ Error during initialization: $e");
      // Fallback to attendance only
      _setupAttendanceOnlyView();
    }
  }

  Future<void> _initializeServices() async {
    try {
      debugPrint("🔧 Initializing services...");

      // Try to get the service from GetIt
      _overtimeService = getIt<EmployeeOvertimeService>();
      debugPrint("✅ Successfully got EmployeeOvertimeService from GetIt");

    } catch (e) {
      debugPrint("❌ Error getting service from GetIt: $e");
      debugPrint("🔄 Creating fallback EmployeeOvertimeService instance");

      // Fallback: create new instance
      _overtimeService = EmployeeOvertimeService();
      debugPrint("✅ Fallback service created successfully");
    }
  }

  Future<void> _checkOvertimeAccess() async {
    try {
      debugPrint("🔐 Checking overtime access for ${widget.employeeId}...");

      // Check if employee has overtime access
      bool hasAccess = await _overtimeService.hasOvertimeAccess(widget.employeeId);
      debugPrint("📋 Overtime access result: $hasAccess");

      // Update UI based on access
      setState(() {
        _hasOvertimeAccess = hasAccess;

        // Dispose old controller and create new one with correct tab count
        _tabController.dispose();
        _tabController = TabController(length: _hasOvertimeAccess ? 2 : 1, vsync: this);
      });

      debugPrint("✅ Updated UI: ${_hasOvertimeAccess ? '2 tabs (Attendance + Overtime)' : '1 tab (Attendance only)'}");

    } catch (e) {
      debugPrint("❌ Error checking overtime access: $e");
      _setupAttendanceOnlyView();
    }
  }

  Future<void> _fetchInitialData() async {
    // Always fetch attendance data
    _fetchAttendanceRecords();

    // Fetch overtime data if user has access
    if (_hasOvertimeAccess) {
      debugPrint("📊 Fetching overtime data...");
      _fetchOvertimeData();
    } else {
      debugPrint("⏭️ Skipping overtime data (no access)");
    }
  }

  void _setupAttendanceOnlyView() {
    setState(() {
      _hasOvertimeAccess = false;
      _tabController.dispose();
      _tabController = TabController(length: 1, vsync: this);
    });
    _fetchAttendanceRecords();
  }

  // ===== ATTENDANCE METHODS =====
  Future<void> _fetchAttendanceRecords() async {
    setState(() => _isLoadingAttendance = true);

    try {
      debugPrint("📅 Fetching attendance records for ${widget.employeeId} in month $_selectedMonth");

      // Parse the selected month to get start and end dates
      DateTime selectedDate = DateFormat('yyyy-MM').parse(_selectedMonth);
      DateTime startOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
      DateTime endOfMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0);

      String startDateStr = DateFormat('yyyy-MM-dd').format(startOfMonth);
      String endDateStr = DateFormat('yyyy-MM-dd').format(endOfMonth);

      debugPrint("📅 Date range: $startDateStr to $endDateStr");

      // Query attendance records for the selected month
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThanOrEqualTo: endDateStr)
          .orderBy('date', descending: true)
          .get();

      debugPrint("📅 Found ${snapshot.docs.length} attendance records");

      // Create a map of existing records by date
      Map<String, Map<String, dynamic>> existingRecords = {};

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String date = data['date'] ?? '';

        if (date.isNotEmpty) {
          // Calculate total hours and overtime hours
          DateTime? checkIn;
          DateTime? checkOut;

          if (data['checkIn'] != null) {
            checkIn = (data['checkIn'] as Timestamp).toDate();
          }

          if (data['checkOut'] != null) {
            checkOut = (data['checkOut'] as Timestamp).toDate();
          }

          // Calculate hours
          double totalHours = 0.0;
          double overtimeHours = 0.0;

          if (checkIn != null && checkOut != null) {
            Duration workDuration = checkOut.difference(checkIn);
            totalHours = workDuration.inMinutes / 60.0;

            // Standard work day is 8 hours
            const double standardWorkHours = 8.0;

            if (totalHours > standardWorkHours) {
              overtimeHours = totalHours - standardWorkHours;
            }
          }

          // Add overtime data from Firebase if available
          if (data.containsKey('overtimeHours')) {
            overtimeHours = (data['overtimeHours'] ?? 0.0).toDouble();
          }

          existingRecords[date] = {
            'date': date,
            'checkIn': checkIn,
            'checkOut': checkOut,
            'location': data['location'] ?? 'Unknown',
            'workStatus': data['workStatus'] ?? 'Unknown',
            'totalHours': totalHours,
            'overtimeHours': overtimeHours,
            'isWithinGeofence': data['isWithinGeofence'] ?? false,
            'rawData': data,
            'hasRecord': true,
          };
        }
      }

      // Generate ALL days of the month
      List<Map<String, dynamic>> completeRecords = [];
      DateTime currentDay = startOfMonth;

      while (currentDay.isBefore(endOfMonth) || currentDay.isAtSameMomentAs(endOfMonth)) {
        String currentDateStr = DateFormat('yyyy-MM-dd').format(currentDay);

        if (existingRecords.containsKey(currentDateStr)) {
          // Day has attendance record
          completeRecords.add(existingRecords[currentDateStr]!);
        } else {
          // Day is absent - no attendance record
          completeRecords.add({
            'date': currentDateStr,
            'checkIn': null,
            'checkOut': null,
            'location': 'No Location',
            'workStatus': 'Absent',
            'totalHours': 0.0,
            'overtimeHours': 0.0,
            'isWithinGeofence': false,
            'rawData': {},
            'hasRecord': false,
          });
        }

        currentDay = currentDay.add(const Duration(days: 1));
      }

      // Sort by date (newest first)
      completeRecords.sort((a, b) => b['date'].compareTo(a['date']));

      setState(() {
        _attendanceRecords = completeRecords;
        _isLoadingAttendance = false;
      });

      debugPrint("✅ Generated complete month view: ${completeRecords.length} days total");
      debugPrint("📊 Days with records: ${existingRecords.length}");
      debugPrint("📊 Absent days: ${completeRecords.length - existingRecords.length}");

    } catch (e) {
      debugPrint("❌ Error fetching attendance records: $e");
      setState(() => _isLoadingAttendance = false);

      if (mounted) {
        CustomSnackBar.errorSnackBar("Error loading attendance records: $e");
      }
    }
  }

  // ===== OVERTIME METHODS =====
  Future<void> _fetchOvertimeData() async {
    if (!_hasOvertimeAccess) return;

    setState(() => _isLoadingOvertime = true);

    try {
      debugPrint("📊 === FETCHING ALL OVERTIME DATA ===");

      // Fetch all overtime data concurrently
      final futures = await Future.wait([
        _overtimeService.getOvertimeHistoryForEmployee(widget.employeeId),
        _overtimeService.getTodayOvertimeForEmployee(widget.employeeId),
        _overtimeService.getOvertimeStatistics(widget.employeeId),
      ]);

      final List<OvertimeRequest> history = futures[0] as List<OvertimeRequest>;
      final List<OvertimeRequest> todayRequests = futures[1] as List<OvertimeRequest>;
      final Map<String, dynamic> statistics = futures[2] as Map<String, dynamic>;

      setState(() {
        _overtimeHistory = history;
        _filteredOvertimeHistory = history;
        _todayOvertimeRequests = todayRequests;
        _overtimeStatistics = statistics;
        _isLoadingOvertime = false;
      });

      debugPrint("✅ Successfully loaded overtime data:");
      debugPrint("  - History: ${history.length} requests");
      debugPrint("  - Today: ${todayRequests.length} requests");
      debugPrint("  - Statistics: $statistics");

    } catch (e) {
      debugPrint("❌ Error fetching overtime data: $e");
      setState(() => _isLoadingOvertime = false);

      if (mounted) {
        CustomSnackBar.errorSnackBar("Error loading overtime data: $e");
      }
    }
  }

  // ===== OVERTIME FILTER METHODS =====
  void _filterOvertimeHistory() {
    List<OvertimeRequest> filtered = _overtimeHistory;

    // Apply status filter
    if (_selectedOvertimeStatus != null) {
      filtered = filtered.where((request) => request.status == _selectedOvertimeStatus).toList();
    }

    // Apply search query
    if (_overtimeSearchQuery.isNotEmpty) {
      String query = _overtimeSearchQuery.toLowerCase();
      filtered = filtered.where((request) {
        return request.projectName.toLowerCase().contains(query) ||
            request.projectCode.toLowerCase().contains(query) ||
            request.requesterName.toLowerCase().contains(query) ||
            request.approverName.toLowerCase().contains(query);
      }).toList();
    }

    setState(() {
      _filteredOvertimeHistory = filtered;
    });
  }

  void _clearOvertimeFilters() {
    setState(() {
      _overtimeSearchQuery = '';
      _selectedOvertimeStatus = null;
      _filteredOvertimeHistory = _overtimeHistory;
    });
  }

  // ===== UI BUILD METHODS =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'My ${_hasOvertimeAccess ? 'Attendance & Overtime' : 'Attendance'}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () {
              _fetchAttendanceRecords();
              if (_hasOvertimeAccess) {
                _fetchOvertimeData();
              }
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: _hasOvertimeAccess
            ? TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Attendance', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Overtime', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        )
            : null,
      ),
      body: _hasOvertimeAccess
          ? TabBarView(
        controller: _tabController,
        children: [
          _buildAttendanceTab(),
          _buildOvertimeTab(),
        ],
      )
          : _buildAttendanceTab(),
    );
  }

  // ===== ATTENDANCE TAB =====
  Widget _buildAttendanceTab() {
    return Column(
      children: [
        // Month selector
        _buildMonthSelector(),

        // Summary cards
        if (!_isLoadingAttendance && _attendanceRecords.isNotEmpty)
          _buildSummaryCards(),

        // Attendance table
        Expanded(
          child: _isLoadingAttendance
              ? const Center(
            child: CircularProgressIndicator(color: accentColor),
          )
              : _attendanceRecords.isEmpty
              ? _buildEmptyState()
              : _buildAttendanceTable(),
        ),
      ],
    );
  }

  // ===== OVERTIME TAB =====
  Widget _buildOvertimeTab() {
    return Column(
      children: [
        // Today's overtime (compact design)
        if (_todayOvertimeRequests.isNotEmpty) _buildTodayOvertimeCompact(),

        // Overtime summary
        if (!_isLoadingOvertime && _overtimeHistory.isNotEmpty)
          _buildOvertimeSummary(),

        // Overtime history
        Expanded(
          child: _isLoadingOvertime
              ? const Center(
            child: CircularProgressIndicator(color: accentColor),
          )
              : _overtimeHistory.isEmpty
              ? _buildEmptyOvertimeState()
              : _buildOvertimeHistoryList(),
        ),
      ],
    );
  }

  // ===== IMPROVED TODAY'S OVERTIME (COMPACT & PROFESSIONAL) =====
  Widget _buildTodayOvertimeCompact() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.today_rounded, color: Colors.blue.shade600, size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Today's Overtime",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_todayOvertimeRequests.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Overtime requests list (compact)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: _todayOvertimeRequests.map((request) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    // Project info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.projectName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Code: ${request.projectCode}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Time info
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${DateFormat('h:mm a').format(request.startTime)} - ${DateFormat('h:mm a').format(request.endTime)}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${request.totalDurationHours.toStringAsFixed(1)}h",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ===== IMPROVED OVERTIME SUMMARY =====
  Widget _buildOvertimeSummary() {
    int totalRequests = _overtimeStatistics['totalRequests'] ?? 0;
    int approvedRequests = _overtimeStatistics['approvedRequests'] ?? 0;
    int pendingRequests = _overtimeStatistics['pendingRequests'] ?? 0;
    double totalOvertimeHours = _overtimeStatistics['totalApprovedHours'] ?? 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overtime Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactSummaryCard(
                  'Total',
                  totalRequests.toString(),
                  Icons.assignment_rounded,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactSummaryCard(
                  'Approved',
                  approvedRequests.toString(),
                  Icons.check_circle_rounded,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactSummaryCard(
                  'Pending',
                  pendingRequests.toString(),
                  Icons.pending_rounded,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactSummaryCard(
                  'Hours',
                  '${totalOvertimeHours.toStringAsFixed(1)}h',
                  Icons.timer_rounded,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== COMPACT SUMMARY CARD =====
  Widget _buildCompactSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOvertimeHistoryList() {
    return Column(
      children: [
        // Search and filter section
        _buildOvertimeSearchAndFilter(),

        // History list
        Expanded(
          child: _filteredOvertimeHistory.isEmpty
              ? _buildNoResultsState()
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _filteredOvertimeHistory.length,
            itemBuilder: (context, index) {
              final request = _filteredOvertimeHistory[index];
              return _buildCompactOvertimeCard(request);
            },
          ),
        ),
      ],
    );
  }

  // ===== IMPROVED OVERTIME CARD (COMPACT & PROFESSIONAL) =====
  Widget _buildCompactOvertimeCard(OvertimeRequest request) {
    Color statusColor = _getOvertimeStatusColor(request.status);
    IconData statusIcon = _getOvertimeStatusIcon(request.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with project and status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.projectName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        request.projectCode,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.status.displayName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Time and duration row
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "${DateFormat('MMM dd').format(request.startTime)} • ${DateFormat('h:mm a').format(request.startTime)} - ${DateFormat('h:mm a').format(request.endTime)}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "${request.totalDurationHours.toStringAsFixed(1)}h",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Requester and team info
                Row(
                  children: [
                    Icon(Icons.person_rounded, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "By: ${request.requesterName}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Text(
                      "${request.totalEmployeeCount} ${request.totalEmployeeCount == 1 ? 'person' : 'people'}",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),

                // Response message (if any)
                if (request.responseMessage != null && request.responseMessage!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.message_rounded, size: 12, color: statusColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            request.responseMessage!,
                            style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildOvertimeSearchAndFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: accentColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Overtime History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (_overtimeSearchQuery.isNotEmpty || _selectedOvertimeStatus != null)
                TextButton.icon(
                  onPressed: _clearOvertimeFilters,
                  icon: const Icon(Icons.clear_rounded, size: 14),
                  label: const Text('Clear', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Search bar (compact)
          SizedBox(
            height: 36,
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _overtimeSearchQuery = value;
                });
                _filterOvertimeHistory();
              },
              decoration: InputDecoration(
                hintText: 'Search projects, codes...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _overtimeSearchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () {
                    setState(() {
                      _overtimeSearchQuery = '';
                    });
                    _filterOvertimeHistory();
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: accentColor),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Status filter chips (compact)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCompactFilterChip(
                  label: 'All',
                  isSelected: _selectedOvertimeStatus == null,
                  onTap: () {
                    setState(() {
                      _selectedOvertimeStatus = null;
                    });
                    _filterOvertimeHistory();
                  },
                ),
                const SizedBox(width: 6),
                _buildCompactFilterChip(
                  label: 'Pending',
                  isSelected: _selectedOvertimeStatus == OvertimeRequestStatus.pending,
                  color: Colors.orange,
                  onTap: () {
                    setState(() {
                      _selectedOvertimeStatus = OvertimeRequestStatus.pending;
                    });
                    _filterOvertimeHistory();
                  },
                ),
                const SizedBox(width: 6),
                _buildCompactFilterChip(
                  label: 'Approved',
                  isSelected: _selectedOvertimeStatus == OvertimeRequestStatus.approved,
                  color: Colors.green,
                  onTap: () {
                    setState(() {
                      _selectedOvertimeStatus = OvertimeRequestStatus.approved;
                    });
                    _filterOvertimeHistory();
                  },
                ),
                const SizedBox(width: 6),
                _buildCompactFilterChip(
                  label: 'Rejected',
                  isSelected: _selectedOvertimeStatus == OvertimeRequestStatus.rejected,
                  color: Colors.red,
                  onTap: () {
                    setState(() {
                      _selectedOvertimeStatus = OvertimeRequestStatus.rejected;
                    });
                    _filterOvertimeHistory();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? (color ?? accentColor) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? (color ?? accentColor) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : (color ?? Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'No overtime requests found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _overtimeSearchQuery.isNotEmpty || _selectedOvertimeStatus != null
                ? 'Try adjusting your filters'
                : 'Your overtime requests will appear here',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              if (_overtimeSearchQuery.isNotEmpty || _selectedOvertimeStatus != null) {
                _clearOvertimeFilters();
              } else {
                _fetchOvertimeData();
              }
            },
            icon: Icon(_overtimeSearchQuery.isNotEmpty || _selectedOvertimeStatus != null
                ? Icons.clear_rounded
                : Icons.refresh_rounded, size: 16),
            label: Text(_overtimeSearchQuery.isNotEmpty || _selectedOvertimeStatus != null
                ? 'Clear Filters'
                : 'Refresh', style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOvertimeState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No overtime history',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your overtime requests will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchOvertimeData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ===== HELPER METHODS =====
  Color _getOvertimeStatusColor(OvertimeRequestStatus status) {
    switch (status) {
      case OvertimeRequestStatus.pending:
        return Colors.orange;
      case OvertimeRequestStatus.approved:
        return Colors.green;
      case OvertimeRequestStatus.rejected:
        return Colors.red;
      case OvertimeRequestStatus.cancelled:
        return Colors.grey;
    }
  }

  IconData _getOvertimeStatusIcon(OvertimeRequestStatus status) {
    switch (status) {
      case OvertimeRequestStatus.pending:
        return Icons.pending_rounded;
      case OvertimeRequestStatus.approved:
        return Icons.check_circle_rounded;
      case OvertimeRequestStatus.rejected:
        return Icons.cancel_rounded;
      case OvertimeRequestStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  // ===== ATTENDANCE UI METHODS (Keeping existing ones) =====
  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: accentColor),
          const SizedBox(width: 12),
          const Text(
            'Select Month:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMonth,
                  isExpanded: true,
                  items: _generateMonthOptions(),
                  onChanged: (String? newValue) {
                    if (newValue != null && newValue != _selectedMonth) {
                      setState(() {
                        _selectedMonth = newValue;
                      });
                      _fetchAttendanceRecords();
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _generateMonthOptions() {
    List<DropdownMenuItem<String>> items = [];
    DateTime now = DateTime.now();

    // Generate last 12 months
    for (int i = 0; i < 12; i++) {
      DateTime month = DateTime(now.year, now.month - i, 1);
      String monthKey = DateFormat('yyyy-MM').format(month);
      String monthDisplay = DateFormat('MMMM yyyy').format(month);

      items.add(
        DropdownMenuItem<String>(
          value: monthKey,
          child: Text(monthDisplay),
        ),
      );
    }

    return items;
  }

  Widget _buildSummaryCards() {
    int totalDaysInMonth = _attendanceRecords.length;
    double totalWorkHours = 0;
    double totalOvertimeHours = 0;
    int absentDays = 0;
    int presentDays = 0;

    for (var record in _attendanceRecords) {
      DateTime? checkIn = record['checkIn'];
      DateTime? checkOut = record['checkOut'];
      bool hasRecord = record['hasRecord'] ?? true;

      if (!hasRecord || (checkIn == null && checkOut == null)) {
        absentDays++;
      } else {
        presentDays++;
      }

      totalWorkHours += record['totalHours'] ?? 0.0;
      double overtimeHours = record['overtimeHours'] ?? 0.0;
      totalOvertimeHours += overtimeHours;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary for ${DateFormat('MMMM yyyy').format(DateFormat('yyyy-MM').parse(_selectedMonth))}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Days',
                  totalDaysInMonth.toString(),
                  Icons.calendar_today,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Present Days',
                  presentDays.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Absent Days',
                  absentDays.toString(),
                  Icons.cancel,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Total Hours',
                  '${totalWorkHours.toStringAsFixed(1)}h',
                  Icons.access_time,
                  Colors.indigo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_view_month,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No attendance records found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'for ${DateFormat('MMMM yyyy').format(DateFormat('yyyy-MM').parse(_selectedMonth))}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchAttendanceRecords,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTable() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text(
              'Attendance Records',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 16,
                  headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                  columns: [
                    const DataColumn(
                      label: Text(
                        'Date',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Check In',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Check Out',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Total Hours',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (_hasOvertimeAccess)
                      const DataColumn(
                        label: Text(
                          'Overtime',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    const DataColumn(
                      label: Text(
                        'Location',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Attendance',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: _attendanceRecords.map((record) => _buildDataRow(record)).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(Map<String, dynamic> record) {
    String date = record['date'] ?? '';
    DateTime? checkIn = record['checkIn'];
    DateTime? checkOut = record['checkOut'];
    double totalHours = record['totalHours'] ?? 0.0;
    double overtimeHours = record['overtimeHours'] ?? 0.0;
    String location = record['location'] ?? 'Unknown';
    String status = record['workStatus'] ?? 'Unknown';
    bool isWithinGeofence = record['isWithinGeofence'] ?? false;
    bool hasRecord = record['hasRecord'] ?? true;

    // Determine attendance status
    String attendanceStatus = 'Present';
    Color attendanceColor = Colors.green;
    IconData attendanceIcon = Icons.check_circle;

    if (!hasRecord || (checkIn == null && checkOut == null)) {
      attendanceStatus = 'Absent';
      attendanceColor = Colors.red;
      attendanceIcon = Icons.cancel;
      location = 'No Location';
      status = 'Absent';
    } else if (checkIn == null || checkOut == null) {
      attendanceStatus = 'Incomplete';
      attendanceColor = Colors.orange;
      attendanceIcon = Icons.warning;
    }

    // Format date
    String formattedDate = '';
    String dayOfWeek = '';
    try {
      DateTime dateTime = DateFormat('yyyy-MM-dd').parse(date);
      formattedDate = DateFormat('MMM dd').format(dateTime);
      dayOfWeek = DateFormat('EEE').format(dateTime);
    } catch (e) {
      formattedDate = date;
    }

    return DataRow(
      color: attendanceStatus == 'Absent'
          ? MaterialStateProperty.all(Colors.red.withOpacity(0.05))
          : attendanceStatus == 'Incomplete'
          ? MaterialStateProperty.all(Colors.orange.withOpacity(0.05))
          : null,
      cells: [
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                formattedDate,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: attendanceStatus == 'Absent' ? Colors.red.shade700 : Colors.black,
                ),
              ),
              if (dayOfWeek.isNotEmpty)
                Text(
                  dayOfWeek,
                  style: TextStyle(
                    fontSize: 12,
                    color: attendanceStatus == 'Absent'
                        ? Colors.red.shade500
                        : Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
        DataCell(
          Text(
            checkIn != null ? DateFormat('HH:mm').format(checkIn) : '-',
            style: TextStyle(
              color: checkIn != null ? Colors.green.shade700 : Colors.grey,
              fontWeight: checkIn != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        DataCell(
          Text(
            checkOut != null ? DateFormat('HH:mm').format(checkOut) : '-',
            style: TextStyle(
              color: checkOut != null ? Colors.red.shade700 : Colors.grey,
              fontWeight: checkOut != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        DataCell(
          Text(
            totalHours > 0 ? '${totalHours.toStringAsFixed(1)}h' : '-',
            style: TextStyle(
              color: totalHours > 0 ? Colors.blue.shade700 : Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (_hasOvertimeAccess)
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: overtimeHours > 0 ? Colors.orange.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                overtimeHours > 0 ? '${overtimeHours.toStringAsFixed(1)}h' : '-',
                style: TextStyle(
                  color: overtimeHours > 0 ? Colors.orange.shade800 : Colors.grey,
                  fontWeight: overtimeHours > 0 ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                location,
                style: TextStyle(
                  fontSize: 12,
                  color: attendanceStatus == 'Absent' ? Colors.grey : Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (attendanceStatus != 'Absent' && hasRecord)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isWithinGeofence ? Icons.location_on : Icons.location_off,
                      size: 12,
                      color: isWithinGeofence ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isWithinGeofence ? 'Inside' : 'Outside',
                      style: TextStyle(
                        fontSize: 10,
                        color: isWithinGeofence ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: _getStatusColor(status),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: attendanceColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  attendanceIcon,
                  size: 14,
                  color: attendanceColor,
                ),
                const SizedBox(width: 4),
                Text(
                  attendanceStatus,
                  style: TextStyle(
                    color: attendanceColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}