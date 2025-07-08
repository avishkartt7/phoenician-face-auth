// lib/utils/overtime_setup_utility.dart - Complete Setup Utility

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:phoenician_face_auth/services/service_locator.dart';
import 'package:phoenician_face_auth/services/notification_service.dart';
import 'package:phoenician_face_auth/services/fcm_token_service.dart';
import 'package:phoenician_face_auth/common/utils/custom_snackbar.dart';

class OvertimeSetupUtility {
  static Future<bool> setupOvertimeApproverSystem(BuildContext context, String employeeId) async {
    if (employeeId != 'EMP1289') {
      CustomSnackBar.errorSnackBar(context, "Only EMP1289 can run this setup");
      return false;
    }

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text("Setting up Overtime System"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Please wait while we configure your overtime approver settings..."),
          ],
        ),
      ),
    );

    try {
      List<String> setupSteps = [];
      bool allSuccess = true;

      // Step 1: Register multiple FCM token formats
      print("=== STEP 1: FCM TOKEN REGISTRATION ===");
      try {
        final fcmTokenService = getIt<FcmTokenService>();

        // Register with all possible formats
        await fcmTokenService.registerTokenForUser('EMP1289');
        await fcmTokenService.registerTokenForUser('1289');

        // Force refresh to ensure latest token
        await fcmTokenService.forceTokenRefresh('EMP1289');

        setupSteps.add("✅ FCM Token registered successfully");
        print("✅ FCM Token registration complete");
      } catch (e) {
        setupSteps.add("❌ FCM Token registration failed: $e");
        allSuccess = false;
        print("❌ FCM Token registration failed: $e");
      }

      // Step 2: Subscribe to all overtime topics
      print("=== STEP 2: TOPIC SUBSCRIPTIONS ===");
      try {
        final notificationService = getIt<NotificationService>();

        // Subscribe to all relevant topics
        await notificationService.subscribeToTopic('overtime_approver_EMP1289');
        await notificationService.subscribeToTopic('overtime_approver_1289');
        await notificationService.subscribeToTopic('overtime_requests');
        await notificationService.subscribeToTopic('all_overtime_approvers');

        setupSteps.add("✅ Subscribed to all overtime topics");
        print("✅ Topic subscriptions complete");
      } catch (e) {
        setupSteps.add("❌ Topic subscription failed: $e");
        allSuccess = false;
        print("❌ Topic subscription failed: $e");
      }

      // Step 3: Verify token in Firestore
      print("=== STEP 3: TOKEN VERIFICATION ===");
      try {
        // Check main token
        final tokenDoc = await FirebaseFirestore.instance
            .collection('fcm_tokens')
            .doc('EMP1289')
            .get();

        if (tokenDoc.exists && tokenDoc.data()?['token'] != null) {
          setupSteps.add("✅ FCM token verified in Firestore");
          print("✅ Token verified: ${tokenDoc.data()}");
        } else {
          setupSteps.add("❌ FCM token not found in Firestore");
          allSuccess = false;
          print("❌ Token not found in Firestore");
        }
      } catch (e) {
        setupSteps.add("❌ Token verification failed: $e");
        allSuccess = false;
        print("❌ Token verification error: $e");
      }

      // Step 4: Test notification delivery
      print("=== STEP 4: TEST NOTIFICATION ===");
      try {
        final callable = FirebaseFunctions.instance.httpsCallable('sendTestOvertimeNotificationToApprover');

        final result = await callable.call();

        if (result.data['success'] == true) {
          setupSteps.add("✅ Test notification sent successfully");
          print("✅ Test notification successful");
        } else {
          setupSteps.add("❌ Test notification failed");
          allSuccess = false;
          print("❌ Test notification failed");
        }
      } catch (e) {
        setupSteps.add("❌ Test notification error: $e");
        allSuccess = false;
        print("❌ Test notification error: $e");
      }

      // Step 5: Verify database access
      print("=== STEP 5: DATABASE ACCESS VERIFICATION ===");
      try {
        final testQuery = await FirebaseFirestore.instance
            .collection('overtime_requests')
            .where('approverEmpId', isEqualTo: 'EMP1289')
            .limit(1)
            .get();

        setupSteps.add("✅ Database access verified");
        print("✅ Database access verified");
      } catch (e) {
        setupSteps.add("❌ Database access failed: $e");
        allSuccess = false;
        print("❌ Database access error: $e");
      }

      // Close loading dialog
      Navigator.of(context).pop();

      // Show results dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(
                allSuccess ? Icons.check_circle : Icons.warning,
                color: allSuccess ? Colors.green : Colors.orange,
              ),
              SizedBox(width: 8),
              Text(
                allSuccess ? "Setup Complete!" : "Setup Issues Found",
                style: TextStyle(
                  color: allSuccess ? Colors.green : Colors.orange,
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
                Text(
                  "Setup Results:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                ...setupSteps.map((step) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text(step),
                )),
                if (allSuccess) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "🎉 Your overtime approval system is now ready!\n\n"
                          "You will receive notifications when employees submit overtime requests.",
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                  ),
                ] else ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "⚠️ Some issues were found. Please contact IT support or try running the setup again.",
                      style: TextStyle(color: Colors.orange.shade700),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text("Close"),
            ),
            if (!allSuccess)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setupOvertimeApproverSystem(context, employeeId);
                },
                child: Text("Try Again"),
              ),
          ],
        ),
      );

      return allSuccess;

    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("Setup Error"),
          content: Text("Critical error during setup: $e"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text("OK"),
            ),
          ],
        ),
      );

      return false;
    }
  }

  // Quick diagnostic function
  static Future<void> runDiagnostics(BuildContext context, String employeeId) async {
    if (employeeId != 'EMP1289') return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Overtime System Diagnostics"),
        content: FutureBuilder<Map<String, dynamic>>(
          future: _getDiagnosticInfo(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Running diagnostics..."),
                ],
              );
            }

            if (snapshot.hasError) {
              return Text("Error: ${snapshot.error}");
            }

            final data = snapshot.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDiagnosticRow("FCM Token Registered", data['hasToken']),
                _buildDiagnosticRow("Database Access", data['dbAccess']),
                _buildDiagnosticRow("Pending Requests", "${data['pendingCount']}"),
                _buildDiagnosticRow("Last Setup", data['lastSetup'] ?? 'Never'),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  static Widget _buildDiagnosticRow(String label, dynamic value) {
    bool isStatus = value is bool;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (isStatus)
            Icon(
              value ? Icons.check_circle : Icons.error,
              color: value ? Colors.green : Colors.red,
              size: 16,
            ),
          if (isStatus) SizedBox(width: 8),
          Text("$label: "),
          Text(
            isStatus ? (value ? 'OK' : 'Failed') : value.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isStatus ? (value ? Colors.green : Colors.red) : null,
            ),
          ),
        ],
      ),
    );
  }

  static Future<Map<String, dynamic>> _getDiagnosticInfo() async {
    try {
      // Check token
      final tokenDoc = await FirebaseFirestore.instance
          .collection('fcm_tokens')
          .doc('EMP1289')
          .get();

      // Check database access
      final testQuery = await FirebaseFirestore.instance
          .collection('overtime_requests')
          .where('approverEmpId', isEqualTo: 'EMP1289')
          .where('status', isEqualTo: 'pending')
          .get();

      return {
        'hasToken': tokenDoc.exists && tokenDoc.data()?['token'] != null,
        'dbAccess': true,
        'pendingCount': testQuery.docs.length,
        'lastSetup': tokenDoc.data()?['updatedAt']?.toDate()?.toString() ?? 'Unknown',
      };
    } catch (e) {
      return {
        'hasToken': false,
        'dbAccess': false,
        'pendingCount': 'Error',
        'lastSetup': 'Error',
      };
    }
  }
}