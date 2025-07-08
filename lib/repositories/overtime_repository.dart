// lib/repositories/overtime_repository.dart - COMPLETE CORRECTED VERSION
// Fixed to match the enhanced OvertimeRequest model structure

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:phoenician_face_auth/model/overtime_request_model.dart';
import 'package:phoenician_face_auth/services/database_helper.dart';
import 'package:phoenician_face_auth/services/connectivity_service.dart';
import 'package:phoenician_face_auth/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OvertimeRepository {
  final FirebaseFirestore _firestore;
  final DatabaseHelper _dbHelper;
  final ConnectivityService _connectivityService;
  final NotificationService _notificationService;

  OvertimeRepository({
    required FirebaseFirestore firestore,
    required DatabaseHelper dbHelper,
    required ConnectivityService connectivityService,
    required NotificationService notificationService,
  }) : _firestore = firestore,
        _dbHelper = dbHelper,
        _connectivityService = connectivityService,
        _notificationService = notificationService;

  // ✅ ENHANCED: Get the current overtime approver from database
  Future<Map<String, dynamic>?> getOvertimeApprover() async {
    try {
      debugPrint("=== FETCHING OVERTIME APPROVER FROM DATABASE ===");

      // Method 1: Check for specific overtime_approvers collection
      QuerySnapshot approversSnapshot = await _firestore
          .collection('overtime_approvers')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (approversSnapshot.docs.isNotEmpty) {
        var approverDoc = approversSnapshot.docs.first;
        var approverData = approverDoc.data() as Map<String, dynamic>;
        debugPrint("Found overtime approver in overtime_approvers: ${approverData['approverId']}");

        return {
          'approverId': approverData['approverId'],
          'approverName': approverData['approverName'] ?? 'Unknown',
          'source': 'overtime_approvers'
        };
      }

      // Method 2: Check employees collection for overtime approver role
      QuerySnapshot employeesSnapshot = await _firestore
          .collection('employees')
          .where('hasOvertimeApprovalAccess', isEqualTo: true)
          .limit(1)
          .get();

      if (employeesSnapshot.docs.isNotEmpty) {
        var approverDoc = employeesSnapshot.docs.first;
        var approverData = approverDoc.data() as Map<String, dynamic>;
        debugPrint("Found overtime approver in employees: ${approverDoc.id}");

        return {
          'approverId': approverDoc.id,
          'approverName': approverData['name'] ?? approverData['employeeName'] ?? 'Unknown',
          'source': 'employees'
        };
      }

      // Method 3: Check line_managers collection
      QuerySnapshot managersSnapshot = await _firestore
          .collection('line_managers')
          .where('canApproveOvertime', isEqualTo: true)
          .limit(1)
          .get();

      if (managersSnapshot.docs.isNotEmpty) {
        var managerDoc = managersSnapshot.docs.first;
        var managerData = managerDoc.data() as Map<String, dynamic>;
        String managerId = managerData['managerId'] ?? managerDoc.id;

        debugPrint("Found overtime approver in line_managers: $managerId");

        return {
          'approverId': managerId,
          'approverName': managerData['managerName'] ?? 'Manager',
          'source': 'line_managers'
        };
      }

      // Method 4: Ultimate fallback to EMP1289 if nothing else found
      debugPrint("No dynamic approver found, falling back to EMP1289");

      return {
        'approverId': 'EMP1289',
        'approverName': 'Default Approver',
        'source': 'fallback'
      };

    } catch (e) {
      debugPrint("Error fetching overtime approver: $e");
      // Return fallback approver
      return {
        'approverId': 'EMP1289',
        'approverName': 'Default Approver',
        'source': 'error_fallback'
      };
    }
  }

  // ✅ ENHANCED: Create a new overtime request with multi-project support
  Future<String?> createOvertimeRequest({
    required String projectName,
    required String projectCode,
    required DateTime startTime,
    required DateTime endTime,
    required List<String> employeeIds,
    required String requesterId,
    required String requesterName,
    // ✅ NEW: Multi-project support
    List<OvertimeProjectEntry>? projects,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint("=== CREATING ENHANCED OVERTIME REQUEST ===");
      debugPrint("Requester: $requesterName ($requesterId)");
      debugPrint("Project: $projectName");
      debugPrint("Employees: ${employeeIds.length}");

      // Get the current overtime approver dynamically
      Map<String, dynamic>? approverInfo = await getOvertimeApprover();

      if (approverInfo == null) {
        throw Exception("Could not determine overtime approver");
      }

      String approverId = approverInfo['approverId'];
      String approverName = approverInfo['approverName'];

      debugPrint("Dynamic approver found: $approverName ($approverId) from ${approverInfo['source']}");

      // ✅ ENHANCED: Handle multi-project or single project
      List<OvertimeProjectEntry> projectList = projects ?? [
        OvertimeProjectEntry(
          projectName: projectName,
          projectCode: projectCode,
          startTime: startTime,
          endTime: endTime,
          employeeIds: employeeIds,
        )
      ];

      // Calculate totals
      int totalProjects = projectList.length;
      int totalEmployees = employeeIds.length;
      double totalHours = projectList.fold(0.0, (sum, p) => sum + p.durationInHours);

      // Create the enhanced overtime request
      final requestData = {
        // ✅ NEW: Multi-project structure
        'projects': projectList.map((p) => p.toMap()).toList(),

        // Basic fields
        'projectName': totalProjects == 1 ? projectName : "$totalProjects Projects",
        'projectCode': totalProjects == 1 ? projectCode : 'MULTI',
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'employeeIds': employeeIds,
        'requesterId': requesterId,
        'requesterName': requesterName,
        'approverEmpId': approverId,
        'approverName': approverName,
        'requestTime': FieldValue.serverTimestamp(),
        'status': 'pending',

        // ✅ NEW: Enhanced tracking fields
        'totalProjects': totalProjects,
        'totalEmployees': totalEmployees,
        'totalHours': totalHours,
        'isActive': true,
        'version': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        // ✅ NEW: Additional metadata
        'metadata': metadata ?? {},
      };

      // Save to Firestore
      DocumentReference docRef = await _firestore
          .collection('overtime_requests')
          .add(requestData);

      debugPrint("Enhanced overtime request created with ID: ${docRef.id}");

      // ✅ ENHANCED: Send notifications with multi-project support
      await _sendOvertimeNotifications(
        requestId: docRef.id,
        approverId: approverId,
        approverName: approverName,
        requesterId: requesterId,
        requesterName: requesterName,
        projectName: requestData['projectName'] as String,
        projectCode: requestData['projectCode'] as String,
        employeeCount: employeeIds.length,
        totalProjects: totalProjects,
        totalHours: totalHours,
      );

      return docRef.id;

    } catch (e) {
      debugPrint("Error creating overtime request: $e");
      rethrow;
    }
  }

  // ✅ FIXED: Get requests created by a specific requester (for history)
  Future<List<OvertimeRequest>> getRequestsForRequester(String requesterId) async {
    try {
      debugPrint("Getting request history for requester: $requesterId");

      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        QuerySnapshot snapshot = await _firestore
            .collection('overtime_requests')
            .where('requesterId', isEqualTo: requesterId)
            .orderBy('requestTime', descending: true)
            .limit(50)
            .get();

        List<OvertimeRequest> requests = [];
        for (var doc in snapshot.docs) {
          try {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            requests.add(_mapToOvertimeRequest(doc.id, data));
          } catch (e) {
            debugPrint("Error parsing request ${doc.id}: $e");
          }
        }

        debugPrint("Found ${requests.length} requests for requester $requesterId");
        return requests;
      } else {
        // Offline mode - get from local database
        debugPrint("Fetching requester history from local database");
        final db = await _dbHelper.database;
        final List<Map<String, dynamic>> maps = await db.query(
          'overtime_requests',
          where: 'requester_id = ?',
          whereArgs: [requesterId],
          orderBy: 'request_time DESC',
          limit: 50,
        );

        // ✅ FIXED: Use correct fromMap method
        return maps.map<OvertimeRequest>((map) => _mapLocalToOvertimeRequest(map)).toList();
      }
    } catch (e) {
      debugPrint("Error getting requester history: $e");
      return [];
    }
  }

  // ✅ ENHANCED: Get all requests with filtering
  Future<List<OvertimeRequest>> getAllRequests({
    int? limit,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('overtime_requests');

      // Add filters
      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      if (startDate != null) {
        query = query.where('requestTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('requestTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      query = query.orderBy('requestTime', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      QuerySnapshot snapshot = await query.get();

      List<OvertimeRequest> requests = [];
      for (var doc in snapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          requests.add(_mapToOvertimeRequest(doc.id, data));
        } catch (e) {
          debugPrint("Error parsing request ${doc.id}: $e");
        }
      }

      return requests;
    } catch (e) {
      debugPrint("Error getting all requests: $e");
      return [];
    }
  }

  // ✅ ENHANCED: Get requests by status with pagination
  Future<List<OvertimeRequest>> getRequestsByStatus(
      OvertimeRequestStatus status, {
        int? limit,
        DocumentSnapshot? startAfter,
      }) async {
    try {
      Query query = _firestore
          .collection('overtime_requests')
          .where('status', isEqualTo: status.value)
          .orderBy('requestTime', descending: true);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      QuerySnapshot snapshot = await query.get();

      List<OvertimeRequest> requests = [];
      for (var doc in snapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          requests.add(_mapToOvertimeRequest(doc.id, data));
        } catch (e) {
          debugPrint("Error parsing request ${doc.id}: $e");
        }
      }

      return requests;
    } catch (e) {
      debugPrint("Error getting requests by status: $e");
      return [];
    }
  }

  // ✅ ENHANCED: Search requests with multiple criteria
  Future<List<OvertimeRequest>> searchRequests(String query, {
    String? requesterId,
    String? approverId,
    OvertimeRequestStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query baseQuery = _firestore.collection('overtime_requests');

      if (requesterId != null) {
        baseQuery = baseQuery.where('requesterId', isEqualTo: requesterId);
      }

      if (approverId != null) {
        List<String> approverIds = [
          approverId,
          approverId.startsWith('EMP') ? approverId.substring(3) : 'EMP$approverId',
        ];
        baseQuery = baseQuery.where('approverEmpId', whereIn: approverIds);
      }

      if (status != null) {
        baseQuery = baseQuery.where('status', isEqualTo: status.value);
      }

      if (startDate != null) {
        baseQuery = baseQuery.where('requestTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        baseQuery = baseQuery.where('requestTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      QuerySnapshot snapshot = await baseQuery
          .orderBy('requestTime', descending: true)
          .get();

      List<OvertimeRequest> allRequests = [];
      for (var doc in snapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          allRequests.add(_mapToOvertimeRequest(doc.id, data));
        } catch (e) {
          debugPrint("Error parsing request ${doc.id}: $e");
        }
      }

      // Filter by search query text
      if (query.isNotEmpty) {
        String lowerQuery = query.toLowerCase();
        allRequests = allRequests.where((request) {
          return request.projectsSummary.toLowerCase().contains(lowerQuery) ||
              request.requesterName.toLowerCase().contains(lowerQuery) ||
              request.approverName.toLowerCase().contains(lowerQuery);
        }).toList();
      }

      return allRequests;
    } catch (e) {
      debugPrint("Error searching requests: $e");
      return [];
    }
  }

  // ✅ ENHANCED: Get pending requests for approver with better error handling
  Future<List<OvertimeRequest>> getPendingRequestsForApprover(String approverId) async {
    try {
      debugPrint("=== FETCHING PENDING REQUESTS FOR APPROVER ===");
      debugPrint("Approver ID: $approverId");

      List<OvertimeRequest> requests = [];

      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        // Try exact match first
        QuerySnapshot exactSnapshot = await _firestore
            .collection('overtime_requests')
            .where('status', isEqualTo: 'pending')
            .where('approverEmpId', isEqualTo: approverId)
            .orderBy('requestTime', descending: true)
            .get();

        debugPrint("Exact match found ${exactSnapshot.docs.length} requests");

        // Try alternative ID format if no exact match
        if (exactSnapshot.docs.isEmpty) {
          String altId = approverId.startsWith('EMP')
              ? approverId.substring(3)
              : 'EMP$approverId';

          QuerySnapshot altSnapshot = await _firestore
              .collection('overtime_requests')
              .where('status', isEqualTo: 'pending')
              .where('approverEmpId', isEqualTo: altId)
              .orderBy('requestTime', descending: true)
              .get();

          debugPrint("Alternative ID ($altId) found ${altSnapshot.docs.length} requests");
          exactSnapshot = altSnapshot;
        }

        // Parse documents safely
        for (var doc in exactSnapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            debugPrint("Processing request ${doc.id}: approverEmpId = ${data['approverEmpId']}");

            OvertimeRequest request = _mapToOvertimeRequest(doc.id, data);
            requests.add(request);

          } catch (e) {
            debugPrint("Error parsing request ${doc.id}: $e");
            continue;
          }
        }

        // Cache successful requests
        for (var request in requests) {
          await _cacheOvertimeRequest(request);
        }

        debugPrint("Successfully loaded ${requests.length} requests from Firestore");
        return requests;

      } else {
        // Offline mode - get from local database
        debugPrint("Fetching pending requests from local database");
        final db = await _dbHelper.database;
        final List<Map<String, dynamic>> maps = await db.query(
          'overtime_requests',
          where: 'status = ? AND (approver_emp_id = ? OR approver_emp_id = ?)',
          whereArgs: [
            'pending',
            approverId,
            approverId.startsWith('EMP') ? approverId.substring(3) : 'EMP$approverId'
          ],
          orderBy: 'request_time DESC',
        );

        debugPrint("Found ${maps.length} pending requests locally");
        return maps.map<OvertimeRequest>((map) => _mapLocalToOvertimeRequest(map)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching pending requests: $e");
      return [];
    }
  }

  // ✅ ENHANCED: Update request status with better tracking
  Future<bool> updateRequestStatus(
      String requestId,
      OvertimeRequestStatus status,
      String? responseMessage,
      ) async {
    try {
      debugPrint("Updating request $requestId to status: ${status.displayName}");

      // Get the request first to gather details for notifications
      DocumentSnapshot requestDoc = await _firestore
          .collection('overtime_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        debugPrint("Request not found: $requestId");
        return false;
      }

      Map<String, dynamic> requestData = requestDoc.data() as Map<String, dynamic>;

      // Update the request status
      await _firestore.collection('overtime_requests').doc(requestId).update({
        'status': status.value,
        'responseMessage': responseMessage,
        'responseTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'version': FieldValue.increment(1),
      });

      // ✅ ENHANCED: Send status update notification
      try {
        await _sendStatusUpdateNotification(
          requestId: requestId,
          requestData: requestData,
          newStatus: status,
          responseMessage: responseMessage,
        );
      } catch (notificationError) {
        debugPrint("Error sending status update notification: $notificationError");
      }

      debugPrint("Request status updated successfully");
      return true;
    } catch (e) {
      debugPrint("Error updating request status: $e");
      return false;
    }
  }

  // ✅ NEW: Get employee details for a request
  Future<List<Map<String, dynamic>>> getEmployeeDetailsForRequest(List<String> employeeIds) async {
    try {
      List<Map<String, dynamic>> employees = [];

      for (String empId in employeeIds) {
        // Try employees collection first
        DocumentSnapshot empDoc = await _firestore.collection('employees').doc(empId).get();

        if (empDoc.exists) {
          Map<String, dynamic> data = empDoc.data() as Map<String, dynamic>;
          data['id'] = empId;
          employees.add(data);
        } else {
          // Try MasterSheet
          DocumentSnapshot masterDoc = await _firestore
              .collection('MasterSheet')
              .doc('Employee-Data')
              .collection('employees')
              .doc(empId)
              .get();

          if (masterDoc.exists) {
            Map<String, dynamic> data = masterDoc.data() as Map<String, dynamic>;
            data['id'] = empId;
            employees.add(data);
          }
        }
      }

      return employees;
    } catch (e) {
      debugPrint("Error getting employee details: $e");
      return [];
    }
  }

  // ✅ NEW: Get comprehensive statistics
  Future<Map<String, dynamic>> getRequestStatistics({
    String? requesterId,
    String? approverId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('overtime_requests');

      if (requesterId != null) {
        query = query.where('requesterId', isEqualTo: requesterId);
      }

      if (approverId != null) {
        List<String> approverIds = [
          approverId,
          approverId.startsWith('EMP') ? approverId.substring(3) : 'EMP$approverId',
        ];
        query = query.where('approverEmpId', whereIn: approverIds);
      }

      if (startDate != null) {
        query = query.where('requestTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('requestTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      QuerySnapshot snapshot = await query.get();

      Map<String, int> statusCounts = {
        'total': 0,
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'cancelled': 0,
      };

      double totalHours = 0;
      int totalEmployees = 0;
      int multiProjectRequests = 0;
      Map<String, int> projectBreakdown = {};

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String status = data['status'] ?? 'pending';

        statusCounts['total'] = statusCounts['total']! + 1;
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;

        totalHours += (data['totalHours'] ?? 0).toDouble();
        totalEmployees += ((data['totalEmployees'] ?? 0) as num).toInt();

        int projects = data['totalProjects'] ?? 1;
        if (projects > 1) {
          multiProjectRequests++;
        }

        String projectName = projects > 1 ? 'Multi-Project' : (data['projectName'] ?? 'Unknown');
        projectBreakdown[projectName] = (projectBreakdown[projectName] ?? 0) + 1;
      }

      return {
        'statusCounts': statusCounts,
        'totalHours': totalHours,
        'totalEmployees': totalEmployees,
        'multiProjectRequests': multiProjectRequests,
        'singleProjectRequests': statusCounts['total']! - multiProjectRequests,
        'projectBreakdown': projectBreakdown,
        'averageHoursPerRequest': statusCounts['total']! > 0 ? totalHours / statusCounts['total']! : 0,
        'averageEmployeesPerRequest': statusCounts['total']! > 0 ? totalEmployees / statusCounts['total']! : 0,
        'approvalRate': _calculateApprovalRate(statusCounts),
      };
    } catch (e) {
      debugPrint("Error getting request statistics: $e");
      return {
        'statusCounts': {'total': 0, 'pending': 0, 'approved': 0, 'rejected': 0, 'cancelled': 0},
        'totalHours': 0.0,
        'totalEmployees': 0,
        'multiProjectRequests': 0,
        'singleProjectRequests': 0,
        'projectBreakdown': {},
        'averageHoursPerRequest': 0.0,
        'averageEmployeesPerRequest': 0.0,
        'approvalRate': 0.0,
      };
    }
  }

  // ✅ HELPER: Calculate approval rate
  double _calculateApprovalRate(Map<String, int> statusCounts) {
    int approved = statusCounts['approved'] ?? 0;
    int rejected = statusCounts['rejected'] ?? 0;
    int total = approved + rejected;

    if (total == 0) return 0.0;
    return (approved / total) * 100;
  }

  // ✅ FIXED: Map Firestore data to OvertimeRequest object with correct constructor
  OvertimeRequest _mapToOvertimeRequest(String id, Map<String, dynamic> data) {
    // Handle projects (new multi-project format or legacy single project)
    List<OvertimeProjectEntry> projects = [];

    if (data['projects'] != null && data['projects'] is List) {
      // New multi-project format
      for (var projectData in data['projects']) {
        projects.add(OvertimeProjectEntry.fromMap(projectData));
      }
    } else {
      // Legacy single project format
      projects.add(OvertimeProjectEntry(
        projectName: data['projectName'] ?? '',
        projectCode: data['projectCode'] ?? '',
        startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        endTime: (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        employeeIds: List<String>.from(data['employeeIds'] ?? []),
      ));
    }

    return OvertimeRequest(
      id: id,
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
      totalDurationHours: (data['totalHours'] ?? 0).toDouble(),
      projects: projects,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      version: data['version'] ?? 1,
      isActive: data['isActive'] ?? true,
      metadata: data['metadata'],
    );
  }

  // ✅ FIXED: Map local database data to OvertimeRequest object
  OvertimeRequest _mapLocalToOvertimeRequest(Map<String, dynamic> map) {
    return OvertimeRequest(
      id: map['id'] ?? '',
      requesterId: map['requester_id'] ?? '',
      requesterName: map['requester_name'] ?? '',
      approverEmpId: map['approver_emp_id'] ?? '',
      approverName: map['approver_name'] ?? '',
      projectName: map['project_name'] ?? '',
      projectCode: map['project_code'] ?? '',
      startTime: DateTime.parse(map['start_time'] ?? DateTime.now().toIso8601String()),
      endTime: DateTime.parse(map['end_time'] ?? DateTime.now().toIso8601String()),
      employeeIds: (map['employee_ids'] as String?)?.split(',') ?? [],
      requestTime: DateTime.parse(map['request_time'] ?? DateTime.now().toIso8601String()),
      status: _parseStatus(map['status']),
      responseMessage: map['response_message'],
      responseTime: map['response_time'] != null ? DateTime.parse(map['response_time']) : null,
      totalProjects: map['total_projects'] ?? 1,
      totalEmployeeCount: map['total_employees'] ?? 0,
      totalDurationHours: (map['total_hours'] ?? 0).toDouble(),
      projects: [
        OvertimeProjectEntry(
          projectName: map['project_name'] ?? '',
          projectCode: map['project_code'] ?? '',
          startTime: DateTime.parse(map['start_time'] ?? DateTime.now().toIso8601String()),
          endTime: DateTime.parse(map['end_time'] ?? DateTime.now().toIso8601String()),
          employeeIds: (map['employee_ids'] as String?)?.split(',') ?? [],
        )
      ],
    );
  }

  // ✅ FIXED: Helper method to parse status string to enum
  OvertimeRequestStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
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

  // ✅ ENHANCED: Cache overtime request with correct properties
  Future<void> _cacheOvertimeRequest(OvertimeRequest request) async {
    try {
      final requestMap = {
        'id': request.id,
        'projectName': request.projectName,
        'projectCode': request.projectCode,
        'startTime': request.startTime.toIso8601String(),
        'endTime': request.endTime.toIso8601String(),
        'employeeIds': request.employeeIds,
        'requesterId': request.requesterId,
        'requesterName': request.requesterName,
        'approverEmpId': request.approverEmpId,
        'approverName': request.approverName,
        'requestTime': request.requestTime.toIso8601String(),
        'status': request.status.value,
        'responseMessage': request.responseMessage,
        'responseTime': request.responseTime?.toIso8601String(),
        'totalProjects': request.totalProjects,
        'totalEmployees': request.totalEmployeeCount,
        'totalHours': request.totalDurationHours,
      };

      final prefs = await SharedPreferences.getInstance();
      final cachedRequests = prefs.getStringList('cached_overtime_requests') ?? [];
      cachedRequests.add(jsonEncode(requestMap));
      await prefs.setStringList('cached_overtime_requests', cachedRequests);
      debugPrint("Cached overtime request: ${request.id}");
    } catch (e) {
      debugPrint("Error caching overtime request: $e");
    }
  }

  // ✅ ENHANCED: Send overtime notifications with multi-project support
  Future<void> _sendOvertimeNotifications({
    required String requestId,
    required String approverId,
    required String approverName,
    required String requesterId,
    required String requesterName,
    required String projectName,
    required String projectCode,
    required int employeeCount,
    int totalProjects = 1,
    double totalHours = 0,
  }) async {
    try {
      debugPrint("=== SENDING ENHANCED OVERTIME NOTIFICATIONS ===");
      debugPrint("Approver: $approverName ($approverId)");
      debugPrint("Requester: $requesterName ($requesterId)");
      debugPrint("Projects: $totalProjects, Hours: $totalHours");

      // Enhanced notification messages
      String approverTitle = totalProjects > 1
          ? "🔥 New Multi-Project Overtime Request"
          : "🔥 New Overtime Request";

      String approverBody = totalProjects > 1
          ? "$requesterName requested overtime for $employeeCount employees across $totalProjects projects (${totalHours.toStringAsFixed(1)}h total)"
          : "$requesterName requested overtime for $employeeCount employees in $projectName";

      String requesterTitle = totalProjects > 1
          ? "✅ Multi-Project Overtime Request Submitted"
          : "✅ Overtime Request Submitted";

      String requesterBody = totalProjects > 1
          ? "Your $totalProjects projects overtime request for $employeeCount employees has been submitted to $approverName for approval."
          : "Your overtime request for $employeeCount employees has been submitted to $approverName for approval.";

      // 1. Send notification to the approver
      await _sendNotificationToUser(
        userId: approverId,
        title: approverTitle,
        body: approverBody,
        data: {
          'type': 'overtime_request',
          'requestId': requestId,
          'requesterId': requesterId,
          'requesterName': requesterName,
          'projectName': projectName,
          'projectCode': projectCode,
          'employeeCount': employeeCount.toString(),
          'totalProjects': totalProjects.toString(),
          'totalHours': totalHours.toString(),
          'isMultiProject': (totalProjects > 1).toString(),
          'approverId': approverId,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );

      // 2. Send confirmation to the requester
      await _sendNotificationToUser(
        userId: requesterId,
        title: requesterTitle,
        body: requesterBody,
        data: {
          'type': 'overtime_request_submitted',
          'requestId': requestId,
          'projectName': projectName,
          'projectCode': projectCode,
          'employeeCount': employeeCount.toString(),
          'totalProjects': totalProjects.toString(),
          'totalHours': totalHours.toString(),
          'isMultiProject': (totalProjects > 1).toString(),
          'approverId': approverId,
          'approverName': approverName,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );

      debugPrint("Enhanced overtime notifications sent successfully");

    } catch (e) {
      debugPrint("Error sending overtime notifications: $e");
    }
  }

  // ✅ NEW: Send status update notification
  Future<void> _sendStatusUpdateNotification({
    required String requestId,
    required Map<String, dynamic> requestData,
    required OvertimeRequestStatus newStatus,
    String? responseMessage,
  }) async {
    try {
      String requesterId = requestData['requesterId'] ?? '';
      String projectName = requestData['projectName'] ?? '';
      int totalProjects = requestData['totalProjects'] ?? 1;
      double totalHours = (requestData['totalHours'] ?? 0).toDouble();
      List<String> employeeIds = List<String>.from(requestData['employeeIds'] ?? []);

      String title = totalProjects > 1
          ? (newStatus == OvertimeRequestStatus.approved
          ? "✅ Multi-Project Overtime Approved!"
          : "❌ Multi-Project Overtime Rejected")
          : (newStatus == OvertimeRequestStatus.approved
          ? "✅ Overtime Request Approved!"
          : "❌ Overtime Request Rejected");

      String body = totalProjects > 1
          ? (newStatus == OvertimeRequestStatus.approved
          ? "Your $totalProjects projects overtime request (${totalHours.toStringAsFixed(1)}h) has been approved."
          : "Your $totalProjects projects overtime request has been rejected.${responseMessage != null ? ' Message: $responseMessage' : ''}")
          : (newStatus == OvertimeRequestStatus.approved
          ? "Your overtime request for $projectName has been approved."
          : "Your overtime request for $projectName has been rejected.${responseMessage != null ? ' Message: $responseMessage' : ''}");

      await _sendNotificationToUser(
        userId: requesterId,
        title: title,
        body: body,
        data: {
          'type': 'overtime_request_update',
          'requestId': requestId,
          'projectName': projectName,
          'status': newStatus.value,
          'message': responseMessage ?? '',
          'totalProjects': totalProjects.toString(),
          'totalHours': totalHours.toString(),
          'isMultiProject': (totalProjects > 1).toString(),
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );

      // ✅ FIXED: If approved, notify each selected employee (correct for loop syntax)
      if (newStatus == OvertimeRequestStatus.approved && employeeIds.isNotEmpty) {
        String employeeTitle = totalProjects > 1
            ? "🎉 You're Approved for Multi-Project Overtime!"
            : "🎉 You're Approved for Overtime!";

        String employeeBody = totalProjects > 1
            ? "You have been approved for overtime work across $totalProjects projects (${totalHours.toStringAsFixed(1)}h total)."
            : "You have been approved for overtime work in $projectName.";

        // ✅ CORRECT: Use 'in' instead of 'of' for Dart for-loops
        for (String employeeId in employeeIds) {
          try {
            await _sendNotificationToUser(
              userId: employeeId,
              title: employeeTitle,
              body: employeeBody,
              data: {
                'type': 'overtime_approved',
                'requestId': requestId,
                'projectName': projectName,
                'totalProjects': totalProjects.toString(),
                'totalHours': totalHours.toString(),
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              },
            );
          } catch (e) {
            debugPrint("Error notifying employee $employeeId: $e");
          }
        }
      }

    } catch (e) {
      debugPrint("Error sending status update notification: $e");
    }
  }

  // ✅ ENHANCED: Send notification to user with multiple strategies
  Future<void> _sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      debugPrint("Sending notification to user: $userId");

      // Method 1: Direct FCM token lookup and send
      bool directSuccess = await _sendDirectFCMNotification(userId, title, body, data);

      // Method 2: Topic-based notification for redundancy
      await _sendTopicNotification(userId, title, body, data);

      // Method 3: Firestore notification document (for app to poll if needed)
      await _createFirestoreNotification(userId, title, body, data);

      debugPrint("Notification sent to $userId via multiple methods. Direct FCM: ${directSuccess ? 'Success' : 'Failed'}");

    } catch (e) {
      debugPrint("Error in _sendNotificationToUser for $userId: $e");
    }
  }

  // ✅ ENHANCED: Direct FCM notification with better token handling
  Future<bool> _sendDirectFCMNotification(
      String userId,
      String title,
      String body,
      Map<String, dynamic> data,
      ) async {
    try {
      // Try multiple user ID formats
      List<String> userIdVariants = [
        userId,
        userId.startsWith('EMP') ? userId.substring(3) : 'EMP$userId',
      ];

      for (String id in userIdVariants) {
        try {
          DocumentSnapshot tokenDoc = await _firestore
              .collection('fcm_tokens')
              .doc(id)
              .get();

          if (tokenDoc.exists) {
            Map<String, dynamic> tokenData = tokenDoc.data() as Map<String, dynamic>;
            String? token = tokenData['token'];

            if (token != null && token.isNotEmpty) {
              debugPrint("Found FCM token for $id: ${token.substring(0, 15)}...");

              // Create the message payload for Cloud Messaging
              await _firestore.collection('fcm_messages').add({
                'token': token,
                'notification': {
                  'title': title,
                  'body': body,
                },
                'data': data,
                'android': {
                  'priority': 'high',
                  'notification': {
                    'sound': 'default',
                    'priority': 'high',
                    'channel_id': 'overtime_requests_channel',
                  }
                },
                'apns': {
                  'payload': {
                    'aps': {
                      'sound': 'default',
                      'badge': 1,
                      'content_available': true,
                      'interruption_level': 'time_sensitive',
                    }
                  }
                },
                'timestamp': FieldValue.serverTimestamp(),
                'processed': false,
                'targetUserId': id,
              });

              debugPrint("FCM message queued for $id");
              return true;
            }
          }
        } catch (e) {
          debugPrint("Error checking token for $id: $e");
          continue;
        }
      }

      return false;
    } catch (e) {
      debugPrint("Error in direct FCM notification: $e");
      return false;
    }
  }

  // ✅ Topic-based notification fallback
  Future<void> _sendTopicNotification(
      String userId,
      String title,
      String body,
      Map<String, dynamic> data,
      ) async {
    try {
      // Subscribe the user to their topic if not already subscribed
      await _notificationService.subscribeToEmployeeTopic(userId);

      // Send to user-specific topics
      List<String> topics = [
        'employee_$userId',
        userId.startsWith('EMP') ? 'employee_${userId.substring(3)}' : 'employee_EMP$userId',
        'overtime_approver_$userId',
        'overtime_requests', // General overtime topic
      ];

      for (String topic in topics) {
        await _firestore.collection('topic_messages').add({
          'topic': topic,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': data,
          'timestamp': FieldValue.serverTimestamp(),
          'processed': false,
          'targetUserId': userId,
        });
      }

      debugPrint("Topic notifications queued for $userId");
    } catch (e) {
      debugPrint("Error sending topic notification: $e");
    }
  }

  // ✅ Firestore notification document creation
  Future<void> _createFirestoreNotification(
      String userId,
      String title,
      String body,
      Map<String, dynamic> data,
      ) async {
    try {
      await _firestore.collection('user_notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'overtime_notification',
      });

      debugPrint("Firestore notification created for $userId");
    } catch (e) {
      debugPrint("Error creating Firestore notification: $e");
    }
  }

  // ✅ Setup overtime approver
  Future<void> setupOvertimeApprover(String employeeId) async {
    try {
      debugPrint("=== SETTING UP OVERTIME APPROVER: $employeeId ===");

      // 1. Register FCM token specifically for this user
      await _notificationService.updateTokenForUser(employeeId);

      // 2. Subscribe to overtime-related topics
      await _notificationService.subscribeToTopic('overtime_requests');
      await _notificationService.subscribeToTopic('overtime_approver_$employeeId');

      // Try alternative ID format too
      String altId = employeeId.startsWith('EMP') ? employeeId.substring(3) : 'EMP$employeeId';
      await _notificationService.subscribeToTopic('overtime_approver_$altId');

      // 3. Mark as overtime approver in Firestore
      await _firestore.collection('overtime_approvers').doc(employeeId).set({
        'approverId': employeeId,
        'approverName': 'Overtime Approver',
        'isActive': true,
        'setupAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4. Also update employee record
      await _firestore.collection('employees').doc(employeeId).update({
        'hasOvertimeApprovalAccess': true,
        'overtimeApproverSetupAt': FieldValue.serverTimestamp(),
      });

      debugPrint("Overtime approver setup completed for $employeeId");

    } catch (e) {
      debugPrint("Error setting up overtime approver: $e");
    }
  }

  // ✅ Delete a request (admin only)
  Future<bool> deleteRequest(String requestId) async {
    try {
      await _firestore.collection('overtime_requests').doc(requestId).update({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
      });
      debugPrint("Request marked as deleted: $requestId");
      return true;
    } catch (e) {
      debugPrint("Error deleting request: $e");
      return false;
    }
  }

  // ✅ Get requests for a specific date range
  Future<List<OvertimeRequest>> getRequestsForDateRange(
      DateTime startDate,
      DateTime endDate,
      ) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('overtime_requests')
          .where('requestTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('requestTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('requestTime', descending: true)
          .get();


      List<OvertimeRequest> requests = [];
      for (var doc in snapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          requests.add(_mapToOvertimeRequest(doc.id, data));
        } catch (e) {
          debugPrint("Error parsing request ${doc.id}: $e");
        }
      }

      return requests;
    } catch (e) {
      debugPrint("Error getting requests for date range: $e");
      return [];
    }
  }
}