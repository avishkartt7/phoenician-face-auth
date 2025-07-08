// lib/services/overtime_approver_service.dart
// Simplified version - only uses employees collection

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class OvertimeApproverService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current active overtime approver - SIMPLIFIED to only check employees collection
  static Future<Map<String, dynamic>?> getCurrentApprover() async {
    try {
      debugPrint("=== GETTING CURRENT OVERTIME APPROVER (SIMPLIFIED) ===");

      // ONLY Method: Check employees collection for hasOvertimeApprovalAccess
      debugPrint("Checking employees collection for approval access...");
      QuerySnapshot employeesSnapshot = await _firestore
          .collection('employees')
          .where('hasOvertimeApprovalAccess', isEqualTo: true)
          .limit(1)
          .get();

      if (employeesSnapshot.docs.isNotEmpty) {
        var doc = employeesSnapshot.docs.first;
        var data = doc.data() as Map<String, dynamic>;

        debugPrint("✅ Found approver in employees collection: ${doc.id}");
        debugPrint("Approver name: ${data['name'] ?? data['employeeName']}");
        return {
          'approverId': doc.id,
          'approverName': data['name'] ?? data['employeeName'] ?? 'Overtime Approver',
          'source': 'employees_collection',
          'docId': doc.id,
        };
      }

      // If no approver found, return EMP1289 as default
      debugPrint("⚠️ No approver found, using EMP1289 as fallback");
      DocumentSnapshot fallbackDoc = await _firestore
          .collection('employees')
          .doc('EMP1289')
          .get();

      if (fallbackDoc.exists) {
        var data = fallbackDoc.data() as Map<String, dynamic>;

        // Also set this user as approver for future
        await _firestore.collection('employees').doc('EMP1289').update({
          'hasOvertimeApprovalAccess': true,
          'overtimeApproverSetAt': FieldValue.serverTimestamp(),
        });

        return {
          'approverId': 'EMP1289',
          'approverName': data['name'] ?? data['employeeName'] ?? 'Default Approver',
          'source': 'fallback_set_as_approver',
          'docId': 'EMP1289',
        };
      }

      debugPrint("❌ No approver found and fallback failed!");
      return null;

    } catch (e) {
      debugPrint("Error getting current approver: $e");
      return null;
    }
  }

  // Set up an employee as overtime approver - SIMPLIFIED
  static Future<bool> setupApprover({
    required String employeeId,
    required String employeeName,
  }) async {
    try {
      debugPrint("Setting up $employeeId as overtime approver (SIMPLIFIED)");

      // Remove approval access from all other employees first
      QuerySnapshot allApprovers = await _firestore
          .collection('employees')
          .where('hasOvertimeApprovalAccess', isEqualTo: true)
          .get();

      for (var doc in allApprovers.docs) {
        if (doc.id != employeeId) {
          await doc.reference.update({
            'hasOvertimeApprovalAccess': false,
            'overtimeApproverRemovedAt': FieldValue.serverTimestamp(),
          });
          debugPrint("Removed approval access from: ${doc.id}");
        }
      }

      // Set new approver
      await _firestore.collection('employees').doc(employeeId).update({
        'hasOvertimeApprovalAccess': true,
        'overtimeApproverSetAt': FieldValue.serverTimestamp(),
        'overtimeApproverSetBy': 'system',
      });

      debugPrint("✅ Successfully set up $employeeId as overtime approver");
      return true;
    } catch (e) {
      debugPrint("Error setting up approver: $e");
      return false;
    }
  }

  // Check if a specific employee is an approver - SIMPLIFIED
  static Future<bool> isApprover(String employeeId) async {
    try {
      debugPrint("Checking if $employeeId is approver...");

      DocumentSnapshot empDoc = await _firestore
          .collection('employees')
          .doc(employeeId)
          .get();

      if (empDoc.exists) {
        var data = empDoc.data() as Map<String, dynamic>;
        bool isApprover = data['hasOvertimeApprovalAccess'] == true;
        debugPrint("$employeeId approver status: $isApprover");
        return isApprover;
      }

      debugPrint("$employeeId document not found");
      return false;
    } catch (e) {
      debugPrint("Error checking if $employeeId is approver: $e");
      return false;
    }
  }

  // Get all current approvers - SIMPLIFIED
  static Future<List<Map<String, dynamic>>> getAllApprovers() async {
    try {
      List<Map<String, dynamic>> approvers = [];

      QuerySnapshot employeesSnapshot = await _firestore
          .collection('employees')
          .where('hasOvertimeApprovalAccess', isEqualTo: true)
          .get();

      for (var doc in employeesSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        approvers.add({
          'approverId': doc.id,
          'approverName': data['name'] ?? data['employeeName'] ?? 'Unknown',
          'source': 'employees_collection',
          'docId': doc.id,
        });
      }

      debugPrint("Found ${approvers.length} approvers total");
      return approvers;
    } catch (e) {
      debugPrint("Error getting all approvers: $e");
      return [];
    }
  }
}