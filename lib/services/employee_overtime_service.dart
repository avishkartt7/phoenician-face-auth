// lib/services/employee_overtime_service.dart - FIXED FOR INDEX ERROR

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phoenician_face_auth/model/overtime_request_model.dart';
import 'package:flutter/foundation.dart';

class EmployeeOvertimeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if an employee has overtime access by dynamically finding their record
  Future<bool> hasOvertimeAccess(String employeeId) async {
    try {
      debugPrint("=== CHECKING OVERTIME ACCESS FOR: $employeeId ===");

      // Step 1: Try to find the employee in MasterSheet directly
      DocumentSnapshot masterDoc = await _firestore
          .collection('MasterSheet')
          .doc('Employee-Data')
          .collection('employees')
          .doc(employeeId)
          .get();

      if (masterDoc.exists) {
        return _checkOvertimeFields(masterDoc.data() as Map<String, dynamic>, employeeId, 'MasterSheet');
      }

      // Step 2: Try to find employee's PIN/number from employees collection to map to EMP format
      String? empId = await _findEmployeeEMPId(employeeId);
      if (empId != null) {
        debugPrint("🔍 Found EMP ID: $empId for employee: $employeeId");

        DocumentSnapshot empMasterDoc = await _firestore
            .collection('MasterSheet')
            .doc('Employee-Data')
            .collection('employees')
            .doc(empId)
            .get();

        if (empMasterDoc.exists) {
          return _checkOvertimeFields(empMasterDoc.data() as Map<String, dynamic>, empId, 'MasterSheet');
        }
      }

      // Step 3: Check employees collection as fallback
      DocumentSnapshot empDoc = await _firestore
          .collection('employees')
          .doc(employeeId)
          .get();

      if (empDoc.exists) {
        return _checkOvertimeFields(empDoc.data() as Map<String, dynamic>, employeeId, 'employees');
      }

      debugPrint("❌ Employee $employeeId not found in any collection");
      return false;
    } catch (e) {
      debugPrint("❌ Error checking overtime access for $employeeId: $e");
      return false;
    }
  }

  /// Helper method to check overtime fields in employee data
  bool _checkOvertimeFields(Map<String, dynamic> data, String employeeId, String source) {
    // Check all possible overtime fields
    bool hasOvertime = data['hasOvertime'] == true ||
        data['overtime'] == 'Yes' ||
        data['overtime'] == 'yes' ||
        data['overtime'] == true ||
        data['overtimeAccessGrantedAt'] != null;

    debugPrint("✅ Found employee in $source:");
    debugPrint("  - Employee: ${data['employeeName'] ?? data['name'] ?? 'Unknown'}");
    debugPrint("  - Employee Number: ${data['employeeNumber'] ?? 'N/A'}");
    debugPrint("  - hasOvertime: ${data['hasOvertime']}");
    debugPrint("  - overtime: ${data['overtime']}");
    debugPrint("  - Final Result: $hasOvertime");

    if (hasOvertime) {
      debugPrint("✅ Employee $employeeId has overtime access from $source");
    } else {
      debugPrint("❌ Employee $employeeId does not have overtime access in $source");
    }

    return hasOvertime;
  }

  /// Dynamically find employee's EMP ID by looking up their details
  Future<String?> _findEmployeeEMPId(String originalId) async {
    try {
      debugPrint("🔍 Looking for EMP ID for employee: $originalId");

      // If already in EMP format, return as is
      if (originalId.startsWith('EMP')) {
        return originalId;
      }

      // Check if we can find this employee in the employees collection
      DocumentSnapshot empDoc = await _firestore
          .collection('employees')
          .doc(originalId)
          .get();

      if (empDoc.exists) {
        Map<String, dynamic> data = empDoc.data() as Map<String, dynamic>;

        // Look for employee number, PIN, or other identifiers
        List<String> possibleFields = ['employeeNumber', 'pin', 'empId', 'employeeId'];

        for (String field in possibleFields) {
          if (data[field] != null) {
            String value = data[field].toString();
            String empId = value.startsWith('EMP') ? value : 'EMP$value';

            debugPrint("✅ Found potential EMP ID from field '$field': $empId");

            // Verify this EMP ID exists in MasterSheet
            DocumentSnapshot masterCheck = await _firestore
                .collection('MasterSheet')
                .doc('Employee-Data')
                .collection('employees')
                .doc(empId)
                .get();

            if (masterCheck.exists) {
              debugPrint("✅ Confirmed EMP ID exists in MasterSheet: $empId");
              return empId;
            }
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint("❌ Error finding EMP ID: $e");
      return null;
    }
  }

  /// Get all overtime requests where the employee is selected (FIXED - NO INDEX REQUIRED)
  Future<List<OvertimeRequest>> getOvertimeHistoryForEmployee(String employeeId) async {
    try {
      debugPrint("=== FETCHING OVERTIME HISTORY FOR EMPLOYEE: $employeeId ===");

      // Get all possible employee IDs to search for
      List<String> searchIds = await _getAllEmployeeIds(employeeId);
      debugPrint("Searching overtime requests for IDs: $searchIds");

      Set<String> uniqueRequestIds = {}; // To avoid duplicates
      List<OvertimeRequest> allRequests = [];

      // Search for overtime requests with each ID (WITHOUT orderBy to avoid index requirement)
      for (String searchId in searchIds) {
        debugPrint("🔍 Searching overtime requests for ID: $searchId");

        // FIXED: Remove orderBy to avoid index requirement
        QuerySnapshot snapshot = await _firestore
            .collection('overtime_requests')
            .where('employeeIds', arrayContains: searchId)
            .limit(100) // Still limit results
            .get();

        debugPrint("Found ${snapshot.docs.length} overtime documents for ID: $searchId");

        for (var doc in snapshot.docs) {
          // Skip if we already processed this request
          if (uniqueRequestIds.contains(doc.id)) {
            continue;
          }
          uniqueRequestIds.add(doc.id);

          try {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

            debugPrint("Processing overtime request ${doc.id}:");
            debugPrint("  - Project: ${data['projectName']}");
            debugPrint("  - Status: ${data['status']}");
            debugPrint("  - Employee IDs: ${data['employeeIds']}");

            OvertimeRequest request = _mapFirestoreToOvertimeRequest(doc.id, data);
            allRequests.add(request);

          } catch (e) {
            debugPrint("❌ Error parsing overtime request ${doc.id}: $e");
          }
        }
      }

      // Sort in code instead of in query (newest first)
      allRequests.sort((a, b) => b.requestTime.compareTo(a.requestTime));

      debugPrint("✅ Successfully loaded ${allRequests.length} unique overtime requests");
      return allRequests;

    } catch (e) {
      debugPrint("❌ Error fetching overtime history for $employeeId: $e");
      return [];
    }
  }

  /// Get today's approved overtime requests for the employee (FIXED - NO INDEX REQUIRED)
  Future<List<OvertimeRequest>> getTodayOvertimeForEmployee(String employeeId) async {
    try {
      debugPrint("=== FETCHING TODAY'S OVERTIME FOR EMPLOYEE: $employeeId ===");

      DateTime today = DateTime.now();

      // Get all possible employee IDs to search for
      List<String> searchIds = await _getAllEmployeeIds(employeeId);

      Set<String> uniqueRequestIds = {};
      List<OvertimeRequest> allTodayRequests = [];

      // Search for each ID (WITHOUT orderBy to avoid index requirement)
      for (String searchId in searchIds) {
        debugPrint("🔍 Searching today's overtime for ID: $searchId");

        // FIXED: Simple query without orderBy
        QuerySnapshot snapshot = await _firestore
            .collection('overtime_requests')
            .where('employeeIds', arrayContains: searchId)
            .where('status', isEqualTo: 'approved')
            .get();

        debugPrint("Found ${snapshot.docs.length} approved overtime requests for ID: $searchId");

        for (var doc in snapshot.docs) {
          if (uniqueRequestIds.contains(doc.id)) {
            continue;
          }
          uniqueRequestIds.add(doc.id);

          try {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

            DateTime startTime = (data['startTime'] as Timestamp).toDate();
            DateTime endTime = (data['endTime'] as Timestamp).toDate();

            // Check if overtime falls within today's date
            bool isToday = _isOvertimeToday(startTime, endTime, today);

            if (isToday) {
              OvertimeRequest request = _mapFirestoreToOvertimeRequest(doc.id, data);
              allTodayRequests.add(request);

              debugPrint("✅ Found today's overtime: ${request.projectName}");
            }
          } catch (e) {
            debugPrint("❌ Error parsing today's overtime request ${doc.id}: $e");
          }
        }
      }

      debugPrint("✅ Found ${allTodayRequests.length} overtime requests for today");
      return allTodayRequests;

    } catch (e) {
      debugPrint("❌ Error fetching today's overtime for $employeeId: $e");
      return [];
    }
  }

  /// Get all possible employee IDs for searching (without hardcoding)
  Future<List<String>> _getAllEmployeeIds(String originalId) async {
    List<String> allIds = [originalId]; // Always include original

    // Try to find EMP ID dynamically
    String? empId = await _findEmployeeEMPId(originalId);
    if (empId != null && !allIds.contains(empId)) {
      allIds.add(empId);
    }

    // If original ID starts with EMP, also try without EMP prefix
    if (originalId.startsWith('EMP')) {
      String withoutEMP = originalId.substring(3);
      if (!allIds.contains(withoutEMP)) {
        allIds.add(withoutEMP);
      }
    }

    return allIds;
  }

  /// Get overtime statistics for the employee
  Future<Map<String, dynamic>> getOvertimeStatistics(String employeeId) async {
    try {
      debugPrint("=== GETTING OVERTIME STATISTICS FOR: $employeeId ===");

      List<OvertimeRequest> allRequests = await getOvertimeHistoryForEmployee(employeeId);

      int totalRequests = allRequests.length;
      int approvedRequests = allRequests.where((r) => r.status == OvertimeRequestStatus.approved).length;
      int pendingRequests = allRequests.where((r) => r.status == OvertimeRequestStatus.pending).length;
      int rejectedRequests = allRequests.where((r) => r.status == OvertimeRequestStatus.rejected).length;

      double totalApprovedHours = allRequests
          .where((r) => r.status == OvertimeRequestStatus.approved)
          .fold(0.0, (sum, r) => sum + r.totalDurationHours);

      // Current month statistics
      DateTime now = DateTime.now();
      DateTime startOfMonth = DateTime(now.year, now.month, 1);

      List<OvertimeRequest> thisMonthRequests = allRequests.where((r) {
        return r.requestTime.isAfter(startOfMonth) || r.requestTime.isAtSameMomentAs(startOfMonth);
      }).toList();

      int thisMonthTotal = thisMonthRequests.length;
      double thisMonthHours = thisMonthRequests
          .where((r) => r.status == OvertimeRequestStatus.approved)
          .fold(0.0, (sum, r) => sum + r.totalDurationHours);

      // Most frequent project
      Map<String, int> projectCount = {};
      for (var request in allRequests) {
        String projectName = request.totalProjects > 1 ? 'Multi-Project' : request.projectName;
        projectCount[projectName] = (projectCount[projectName] ?? 0) + 1;
      }

      String mostFrequentProject = 'None';
      if (projectCount.isNotEmpty) {
        mostFrequentProject = projectCount.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }

      Map<String, dynamic> stats = {
        'totalRequests': totalRequests,
        'approvedRequests': approvedRequests,
        'pendingRequests': pendingRequests,
        'rejectedRequests': rejectedRequests,
        'totalApprovedHours': totalApprovedHours,
        'thisMonthRequests': thisMonthTotal,
        'thisMonthHours': thisMonthHours,
        'mostFrequentProject': mostFrequentProject,
        'approvalRate': totalRequests > 0 ? (approvedRequests / totalRequests) * 100 : 0.0,
      };

      debugPrint("✅ Overtime statistics: $stats");
      return stats;
    } catch (e) {
      debugPrint("❌ Error getting overtime statistics for $employeeId: $e");
      return {
        'totalRequests': 0,
        'approvedRequests': 0,
        'pendingRequests': 0,
        'rejectedRequests': 0,
        'totalApprovedHours': 0.0,
        'thisMonthRequests': 0,
        'thisMonthHours': 0.0,
        'mostFrequentProject': 'None',
        'approvalRate': 0.0,
      };
    }
  }

  /// Get employee details from either collection (dynamic search)
  Future<Map<String, dynamic>?> getEmployeeDetails(String employeeId) async {
    try {
      debugPrint("=== GETTING EMPLOYEE DETAILS FOR: $employeeId ===");

      // Try MasterSheet first
      String? empId = await _findEmployeeEMPId(employeeId);
      if (empId != null) {
        DocumentSnapshot masterDoc = await _firestore
            .collection('MasterSheet')
            .doc('Employee-Data')
            .collection('employees')
            .doc(empId)
            .get();

        if (masterDoc.exists) {
          Map<String, dynamic> data = masterDoc.data() as Map<String, dynamic>;

          Map<String, dynamic> employeeDetails = {
            'id': employeeId,
            'empId': empId,
            'name': data['employeeName'] ?? data['name'] ?? 'Unknown',
            'designation': data['designation'] ?? 'No designation',
            'department': data['department'] ?? 'No department',
            'employeeNumber': data['employeeNumber'] ?? '',
            'hasOvertime': data['hasOvertime'] == true || data['overtime'] == 'Yes',
            'source': 'MasterSheet',
          };

          debugPrint("✅ Found employee details in MasterSheet");
          return employeeDetails;
        }
      }

      // Try employees collection
      DocumentSnapshot empDoc = await _firestore
          .collection('employees')
          .doc(employeeId)
          .get();

      if (empDoc.exists) {
        Map<String, dynamic> data = empDoc.data() as Map<String, dynamic>;

        Map<String, dynamic> employeeDetails = {
          'id': employeeId,
          'name': data['name'] ?? data['employeeName'] ?? 'Unknown',
          'designation': data['designation'] ?? 'No designation',
          'department': data['department'] ?? 'No department',
          'employeeNumber': data['employeeNumber'] ?? '',
          'hasOvertime': data['hasOvertime'] == true ||
              data['overtime'] == 'Yes' ||
              data['overtimeAccessGrantedAt'] != null,
          'source': 'Employees',
        };

        debugPrint("✅ Found employee details in employees collection");
        return employeeDetails;
      }

      debugPrint("❌ Employee $employeeId not found in any collection");
      return null;
    } catch (e) {
      debugPrint("❌ Error getting employee details for $employeeId: $e");
      return null;
    }
  }

  /// Check if overtime is scheduled for today
  bool _isOvertimeToday(DateTime startTime, DateTime endTime, DateTime today) {
    DateTime startOfDay = DateTime(today.year, today.month, today.day);
    DateTime endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    bool startsToday = startTime.year == today.year &&
        startTime.month == today.month &&
        startTime.day == today.day;

    bool endsToday = endTime.year == today.year &&
        endTime.month == today.month &&
        endTime.day == today.day;

    bool spansToday = startTime.isBefore(startOfDay) && endTime.isAfter(endOfDay);

    return startsToday || endsToday || spansToday;
  }

  /// Helper method to map Firestore data to OvertimeRequest
  OvertimeRequest _mapFirestoreToOvertimeRequest(String id, Map<String, dynamic> data) {
    try {
      // Handle projects (both single and multi-project formats)
      List<OvertimeProjectEntry> projects = [];

      if (data['projects'] != null && data['projects'] is List) {
        // Multi-project format
        for (var projectData in data['projects']) {
          projects.add(OvertimeProjectEntry.fromMap(projectData));
        }
      } else {
        // Single project format
        projects.add(OvertimeProjectEntry(
          projectName: data['projectName'] ?? '',
          projectCode: data['projectCode'] ?? '',
          startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
          endTime: (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
          employeeIds: List<String>.from(data['employeeIds'] ?? []),
        ));
      }

      // Parse status
      OvertimeRequestStatus status = OvertimeRequestStatus.pending;
      switch (data['status']?.toString().toLowerCase()) {
        case 'approved':
          status = OvertimeRequestStatus.approved;
          break;
        case 'rejected':
          status = OvertimeRequestStatus.rejected;
          break;
        case 'cancelled':
          status = OvertimeRequestStatus.cancelled;
          break;
        default:
          status = OvertimeRequestStatus.pending;
          break;
      }

      // Calculate duration in hours
      DateTime startTime = (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();
      DateTime endTime = (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now();
      double calculatedHours = endTime.difference(startTime).inMinutes / 60.0;
      double totalHours = (data['totalHours'] ?? calculatedHours).toDouble();

      return OvertimeRequest(
        id: id,
        requesterId: data['requesterId'] ?? '',
        requesterName: data['requesterName'] ?? '',
        approverEmpId: data['approverEmpId'] ?? '',
        approverName: data['approverName'] ?? '',
        projectName: data['projectName'] ?? '',
        projectCode: data['projectCode'] ?? '',
        startTime: startTime,
        endTime: endTime,
        employeeIds: List<String>.from(data['employeeIds'] ?? []),
        requestTime: (data['requestTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        status: status,
        responseMessage: data['responseMessage'],
        responseTime: (data['responseTime'] as Timestamp?)?.toDate(),
        totalProjects: data['totalProjects'] ?? 1,
        totalEmployeeCount: data['totalEmployees'] ?? (data['employeeIds'] as List?)?.length ?? 0,
        totalDurationHours: totalHours,
        projects: projects,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        version: data['version'] ?? 1,
        isActive: data['isActive'] ?? true,
        metadata: data['metadata'],
      );
    } catch (e) {
      debugPrint("❌ Error mapping Firestore data to OvertimeRequest: $e");
      rethrow;
    }
  }
}