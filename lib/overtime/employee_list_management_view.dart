// lib/overtime/employee_list_management_view.dart - COMPLETE MULTI-STEP WORKFLOW

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phoenician_face_auth/constants/theme.dart';
import 'package:phoenician_face_auth/common/utils/custom_snackbar.dart';

class EmployeeListManagementView extends StatefulWidget {
  final String requesterId;

  const EmployeeListManagementView({
    Key? key,
    required this.requesterId,
  }) : super(key: key);

  @override
  State<EmployeeListManagementView> createState() => _EmployeeListManagementViewState();
}

class _EmployeeListManagementViewState extends State<EmployeeListManagementView> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();

  // Current step tracking
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Employee data
  List<Map<String, dynamic>> _allEmployees = [];
  List<Map<String, dynamic>> _filteredEmployees = [];
  List<String> _selectedEmployeeIds = [];
  List<String> _currentCustomList = [];

  // UI states
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasExistingList = false;
  String? _listName;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadExistingList();
    _searchController.addListener(_filterEmployees);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ===== DATA LOADING METHODS =====

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);

    try {
      // Load all eligible employees
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

      // Process MasterSheet
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

      // Process employees collection
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

  Future<void> _loadExistingList() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('employee_lists')
          .doc(widget.requesterId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List<String> employeeIds = List<String>.from(data['employeeIds'] ?? []);

        setState(() {
          _currentCustomList = employeeIds;
          _selectedEmployeeIds = List.from(employeeIds);
          _hasExistingList = employeeIds.isNotEmpty;
          _listName = data['listName'] ?? 'My Employee List';
        });
      }
    } catch (e) {
      debugPrint("Error loading existing list: $e");
    }
  }

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

  // ===== UTILITY METHODS =====

  Color _getColorShade(Color color, int shade) {
    if (color == Colors.blue) {
      return Colors.blue[shade] ?? color;
    } else if (color == Colors.green) {
      return Colors.green[shade] ?? color;
    } else if (color == Colors.orange) {
      return Colors.orange[shade] ?? color;
    } else if (color == Colors.red) {
      return Colors.red[shade] ?? color;
    } else if (color == Colors.purple) {
      return Colors.purple[shade] ?? color;
    }
    return color;
  }

  Map<String, int> _getDesignationCounts() {
    Map<String, int> counts = {};
    for (String empId in _selectedEmployeeIds) {
      var employee = _allEmployees.firstWhere(
            (emp) => emp['id'] == empId,
        orElse: () => {},
      );
      if (employee.isNotEmpty) {
        String designation = employee['designation'] ?? 'Unknown';
        counts[designation] = (counts[designation] ?? 0) + 1;
      }
    }
    return counts;
  }

  Map<String, int> _getDepartmentCounts() {
    Map<String, int> counts = {};
    for (String empId in _selectedEmployeeIds) {
      var employee = _allEmployees.firstWhere(
            (emp) => emp['id'] == empId,
        orElse: () => {},
      );
      if (employee.isNotEmpty) {
        String department = employee['department'] ?? 'Unknown';
        counts[department] = (counts[department] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<Map<String, dynamic>> _getSelectedEmployeesDetails() {
    return _selectedEmployeeIds.map((empId) {
      return _allEmployees.firstWhere(
            (emp) => emp['id'] == empId,
        orElse: () => {
          'id': empId,
          'name': 'Unknown Employee',
          'designation': 'Unknown',
          'department': 'Unknown',
          'employeeNumber': '',
        },
      );
    }).toList();
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
      case 0: // Landing page
        return true;
      case 1: // Employee selection
        return _selectedEmployeeIds.isNotEmpty;
      case 2: // Preview
        return _selectedEmployeeIds.isNotEmpty;
      case 3: // Statistics & Save
        return _selectedEmployeeIds.isNotEmpty;
      default:
        return false;
    }
  }

  // ===== SAVE METHODS =====

  Future<void> _saveEmployeeList() async {
    if (_selectedEmployeeIds.isEmpty) {
      CustomSnackBar.errorSnackBar("Please select at least one employee");
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('employee_lists')
          .doc(widget.requesterId)
          .set({
        'employeeIds': _selectedEmployeeIds,
        'listName': _listName ?? 'My Employee List',
        'createdAt': _hasExistingList ? null : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'employeeCount': _selectedEmployeeIds.length,
        'designationBreakdown': _getDesignationCounts(),
        'departmentBreakdown': _getDepartmentCounts(),
        'employeeDetails': _getSelectedEmployeesDetails().map((emp) => {
          'id': emp['id'],
          'name': emp['name'],
          'designation': emp['designation'],
          'department': emp['department'],
          'employeeNumber': emp['employeeNumber'],
        }).toList(),
      }, SetOptions(merge: true));

      setState(() {
        _isSaving = false;
        _hasExistingList = true;
        _currentCustomList = List.from(_selectedEmployeeIds);
      });

      _showSuccessDialog();

    } catch (e) {
      setState(() => _isSaving = false);
      CustomSnackBar.errorSnackBar("Error saving list: $e");
    }
  }

  Future<void> _deleteEmployeeList() async {
    bool? confirmed = await _showDeleteConfirmationDialog();

    if (confirmed == true) {
      setState(() => _isSaving = true);

      try {
        await FirebaseFirestore.instance
            .collection('employee_lists')
            .doc(widget.requesterId)
            .delete();

        setState(() {
          _isSaving = false;
          _hasExistingList = false;
          _currentCustomList.clear();
          _selectedEmployeeIds.clear();
          _currentStep = 0;
        });

        _pageController.animateToPage(
          0,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );

        CustomSnackBar.successSnackBar("Employee list deleted successfully!");

      } catch (e) {
        setState(() => _isSaving = false);
        CustomSnackBar.errorSnackBar("Error deleting list: $e");
      }
    }
  }

  // ===== DIALOG METHODS =====

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.check_circle, color: Colors.green, size: 32),
            ),
            SizedBox(width: 12),
            Text("List Saved!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Your employee list has been saved successfully."),
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
                  Text("📋 ${_listName ?? 'My Employee List'}"),
                  Text("👥 ${_selectedEmployeeIds.length} employees"),
                  Text("🏢 ${_getDepartmentCounts().length} departments"),
                  Text("💼 ${_getDesignationCounts().length} designations"),
                ],
              ),
            ),
          ],
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

  Future<bool?> _showDeleteConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_forever, color: Colors.red, size: 32),
            ),
            SizedBox(width: 12),
            Text("Delete Employee List", style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Are you sure you want to delete your custom employee list?"),
            SizedBox(height: 8),
            Text(
              "This action cannot be undone and you'll lose all your saved employee selections.",
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("Delete"),
          ),
        ],
      ),
    );
  }

  // ===== BUILD METHODS =====

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Employee List"),
        backgroundColor: isDarkMode ? Colors.grey[900] : scaffoldTopGradientClr,
        actions: [
          if (_hasExistingList && _currentStep > 0)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: _isSaving ? null : _deleteEmployeeList,
              tooltip: "Delete List",
            ),
        ],
        bottom: _currentStep > 0 ? PreferredSize(
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
        ) : null,
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
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: accentColor))
            : PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _currentStep = index),
          children: [
            _buildLandingStep(),
            _buildEmployeeSelectionStep(),
            _buildPreviewStep(),
            _buildStatisticsStep(),
          ],
        ),
      ),
      bottomNavigationBar: _currentStep > 0 ? _buildBottomNavigation() : null,
    );
  }

  String _getStepTitle(int index) {
    switch (index) {
      case 0:
        return "Start";
      case 1:
        return "Select";
      case 2:
        return "Preview";
      case 3:
        return "Save";
      default:
        return "";
    }
  }

  // ===== STEP BUILDERS =====

  Widget _buildLandingStep() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          SizedBox(height: 60),

          // Main illustration
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
              border: Border.all(color: accentColor.withOpacity(0.3), width: 2),
            ),
            child: Icon(
              Icons.people_alt,
              size: 60,
              color: accentColor,
            ),
          ),

          SizedBox(height: 32),

          // Title and description
          Text(
            _hasExistingList ? "Manage Your Employee List" : "Create Your Employee List",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 16),

          Text(
            _hasExistingList
                ? "You already have a custom employee list with ${_currentCustomList.length} employees. You can view, edit, or recreate it."
                : "Create a custom employee list for faster overtime request processing. Select your frequently used employees once and reuse them.",
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 48),

          // Existing list card (if exists)
          if (_hasExistingList) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.bookmark, color: Colors.green, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _listName ?? 'My Employee List',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                            Text(
                              "${_currentCustomList.length} employees saved",
                              style: TextStyle(
                                color: Colors.green[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedEmployeeIds = List.from(_currentCustomList);
                              _currentStep = 2; // Go to preview
                            });
                            _pageController.animateToPage(
                              2,
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          icon: Icon(Icons.visibility),
                          label: Text("View List"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: BorderSide(color: Colors.green),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedEmployeeIds = List.from(_currentCustomList);
                              _currentStep = 1;
                            });
                            _pageController.animateToPage(
                              1,
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          icon: Icon(Icons.edit),
                          label: Text("Edit List"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            Text(
              "Or create a new list from scratch:",
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: 16,
              ),
            ),

            SizedBox(height: 16),
          ],

          // Main action button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedEmployeeIds.clear();
                  _currentStep = 1;
                });
                _pageController.animateToPage(
                  1,
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              icon: Icon(Icons.add_circle_outline, size: 24),
              label: Text(
                _hasExistingList ? "Create New List" : "Create Employee List",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ),

          SizedBox(height: 24),

          // Feature highlights
          _buildFeatureHighlights(),
        ],
      ),
    );
  }

  Widget _buildFeatureHighlights() {
    return Column(
      children: [
        Row(
          children: [
            _buildFeatureItem(Icons.speed, "Quick Selection", "Reuse your saved list for faster overtime requests"),
            SizedBox(width: 16),
            _buildFeatureItem(Icons.analytics, "Smart Insights", "View designation and department breakdowns"),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            _buildFeatureItem(Icons.edit, "Easy Management", "Add, remove, or edit employees anytime"),
            SizedBox(width: 16),
            _buildFeatureItem(Icons.sync, "Auto Sync", "Changes sync across all your overtime requests"),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800]!.withOpacity(0.5) : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: accentColor, size: 32),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeSelectionStep() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
            "${_selectedEmployeeIds.length} of ${_allEmployees.length} employees selected",
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),

          SizedBox(height: 24),

          // Current selection summary
          if (_selectedEmployeeIds.isNotEmpty) ...[
            Container(
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
                      Icon(Icons.people, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Selected: ${_selectedEmployeeIds.length} employees",
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _getDesignationCounts().entries.map((entry) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          "${entry.key}: ${entry.value}",
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],

          // Search bar
          TextField(
            controller: _searchController,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: "Search employees...",
              prefixIcon: Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _filterEmployees();
                },
              )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedEmployeeIds = _filteredEmployees
                          .map((emp) => emp['id'] as String)
                          .toList();
                    });
                  },
                  icon: Icon(Icons.select_all),
                  label: Text("Select All (${_filteredEmployees.length})"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedEmployeeIds.clear();
                    });
                  },
                  icon: Icon(Icons.clear_all),
                  label: Text("Clear All"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Employee list
          Container(
            height: 400,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _filteredEmployees.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text("No employees found", style: TextStyle(color: Colors.grey[600])),
                  if (_searchController.text.isNotEmpty) ...[
                    SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        _filterEmployees();
                      },
                      child: Text("Clear search"),
                    ),
                  ],
                ],
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: _filteredEmployees.length,
              itemBuilder: (context, index) {
                final employee = _filteredEmployees[index];
                final empId = employee['id'];
                final isSelected = _selectedEmployeeIds.contains(empId);
                final wasInOriginalList = _currentCustomList.contains(empId);

                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.green.withOpacity(0.2)
                        : wasInOriginalList
                        ? Colors.blue.withOpacity(0.1)
                        : isDarkMode
                        ? Colors.grey[800]!.withOpacity(0.3)
                        : Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.green
                          : wasInOriginalList
                          ? Colors.blue.withOpacity(0.5)
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: CheckboxListTile(
                    title: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isSelected ? Colors.green : Colors.grey,
                          child: Text(
                            employee['name'][0].toUpperCase(),
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employee['name'],
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              Text(
                                "${employee['designation']} | ${employee['department']}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                "ID: $empId | Emp #: ${employee['employeeNumber']}",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedEmployeeIds.add(empId);
                        } else {
                          _selectedEmployeeIds.remove(empId);
                        }
                      });
                    },
                    activeColor: Colors.green,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewStep() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final selectedEmployees = _getSelectedEmployeesDetails();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Preview Employee List",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Review your selected employees before saving",
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),

          SizedBox(height: 24),

          // Summary cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  "Total",
                  "${selectedEmployees.length}",
                  Icons.people,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  "Departments",
                  "${_getDepartmentCounts().length}",
                  Icons.business,
                  Colors.green,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  "Roles",
                  "${_getDesignationCounts().length}",
                  Icons.work,
                  Colors.orange,
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

          // List name input
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "List Name",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  onChanged: (value) => setState(() => _listName = value),
                  decoration: InputDecoration(
                    hintText: "Enter list name (e.g., Production Team, Night Shift)",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  controller: TextEditingController(text: _listName ?? 'My Employee List'),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Employee details table
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        "Selected Employees (${selectedEmployees.length})",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  constraints: BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: selectedEmployees.length,
                    itemBuilder: (context, index) {
                      final employee = selectedEmployees[index];
                      return Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border(
                            top: index > 0 ? BorderSide(color: Colors.grey[200]!) : BorderSide.none,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text(
                                  employee['name'][0].toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    employee['name'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    "${employee['designation']} | ${employee['department']}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              employee['id'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsStep() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final designationCounts = _getDesignationCounts();
    final departmentCounts = _getDepartmentCounts();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Employee Statistics",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Breakdown of your selected employees",
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),

          SizedBox(height: 24),

          // Overall summary
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.purple.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.analytics, size: 48, color: Colors.blue[700]),
                SizedBox(height: 12),
                Text(
                  "List Summary",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "${_selectedEmployeeIds.length} employees across ${departmentCounts.length} departments",
                  style: TextStyle(
                    color: Colors.blue[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Designation breakdown
          _buildBreakdownSection(
            title: "By Designation",
            icon: Icons.work,
            color: Colors.orange,
            data: designationCounts,
          ),

          SizedBox(height: 16),

          // Department breakdown
          _buildBreakdownSection(
            title: "By Department",
            icon: Icons.business,
            color: Colors.green,
            data: departmentCounts,
          ),

          SizedBox(height: 32),

          // Save confirmation
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.save, size: 48, color: Colors.green[700]),
                SizedBox(height: 12),
                Text(
                  "Ready to Save!",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Your employee list '${_listName ?? 'My Employee List'}' is ready to be saved.",
                  style: TextStyle(
                    color: Colors.green[600],
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
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

  Widget _buildBreakdownSection({
    required String title,
    required IconData icon,
    required Color color,
    required Map<String, int> data,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _getColorShade(color, 700),
                  ),
                ),
              ],
            ),
          ),
          ...data.entries.map((entry) {
            double percentage = (entry.value / _selectedEmployeeIds.length) * 100;
            return Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      entry.key,
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: percentage / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${entry.value}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getColorShade(color, 700),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 1)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  child: Text("Previous"),
                ),
              ),
            if (_currentStep > 1) SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _currentStep == 3
                    ? (_isSaving ? null : _saveEmployeeList)
                    : (_canProceedFromStep(_currentStep) ? _nextStep : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentStep == 3 ? Colors.green : accentColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text("Saving..."),
                  ],
                )
                    : Text(_currentStep == 3 ? "Save Employee List" : "Next"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}