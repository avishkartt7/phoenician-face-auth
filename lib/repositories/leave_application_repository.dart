// lib/repositories/leave_application_repository.dart

import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:phoenician_face_auth/model/leave_application_model.dart';
import 'package:phoenician_face_auth/model/leave_balance_model.dart';
import 'package:phoenician_face_auth/services/database_helper.dart';
import 'package:phoenician_face_auth/services/connectivity_service.dart';

class LeaveApplicationRepository {
  final DatabaseHelper _dbHelper;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ConnectivityService _connectivityService;

  LeaveApplicationRepository({
    required DatabaseHelper dbHelper,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    required ConnectivityService connectivityService,
  }) : _dbHelper = dbHelper,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _connectivityService = connectivityService;

  // ============================================================================
  // LEAVE APPLICATION METHODS
  // ============================================================================

  /// Submit a new leave application
  Future<String?> submitLeaveApplication(LeaveApplicationModel application) async {
    try {
      debugPrint("Saving leave application for ${application.employeeName}");

      // Generate ID if not provided
      final applicationId = application.id ?? _generateApplicationId();
      final applicationWithId = application.copyWith(id: applicationId);

      // Save to local database first
      await _saveApplicationLocally(applicationWithId);

      // Try to sync to Firestore if online
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        try {
          await _syncApplicationToFirestore(applicationWithId);
        } catch (e) {
          debugPrint("Failed to sync to Firestore, will sync later: $e");
        }
      }

      debugPrint("Leave application saved successfully with ID: $applicationId");
      return applicationId;
    } catch (e) {
      debugPrint("Error submitting leave application: $e");
      return null;
    }
  }

  /// Get line manager information from mastersheet
  Future<Map<String, String>?> getLineManagerInfo(String employeePin) async {
    try {
      // First try MasterSheet to get the lineManagerId
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        final snapshot = await _firestore
            .collection('MasterSheet')
            .doc('Employee-Data')
            .collection('employees')
            .where('employeeNumber', isEqualTo: employeePin)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          final lineManagerIdFromMaster = data['lineManagerId']; // Gets "EMP1270"
          final lineManagerNameFromMaster = data['lineManagerName']; // Gets "Marwa Omar Mrad"

          if (lineManagerIdFromMaster != null) {
            // Extract PIN from "EMP1270" -> "1270"
            String managerPin = lineManagerIdFromMaster.toString().replaceAll('EMP', '');

            // Find the actual manager document by PIN
            final managerSnapshot = await _firestore
                .collection('employees')
                .where('pin', isEqualTo: managerPin)
                .limit(1)
                .get();

            if (managerSnapshot.docs.isNotEmpty) {
              final managerDocId = managerSnapshot.docs.first.id;
              final managerData = managerSnapshot.docs.first.data();

              debugPrint("Found manager: PIN=$managerPin, DocID=$managerDocId, Name=${managerData['name']}");

              return {
                'lineManagerId': managerDocId, // Use actual document ID
                'lineManagerName': managerData['name'] ?? lineManagerNameFromMaster,
              };
            } else {
              debugPrint("Manager not found in employees collection with PIN: $managerPin");
            }
          }
        }
      }

      debugPrint("Fallback: Could not find line manager info for employee PIN: $employeePin");
      return null;
    } catch (e) {
      debugPrint("Error getting line manager info: $e");
      return null;
    }
  }

  /// Get leave applications for a specific employee
  Future<List<LeaveApplicationModel>> getLeaveApplicationsForEmployee(
      String employeeId, {
        LeaveStatus? status,
        int limit = 20,
      }) async {
    try {
      // Try to sync from Firestore first if online
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        await _syncEmployeeApplicationsFromFirestore(employeeId);
      }

      // Build where clause
      String whereClause = 'is_active = 1';
      List<dynamic> whereArgs = [];

      if (employeeId.isNotEmpty) {
        whereClause += ' AND employee_id = ?';
        whereArgs.add(employeeId);
      }

      if (status != null) {
        whereClause += ' AND status = ?';
        whereArgs.add(status.name);
      }

      // Get from local database
      final applications = await _dbHelper.query(
        'leave_applications',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'application_date DESC',
        limit: limit,
      );

      return applications.map((map) => LeaveApplicationModel.fromMap(map)).toList();
    } catch (e) {
      debugPrint("Error getting employee leave applications: $e");
      return [];
    }
  }

  /// Get pending applications for manager approval
  Future<List<LeaveApplicationModel>> getPendingApplicationsForManager(String managerId) async {
    try {
      // Try to sync from Firestore first if online
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        await _syncManagerApplicationsFromFirestore(managerId);
      }

      // Get from local database
      final applications = await _dbHelper.query(
        'leave_applications',
        where: 'line_manager_id = ? AND status = ? AND is_active = 1',
        whereArgs: [managerId, 'pending'],
        orderBy: 'application_date ASC',
      );

      return applications.map((map) => LeaveApplicationModel.fromMap(map)).toList();
    } catch (e) {
      debugPrint("Error getting pending applications for manager: $e");
      return [];
    }
  }

  /// Update application status (approve/reject/cancel)
  Future<bool> updateApplicationStatus(
      String applicationId,
      LeaveStatus status, {
        String? comments,
        String? reviewedBy,
      }) async {
    try {
      final updates = {
        'status': status.name,
        'review_date': DateTime.now().toIso8601String(),
        'review_comments': comments,
        'reviewed_by': reviewedBy,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Update local database
      final rowsUpdated = await _dbHelper.update(
        'leave_applications',
        updates,
        where: 'id = ?',
        whereArgs: [applicationId],
      );

      // Sync to Firestore if online
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        try {
          await _firestore
              .collection('leave_applications')
              .doc(applicationId)
              .update({
            'status': status.name,
            'reviewDate': FieldValue.serverTimestamp(),
            'reviewComments': comments,
            'reviewedBy': reviewedBy,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint("Failed to sync status update to Firestore: $e");
        }
      }

      return rowsUpdated > 0;
    } catch (e) {
      debugPrint("Error updating application status: $e");
      return false;
    }
  }

  /// Cancel leave application
  Future<bool> cancelLeaveApplication(String applicationId) async {
    try {
      return await updateApplicationStatus(applicationId, LeaveStatus.cancelled);
    } catch (e) {
      debugPrint("Error cancelling leave application: $e");
      return false;
    }
  }

  // ============================================================================
  // LEAVE BALANCE METHODS
  // ============================================================================

  /// Get leave balance for an employee
  Future<LeaveBalance?> getLeaveBalance(String employeeId, {int? year}) async {
    try {
      final targetYear = year ?? DateTime.now().year;

      // Try to sync from Firestore first if online
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        await _syncLeaveBalanceFromFirestore(employeeId, targetYear);
      }

      // Get from local database
      final balanceRecords = await _dbHelper.query(
        'leave_balances',
        where: 'employee_id = ? AND year = ?',
        whereArgs: [employeeId, targetYear],
      );

      if (balanceRecords.isNotEmpty) {
        return _parseLeaveBalanceFromMap(balanceRecords.first);
      }

      // Create default balance if none exists
      final defaultBalance = LeaveBalance.createDefault(employeeId, year: targetYear);
      await _saveLeaveBalanceLocally(defaultBalance);

      return defaultBalance;
    } catch (e) {
      debugPrint("Error getting leave balance: $e");
      return null;
    }
  }

  /// Update leave balance (add/remove days) - ENHANCED
  Future<bool> updateLeaveBalance(
      String employeeId,
      String leaveType,
      int days, {
        required bool isApproval, // true for approval (pending -> used), false for application (add pending)
      }) async {
    try {
      final balance = await getLeaveBalance(employeeId);
      if (balance == null) return false;

      LeaveBalance updatedBalance;

      if (isApproval) {
        // Move from pending to used (when leave is approved)
        updatedBalance = balance.approveLeave(leaveType, days);
      } else {
        // Add to pending (when leave is applied)
        updatedBalance = balance.addPendingDays(leaveType, days);
      }

      return await _updateLeaveBalanceRecord(updatedBalance);
    } catch (e) {
      debugPrint("Error updating leave balance: $e");
      return false;
    }
  }

  /// Remove pending days from balance (for rejection/cancellation) - NEW METHOD
  Future<bool> removePendingDaysFromBalance(
      String employeeId,
      String leaveType,
      int days,
      ) async {
    try {
      final balance = await getLeaveBalance(employeeId);
      if (balance == null) return false;

      // Remove from pending days (reset the balance)
      final updatedBalance = balance.removePendingDays(leaveType, days);

      return await _updateLeaveBalanceRecord(updatedBalance);
    } catch (e) {
      debugPrint("Error removing pending days from balance: $e");
      return false;
    }
  }

  /// Update leave balance record
  Future<bool> _updateLeaveBalanceRecord(LeaveBalance balance) async {
    try {
      // Save to local database
      await _saveLeaveBalanceLocally(balance);

      // Sync to Firestore if online
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        try {
          await _firestore
              .collection('leave_balances')
              .doc('${balance.employeeId}_${balance.year}')
              .set(balance.toMap());
        } catch (e) {
          debugPrint("Failed to sync balance to Firestore: $e");
        }
      }

      return true;
    } catch (e) {
      debugPrint("Error updating leave balance record: $e");
      return false;
    }
  }

  // ============================================================================
  // SYNC METHODS
  // ============================================================================

  /// Sync pending applications to Firestore
  Future<void> syncPendingApplications() async {
    try {
      if (_connectivityService.currentStatus != ConnectionStatus.online) {
        return;
      }

      final unsyncedApplications = await _dbHelper.query(
        'leave_applications',
        where: 'is_synced = 0',
        orderBy: 'created_at ASC',
      );

      debugPrint("Syncing ${unsyncedApplications.length} pending applications");

      for (final applicationMap in unsyncedApplications) {
        try {
          final application = LeaveApplicationModel.fromMap(applicationMap);
          await _syncApplicationToFirestore(application);

          // Mark as synced
          await _dbHelper.update(
            'leave_applications',
            {'is_synced': 1},
            where: 'id = ?',
            whereArgs: [application.id],
          );
        } catch (e) {
          debugPrint("Failed to sync application ${applicationMap['id']}: $e");
        }
      }

      debugPrint("Sync completed successfully");
    } catch (e) {
      debugPrint("Error syncing applications: $e");
    }
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  /// Save application to local database
  Future<void> _saveApplicationLocally(LeaveApplicationModel application) async {
    try {
      await _dbHelper.insert(
        'leave_applications',
        application.toLocalMap(),
      );
    } catch (e) {
      debugPrint("Error saving application locally: $e");
      rethrow;
    }
  }

  /// Sync application to Firestore
  Future<void> _syncApplicationToFirestore(LeaveApplicationModel application) async {
    try {
      await _firestore
          .collection('leave_applications')
          .doc(application.id)
          .set(application.toMap());

      debugPrint("Application synced to Firestore: ${application.id}");
    } catch (e) {
      debugPrint("Error syncing application to Firestore: $e");
      rethrow;
    }
  }

  /// Sync employee applications from Firestore
  Future<void> _syncEmployeeApplicationsFromFirestore(String employeeId) async {
    try {
      final snapshot = await _firestore
          .collection('leave_applications')
          .where('employeeId', isEqualTo: employeeId)
          .where('isActive', isEqualTo: true)
          .orderBy('applicationDate', descending: true)
          .get();

      for (final doc in snapshot.docs) {
        final application = LeaveApplicationModel.fromFirestore(doc);
        await _saveApplicationLocally(application.copyWith(isSynced: true));
      }

      debugPrint("Synced ${snapshot.docs.length} applications for employee: $employeeId");
    } catch (e) {
      debugPrint("Error syncing employee applications from Firestore: $e");
    }
  }

  /// Sync manager applications from Firestore
  Future<void> _syncManagerApplicationsFromFirestore(String managerId) async {
    try {
      final snapshot = await _firestore
          .collection('leave_applications')
          .where('lineManagerId', isEqualTo: managerId)
          .where('status', isEqualTo: 'pending')
          .where('isActive', isEqualTo: true)
          .orderBy('applicationDate', descending: false)
          .get();

      for (final doc in snapshot.docs) {
        final application = LeaveApplicationModel.fromFirestore(doc);
        await _saveApplicationLocally(application.copyWith(isSynced: true));
      }

      debugPrint("Synced ${snapshot.docs.length} pending applications for manager: $managerId");
    } catch (e) {
      debugPrint("Error syncing manager applications from Firestore: $e");
    }
  }

  /// Save leave balance to local database
  Future<void> _saveLeaveBalanceLocally(LeaveBalance balance) async {
    try {
      await _dbHelper.insert(
        'leave_balances',
        {
          'id': '${balance.employeeId}_${balance.year}',
          'employee_id': balance.employeeId,
          'year': balance.year,
          'total_days': _encodeMapToJson(balance.totalDays),
          'used_days': _encodeMapToJson(balance.usedDays),
          'pending_days': _encodeMapToJson(balance.pendingDays),
          'last_updated': balance.lastUpdated?.toIso8601String(),
          'is_synced': 1,
        },
      );
    } catch (e) {
      debugPrint("Error saving leave balance locally: $e");
      rethrow;
    }
  }

  /// Sync leave balance from Firestore
  Future<void> _syncLeaveBalanceFromFirestore(String employeeId, int year) async {
    try {
      final doc = await _firestore
          .collection('leave_balances')
          .doc('${employeeId}_$year')
          .get();

      if (doc.exists) {
        final balance = LeaveBalance.fromFirestore(doc);
        await _saveLeaveBalanceLocally(balance);
        debugPrint("Synced leave balance for employee: $employeeId, year: $year");
      }
    } catch (e) {
      debugPrint("Error syncing leave balance from Firestore: $e");
    }
  }

  /// Generate unique application ID
  String _generateApplicationId() {
    return 'LA_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Parse leave balance from database map
  LeaveBalance _parseLeaveBalanceFromMap(Map<String, dynamic> map) {
    return LeaveBalance(
      employeeId: map['employee_id'],
      year: map['year'],
      totalDays: _decodeJsonToMap(map['total_days']),
      usedDays: _decodeJsonToMap(map['used_days']),
      pendingDays: _decodeJsonToMap(map['pending_days']),
      lastUpdated: map['last_updated'] != null
          ? DateTime.parse(map['last_updated'])
          : null,
    );
  }

  /// Encode map to JSON string for database storage
  String _encodeMapToJson(Map<String, int> map) {
    final buffer = StringBuffer('{');
    final entries = map.entries.toList();

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      buffer.write('"${entry.key}":${entry.value}');
      if (i < entries.length - 1) {
        buffer.write(',');
      }
    }

    buffer.write('}');
    return buffer.toString();
  }

  /// Decode JSON string to map from database
  Map<String, int> _decodeJsonToMap(String jsonString) {
    try {
      final map = <String, int>{};

      if (jsonString.isEmpty || jsonString == '{}') {
        return map;
      }

      // Remove the outer braces
      final content = jsonString.substring(1, jsonString.length - 1);

      if (content.isEmpty) return map;

      // Split by comma and parse each key-value pair
      final pairs = content.split(',');
      for (final pair in pairs) {
        final keyValue = pair.split(':');
        if (keyValue.length == 2) {
          final key = keyValue[0].trim().replaceAll('"', '');
          final value = int.tryParse(keyValue[1].trim()) ?? 0;
          map[key] = value;
        }
      }

      return map;
    } catch (e) {
      debugPrint("Error decoding JSON to map: $e");
      // Return default leave types with updated values
      return {
        'annual': 0,
        'sick': 0,
        'maternity': 0,
        'paternity': 0,
        'emergency': 0,
        'compensate': 0,
        'unpaid': 0,
      };
    }
  }
}