// lib/overtime/create_overtime_view.dart - COMPLETE MULTI-STEP WORKFLOW

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:phoenician_face_auth/constants/theme.dart';
import 'package:phoenician_face_auth/model/overtime_request_model.dart';
import 'package:phoenician_face_auth/common/utils/custom_snackbar.dart';
import 'package:phoenician_face_auth/services/notification_service.dart';
import 'package:phoenician_face_auth/repositories/overtime_repository.dart';
import 'package:phoenician_face_auth/services/service_locator.dart';
import 'package:phoenician_face_auth/overtime/employee_list_management_view.dart';
import 'package:flutter/foundation.dart';

class CreateOvertimeView extends StatefulWidget {
  final String requesterId;

  const CreateOvertimeView({
    Key? key,
    required this.requesterId,
  }) : super(key: key);

  @override
  State<CreateOvertimeView> createState() => _CreateOvertimeViewState();
}

class _CreateOvertimeViewState extends State<CreateOvertimeView> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final _searchController = TextEditingController();

  // Current step tracking
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Multi-project support
  List<OvertimeProjectEntry> _projects = [];
  int _currentProjectIndex = 0;

  // Employee data
  List<Map<String, dynamic>> _allEmployees = [];
  List<Map<String, dynamic>> _filteredEmployees = [];
  List<String> _selectedEmployeeIds = [];
  List<Map<String, dynamic>> _myEmployeeList = [];
  List<OvertimeRequest> _requestHistory = [];

  // UI states
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasCustomList = false;
  bool _showMainList = false;

  // Dynamic approver info
  Map<String, dynamic>? _currentApprover;
  bool _loadingApprover = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentApprover();
    _loadEligibleEmployees();
    _loadMyEmployeeList();
    _loadRequestHistory();
    _addNewProject(); // Initialize with one project
    _searchController.addListener(_filterEmployees);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ===== DATA LOADING METHODS =====

  Future<void> _loadCurrentApprover() async {
    setState(() => _loadingApprover = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('getCurrentOvertimeApprover');
      final result = await callable.call();
      if (result.data['success'] == true) {
        setState(() {
          _currentApprover = Map<String, dynamic>.from(result.data['approver']);
          _loadingApprover = false;
        });
      } else {
        throw Exception("Failed to get current approver");
      }
    } catch (e) {
      setState(() {
        _loadingApprover = false;
        _currentApprover = {
          'approverId': 'EMP1289',
          'approverName': 'Default Approver',
          'source': 'fallback'
        };
      });
    }
  }

  Future<void> _loadEligibleEmployees() async {
    setState(() => _isLoading = true);
    try {
      QuerySnapshot masterSheetSnapshot = await FirebaseFirestore.instance
          .collection('MasterSheet')
          .doc('Employee-Data')
          .collection('employees')
          .where('hasOvertime', isEqualTo: true)
          .get();

      QuerySnapshot employeesSnapshot = await FirebaseFirestore.instance
          .collection('employees')
          .where('hasOvertime', isEqualTo: true)
          .get();

      Set<Map<String, dynamic>> uniqueEmployees = {};

      for (var doc in masterSheetSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        uniqueEmployees.add({
          'id': doc.id,
          'name': data['employeeName'] ?? 'Unknown',
          'designation': data['designation'] ?? 'No designation',
          'department': data['department'] ?? 'No department',
          'employeeNumber': data['employeeNumber'] ?? '',
          'source': 'MasterSheet'
        });
      }

      for (var doc in employeesSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        uniqueEmployees.add({
          'id': doc.id,
          'name': data['name'] ?? data['employeeName'] ?? 'Unknown',
          'designation': data['designation'] ?? 'No designation',
          'department': data['department'] ?? 'No department',
          'employeeNumber': data['employeeNumber'] ?? '',
          'source': 'Employees'
        });
      }

      setState(() {
        _allEmployees = uniqueEmployees.toList();
        _allEmployees.sort((a, b) => a['name'].compareTo(b['name']));
        _filteredEmployees = List.from(_allEmployees);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      CustomSnackBar.errorSnackBar("Error loading employees: $e");
    }
  }

  Future<void> _loadMyEmployeeList() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('employee_lists')
          .doc(widget.requesterId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List<String> employeeIds = List<String>.from(data['employeeIds'] ?? []);

        List<Map<String, dynamic>> customList = [];
        for (String empId in employeeIds) {
          var employee = _allEmployees.firstWhere(
                (emp) => emp['id'] == empId,
            orElse: () => {},
          );
          if (employee.isNotEmpty) {
            customList.add(employee);
          }
        }

        setState(() {
          _myEmployeeList = customList;
          _hasCustomList = customList.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint("Error loading custom employee list: $e");
    }
  }

  Future<void> _loadRequestHistory() async {
    try {
      FirebaseFirestore.instance
          .collection('overtime_requests')
          .where('requesterId', isEqualTo: widget.requesterId)
          .orderBy('requestTime', descending: true)
          .snapshots()
          .listen((snapshot) {
        List<OvertimeRequest> requests = [];
        for (var doc in snapshot.docs) {
          try {
            Map<String, dynamic> data = doc.data();
            List<OvertimeProjectEntry> projects = [];
            if (data['projects'] != null && data['projects'] is List) {
              for (var projectData in data['projects']) {
                projects.add(OvertimeProjectEntry.fromMap(projectData));
              }
            } else {
              projects.add(OvertimeProjectEntry(
                projectName: data['projectName'] ?? '',
                projectCode: data['projectCode'] ?? '',
                startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
                endTime: (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
                employeeIds: List<String>.from(data['employeeIds'] ?? []),
              ));
            }

            OvertimeRequest request = OvertimeRequest(
              id: doc.id,
              requesterId: data['requesterId'] ?? '',
              requesterName: data['requesterName'] ?? '',
              approverEmpId: data['approverEmpId'] ?? '',
              approverName: data['approverName'] ?? '',
              projectName: data['projectName'] ?? '',
              projectCode: data['projectCode'] ?? '',
              startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
              endTime: (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
              employeeIds: List<String>.from(data['employeeIds'] ?? []),
              requestTime: (data['requestTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
              status: _parseStatus(data['status']),
              responseMessage: data['responseMessage'],
              responseTime: (data['responseTime'] as Timestamp?)?.toDate(),
              totalProjects: data['totalProjects'] ?? 1,
              totalEmployeeCount: data['totalEmployees'] ?? (data['employeeIds'] as List?)?.length ?? 0,
              totalDurationHours: data['totalHours']?.toDouble() ?? 0.0,
              projects: projects,
            );
            requests.add(request);
          } catch (e) {
            debugPrint("Error parsing request ${doc.id}: $e");
          }
        }

        if (mounted) {
          setState(() {
            _requestHistory = requests;
          });
        }
      });
    } catch (e) {
      debugPrint("Error loading request history: $e");
    }
  }

  OvertimeRequestStatus _parseStatus(dynamic status) {
    if (status == null) return OvertimeRequestStatus.pending;
    switch (status.toString().toLowerCase()) {
      case 'approved':
        return OvertimeRequestStatus.approved;
      case 'rejected':
        return OvertimeRequestStatus.rejected;
      case 'cancelled':
        return OvertimeRequestStatus.cancelled;
      case 'pending':
      default:
        return OvertimeRequestStatus.pending;
    }
  }

  // ===== PROJECT MANAGEMENT =====

  void _addNewProject() {
    setState(() {
      _projects.add(OvertimeProjectEntry(
        projectName: '',
        projectCode: '',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 2)),
        employeeIds: [],
      ));
      _currentProjectIndex = _projects.length - 1;
    });
  }

  void _removeProject(int index) {
    if (_projects.length > 1) {
      setState(() {
        _projects.removeAt(index);
        if (_currentProjectIndex >= _projects.length) {
          _currentProjectIndex = _projects.length - 1;
        }
      });
    }
  }

  void _updateCurrentProject({
    String? projectName,
    String? projectCode,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    if (_currentProjectIndex < _projects.length) {
      setState(() {
        _projects[_currentProjectIndex] = OvertimeProjectEntry(
          projectName: projectName ?? _projects[_currentProjectIndex].projectName,
          projectCode: projectCode ?? _projects[_currentProjectIndex].projectCode,
          startTime: startTime ?? _projects[_currentProjectIndex].startTime,
          endTime: endTime ?? _projects[_currentProjectIndex].endTime,
          employeeIds: _projects[_currentProjectIndex].employeeIds,
        );
      });
    }
  }

  Future<void> _selectTime(bool isStartTime, int projectIndex) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          isStartTime
              ? _projects[projectIndex].startTime
              : _projects[projectIndex].endTime
      ),
    );

    if (picked != null) {
      setState(() {
        final now = DateTime.now();
        if (isStartTime) {
          DateTime newStartTime = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
          _projects[projectIndex] = OvertimeProjectEntry(
            projectName: _projects[projectIndex].projectName,
            projectCode: _projects[projectIndex].projectCode,
            startTime: newStartTime,
            endTime: _projects[projectIndex].endTime,
            employeeIds: _projects[projectIndex].employeeIds,
          );
          if (_projects[projectIndex].endTime.isBefore(newStartTime)) {
            _projects[projectIndex] = OvertimeProjectEntry(
              projectName: _projects[projectIndex].projectName,
              projectCode: _projects[projectIndex].projectCode,
              startTime: newStartTime,
              endTime: newStartTime.add(const Duration(hours: 1)),
              employeeIds: _projects[projectIndex].employeeIds,
            );
          }
        } else {
          DateTime newEndTime = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
          if (newEndTime.isAfter(_projects[projectIndex].startTime)) {
            _projects[projectIndex] = OvertimeProjectEntry(
              projectName: _projects[projectIndex].projectName,
              projectCode: _projects[projectIndex].projectCode,
              startTime: _projects[projectIndex].startTime,
              endTime: newEndTime,
              employeeIds: _projects[projectIndex].employeeIds,
            );
          } else {
            CustomSnackBar.errorSnackBar("End time must be after start time");
          }
        }
      });
    }
  }

  // ===== EMPLOYEE MANAGEMENT =====

  void _filterEmployees() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredEmployees = List.from(_allEmployees);
      } else {
        _filteredEmployees = _allEmployees.where((employee) {
          String name = employee['name'].toString().toLowerCase();
          String designation = employee['designation'].toString().toLowerCase();
          String department = employee['department'].toString().toLowerCase();
          String empId = employee['id'].toString().toLowerCase();
          return name.contains(query) ||
              designation.contains(query) ||
              department.contains(query) ||
              empId.contains(query);
        }).toList();
      }
    });
  }

  // ===== NAVIGATION =====

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _canProceedFromStep(int step) {
    switch (step) {
      case 0: // Project details
        return _projects.any((p) => p.projectName.trim().isNotEmpty && p.projectCode.trim().isNotEmpty);
      case 1: // Employee selection
        return _selectedEmployeeIds.isNotEmpty;
      case 2: // Preview
        return true;
      default:
        return false;
    }
  }

  // ===== SUBMISSION =====

  Future<void> _submitRequest() async {
    if (!_canProceedFromStep(1) || _currentApprover == null) return;

    setState(() => _isSubmitting = true);

    try {
      DocumentSnapshot requesterDoc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.requesterId)
          .get();

      String requesterName = '';
      if (requesterDoc.exists) {
        Map<String, dynamic> data = requesterDoc.data() as Map<String, dynamic>;
        requesterName = data['employeeName'] ?? data['name'] ?? 'Unknown Requester';
      }

      List<OvertimeProjectEntry> validProjects = _projects
          .where((project) =>
      project.projectName.trim().isNotEmpty &&
          project.projectCode.trim().isNotEmpty)
          .map((project) => OvertimeProjectEntry(
        projectName: project.projectName.trim(),
        projectCode: project.projectCode.trim(),
        startTime: project.startTime,
        endTime: project.endTime,
        employeeIds: _selectedEmployeeIds,
      ))
          .toList();

      DocumentReference requestRef = await FirebaseFirestore.instance
          .collection('overtime_requests')
          .add({
        'projects': validProjects.map((project) => project.toMap()).toList(),
        'requesterId': widget.requesterId,
        'requesterName': requesterName,
        'approverEmpId': _currentApprover!['approverId'],
        'approverName': _currentApprover!['approverName'],
        'requestTime': FieldValue.serverTimestamp(),
        'status': 'pending',
        'createdBy': widget.requesterId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'version': 1,
        'projectName': validProjects.length == 1
            ? validProjects.first.projectName
            : "${validProjects.length} Projects",
        'projectCode': validProjects.length == 1
            ? validProjects.first.projectCode
            : 'MULTI',
        'startTime': validProjects.isNotEmpty
            ? Timestamp.fromDate(validProjects.first.startTime)
            : null,
        'endTime': validProjects.isNotEmpty
            ? Timestamp.fromDate(validProjects.first.endTime)
            : null,
        'employeeIds': _selectedEmployeeIds,
        'totalProjects': validProjects.length,
        'totalEmployees': _selectedEmployeeIds.length,
        'totalHours': validProjects.fold(0.0, (sum, project) => sum + project.durationInHours),
        'employeeDetails': await _getEmployeeDetails(_selectedEmployeeIds),
        'projectDetails': validProjects.map((p) => {
          'name': p.projectName,
          'code': p.projectCode,
          'startTime': Timestamp.fromDate(p.startTime),
          'endTime': Timestamp.fromDate(p.endTime),
          'duration': p.durationInHours,
        }).toList(),
      });

      String requestId = requestRef.id;

      // Send notifications
      try {
        int totalHours = validProjects.fold(0, (sum, project) =>
        sum + project.endTime.difference(project.startTime).inHours);

        String projectSummary = validProjects.length == 1
            ? validProjects.first.projectName
            : "${validProjects.length} projects (${totalHours}h total)";

        final requesterCallable = FirebaseFunctions.instance.httpsCallable('sendNotificationToUser');
        await requesterCallable.call({
          'userId': widget.requesterId,
          'title': '✅ Multi-Project Overtime Request Submitted!',
          'body': 'Your overtime request for $projectSummary with ${_selectedEmployeeIds.length} employees has been sent to ${_currentApprover!['approverName']} for approval.',
          'data': {
            'type': 'overtime_request_submitted',
            'requestId': requestId,
            'projectSummary': projectSummary,
            'totalProjects': validProjects.length.toString(),
            'employeeCount': _selectedEmployeeIds.length.toString(),
            'approverName': _currentApprover!['approverName'],
          }
        });

        final approverCallable = FirebaseFunctions.instance.httpsCallable('sendOvertimeRequestNotification');
        await approverCallable.call({
          'requestId': requestId,
          'projectName': projectSummary,
          'requesterName': requesterName,
          'requesterId': widget.requesterId,
          'employeeCount': _selectedEmployeeIds.length,
          'totalProjects': validProjects.length,
          'totalHours': totalHours,
          'approverId': _currentApprover!['approverId'],
          'approverName': _currentApprover!['approverName'],
        });
      } catch (notificationError) {
        debugPrint("⚠️ Notification error: $notificationError");
      }

      setState(() => _isSubmitting = false);

      if (mounted) {
        _showSuccessDialog(validProjects);
      }

    } catch (e) {
      setState(() => _isSubmitting = false);
      CustomSnackBar.errorSnackBar("Error: $e");
      debugPrint("Error submitting overtime request: $e");
    }
  }

  Future<List<Map<String, dynamic>>> _getEmployeeDetails(List<String> employeeIds) async {
    List<Map<String, dynamic>> details = [];
    for (String empId in employeeIds) {
      var employee = _allEmployees.firstWhere(
            (emp) => emp['id'] == empId,
        orElse: () => {},
      );
      if (employee.isNotEmpty) {
        details.add({
          'id': empId,
          'name': employee['name'],
          'designation': employee['designation'],
          'department': employee['department'],
          'employeeNumber': employee['employeeNumber'],
        });
      }
    }
    return details;
  }

  void _showSuccessDialog(List<OvertimeProjectEntry> submittedProjects) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text("Request Submitted!", style: TextStyle(color: Colors.green)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Your overtime request has been successfully submitted."),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Sent to: ${_currentApprover!['approverName']}"),
                    Text("Projects: ${submittedProjects.length}"),
                    Text("Employees: ${_selectedEmployeeIds.length}"),
                    Text("Total Duration: ${submittedProjects.fold(0.0, (sum, p) => sum + p.durationInHours).toStringAsFixed(1)} hours"),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("Create Overtime Request"),
        backgroundColor: isDarkMode ? Colors.grey[900] : scaffoldTopGradientClr,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: List.generate(_totalSteps, (index) {
                bool isActive = index == _currentStep;
                bool isCompleted = index < _currentStep;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
                    child: Column(
                      children: [
                        Container(
                          height: 30,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? Colors.green
                                : isActive
                                ? accentColor
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Center(
                            child: Text(
                              "${index + 1}",
                              style: TextStyle(
                                color: isCompleted || isActive ? Colors.white : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _getStepTitle(index),
                          style: TextStyle(
                            fontSize: 10,
                            color: isActive ? accentColor : Colors.grey[600],
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [Colors.grey[900]!, Colors.grey[800]!]
                : [Colors.white, Colors.grey[50]!],
          ),
        ),
        child: _isLoading || _loadingApprover
            ? Center(child: CircularProgressIndicator(color: accentColor))
            : PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _currentStep = index),
          children: [
            _buildProjectStep(),
            _buildEmployeeStep(),
            _buildPreviewStep(),
            _buildHistoryStep(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  String _getStepTitle(int index) {
    switch (index) {
      case 0:
        return "Projects";
      case 1:
        return "Employees";
      case 2:
        return "Preview";
      case 3:
        return "History";
      default:
        return "";
    }
  }

  // ===== STEP BUILDERS =====

  Widget _buildProjectStep() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Project Details",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Add project information and set overtime hours",
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          SizedBox(height: 24),

          // Project tabs
          if (_projects.length > 1)
            Container(
              height: 50,
              margin: EdgeInsets.only(bottom: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _projects.length,
                itemBuilder: (context, index) {
                  final isActive = index == _currentProjectIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _currentProjectIndex = index),
                    child: Container(
                      margin: EdgeInsets.only(right: 8),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? accentColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isActive ? accentColor : Colors.grey),
                      ),
                      child: Center(
                        child: Text(
                          "Project ${index + 1}",
                          style: TextStyle(
                            color: isActive ? Colors.white : (isDarkMode ? Colors.white : Colors.black87),
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Current project form
          _buildProjectForm(_currentProjectIndex),

          SizedBox(height: 20),

          // Project management buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _addNewProject,
                  icon: Icon(Icons.add),
                  label: Text("Add Project"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              if (_projects.length > 1) ...[
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _removeProject(_currentProjectIndex),
                    icon: Icon(Icons.remove),
                    label: Text("Remove"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeStep() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Select Employees",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "${_selectedEmployeeIds.length} employees selected",
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          SizedBox(height: 24),

          // Show saved list option if available
          if (_hasCustomList) ...[
            _buildSavedEmployeeListCard(),
            SizedBox(height: 16),
            _buildToggleMainListButton(),
            SizedBox(height: 16),
          ],

          // Main employee selection
          if (!_hasCustomList || _showMainList) ...[
            _buildSearchBar(),
            SizedBox(height: 16),
            _buildActionButtons(),
            SizedBox(height: 16),
            _buildEmployeeList(),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewStep() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final validProjects = _projects.where((p) => p.projectName.trim().isNotEmpty && p.projectCode.trim().isNotEmpty).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Request Preview",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Review your overtime request before submission",
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          SizedBox(height: 24),

          // Summary cards
          Row(
            children: [
              Expanded(child: _buildSummaryCard("Projects", "${validProjects.length}", Icons.work, Colors.blue)),
              SizedBox(width: 8),
              Expanded(child: _buildSummaryCard("Employees", "${_selectedEmployeeIds.length}", Icons.people, Colors.green)),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildSummaryCard("Total Hours", "${validProjects.fold(0.0, (sum, p) => sum + p.durationInHours).toStringAsFixed(1)}", Icons.access_time, Colors.orange)),
              SizedBox(width: 8),
              Expanded(child: _buildSummaryCard("Approver", "${_currentApprover?['approverName'] ?? 'Loading...'}", Icons.person, Colors.purple)),
            ],
          ),

          SizedBox(height: 24),

          // Projects table
          _buildProjectsTable(validProjects),

          SizedBox(height: 16),

          // Employees table
          _buildEmployeesTable(),

          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHistoryStep() {
    if (_requestHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text("No request history", style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _requestHistory.length,
      itemBuilder: (context, index) {
        final request = _requestHistory[index];
        return _buildHistoryCard(request);
      },
    );
  }

  // ===== COMPONENT BUILDERS =====

  Widget _buildProjectForm(int projectIndex) {
    final project = _projects[projectIndex];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
      ),
      child: Column(
        children: [
          TextFormField(
            initialValue: project.projectName,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: "Project Name",
              labelStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => _updateCurrentProject(projectName: value),
          ),
          SizedBox(height: 16),
          TextFormField(
            initialValue: project.projectCode,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: "Project Code",
              labelStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => _updateCurrentProject(projectCode: value),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTimeSelector(
                  label: "Start Time",
                  time: project.startTime,
                  onTap: () => _selectTime(true, projectIndex),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildTimeSelector(
                  label: "End Time",
                  time: project.endTime,
                  onTap: () => _selectTime(false, projectIndex),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.timer, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  "Duration: ${project.durationInHours.toStringAsFixed(1)} hours",
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
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

  Widget _buildTimeSelector({required String label, required DateTime time, required VoidCallback onTap}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[700] : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, color: accentColor, size: 20),
                SizedBox(width: 8),
                Text(
                  DateFormat('h:mm a').format(time),
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedEmployeeListCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bookmark, color: Colors.green),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "My Employee List (${_myEmployeeList.length} employees)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedEmployeeIds = _myEmployeeList.map((emp) => emp['id'] as String).toList();
                  });
                },
                icon: Icon(Icons.select_all, size: 16),
                label: Text("Load All"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            height: 120,
            child: ListView.builder(
              itemCount: _myEmployeeList.length,
              itemBuilder: (context, index) {
                final employee = _myEmployeeList[index];
                final empId = employee['id'];
                final isSelected = _selectedEmployeeIds.contains(empId);
                return CheckboxListTile(
                  dense: true,
                  title: Text(employee['name'], style: TextStyle(fontSize: 14)),
                  subtitle: Text("${employee['designation']}", style: TextStyle(fontSize: 12)),
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedEmployeeIds.add(empId);
                      } else {
                        _selectedEmployeeIds.remove(empId);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleMainListButton() {
    return TextButton.icon(
      onPressed: () => setState(() => _showMainList = !_showMainList),
      icon: Icon(_showMainList ? Icons.expand_less : Icons.expand_more),
      label: Text(_showMainList ? "Hide Main List" : "Add from Main List"),
    );
  }

  Widget _buildSearchBar() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: _searchController,
      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: "Search employees...",
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _selectedEmployeeIds = _filteredEmployees.map((emp) => emp['id'] as String).toList();
              });
            },
            icon: Icon(Icons.select_all),
            label: Text("Select All"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _selectedEmployeeIds.clear()),
            icon: Icon(Icons.clear),
            label: Text("Clear"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeList() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        itemCount: _filteredEmployees.length,
        itemBuilder: (context, index) {
          final employee = _filteredEmployees[index];
          final empId = employee['id'];
          final isSelected = _selectedEmployeeIds.contains(empId);
          return CheckboxListTile(
            title: Text(employee['name']),
            subtitle: Text("${employee['designation']} | ${employee['department']}"),
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedEmployeeIds.add(empId);
                } else {
                  _selectedEmployeeIds.remove(empId);
                }
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsTable(List<OvertimeProjectEntry> projects) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            ),
            child: Text(
              "Projects (${projects.length})",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ...projects.map((project) => Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(project.projectName, style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(project.projectCode, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(
                    "${DateFormat('h:mm a').format(project.startTime)} - ${DateFormat('h:mm a').format(project.endTime)}",
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${project.durationInHours.toStringAsFixed(1)}h",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildEmployeesTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            ),
            child: Text(
              "Selected Employees (${_selectedEmployeeIds.length})",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ..._selectedEmployeeIds.take(5).map((empId) {
            final employee = _allEmployees.firstWhere((emp) => emp['id'] == empId, orElse: () => {});
            if (employee.isEmpty) return SizedBox.shrink();
            return Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue,
                    child: Text(employee['name'][0], style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(employee['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text("${employee['designation']} | ${employee['department']}", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Text(empId, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            );
          }).toList(),
          if (_selectedEmployeeIds.length > 5)
            Container(
              padding: EdgeInsets.all(12),
              child: Text(
                "... and ${_selectedEmployeeIds.length - 5} more employees",
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(OvertimeRequest request) {
    Color statusColor = _getStatusColor(request.status);
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(_getStatusIcon(request.status), color: statusColor),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_getStatusText(request.status), style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
                      Text(DateFormat('MMM dd, yyyy • h:mm a').format(request.requestTime), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.projectsSummary, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text("${request.totalEmployeeCount} employees • ${request.totalDurationHours.toStringAsFixed(1)} hours", style: TextStyle(color: Colors.grey[600])),
                if (request.responseMessage != null && request.responseMessage!.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(request.responseMessage!, style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  child: Text("Previous"),
                ),
              ),
            if (_currentStep > 0) SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _currentStep == 2
                    ? (_isSubmitting ? null : _submitRequest)
                    : (_canProceedFromStep(_currentStep) ? _nextStep : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentStep == 2 ? Colors.green : accentColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text("Submitting..."),
                  ],
                )
                    : Text(_currentStep == 2 ? "Send for Approval" : "Next"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Color _getStatusColor(OvertimeRequestStatus status) {
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

  IconData _getStatusIcon(OvertimeRequestStatus status) {
    switch (status) {
      case OvertimeRequestStatus.pending:
        return Icons.pending;
      case OvertimeRequestStatus.approved:
        return Icons.check_circle;
      case OvertimeRequestStatus.rejected:
        return Icons.cancel;
      case OvertimeRequestStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  String _getStatusText(OvertimeRequestStatus status) {
    switch (status) {
      case OvertimeRequestStatus.pending:
        return "Pending Approval";
      case OvertimeRequestStatus.approved:
        return "Approved";
      case OvertimeRequestStatus.rejected:
        return "Rejected";
      case OvertimeRequestStatus.cancelled:
        return "Cancelled";
    }
  }
}