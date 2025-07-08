// lib/admin/notification_admin_view.dart

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phoenician_face_auth/constants/theme.dart';
import 'package:phoenician_face_auth/common/utils/custom_snackbar.dart';
import 'package:phoenician_face_auth/services/fcm_token_service.dart';
import 'package:phoenician_face_auth/services/notification_service.dart';
import 'package:phoenician_face_auth/services/service_locator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationAdminView extends StatefulWidget {
  final String userId;

  const NotificationAdminView({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  _NotificationAdminViewState createState() => _NotificationAdminViewState();
}

class _NotificationAdminViewState extends State<NotificationAdminView> {
  bool _isLoading = false;
  String _currentToken = '';
  Map<String, dynamic>? _diagnosticResults;
  List<Map<String, dynamic>> _recentErrors = [];
  List<Map<String, dynamic>> _approverDocuments = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load current FCM token
      final prefs = await SharedPreferences.getInstance();
      _currentToken = prefs.getString('fcm_token') ?? 'Not found';

      // Load recent notification errors
      final errorsSnapshot = await FirebaseFirestore.instance
          .collection('notification_errors')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      _recentErrors = errorsSnapshot.docs
          .map((doc) => {
        'id': doc.id,
        ...doc.data(),
        'timestamp': doc.data()['timestamp'] != null
            ? (doc.data()['timestamp'] as Timestamp).toDate().toString()
            : 'Unknown',
      })
          .toList();

      // Load approver documents
      final approversSnapshot = await FirebaseFirestore.instance
          .collection('overtime_approvers')
          .get();

      _approverDocuments = approversSnapshot.docs
          .map((doc) => {
        'id': doc.id,
        ...doc.data(),
        'setupAt': doc.data()['setupAt'] != null
            ? (doc.data()['setupAt'] as Timestamp).toDate().toString()
            : 'Unknown',
      })
          .toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading admin data: $e');
      setState(() {
        _isLoading = false;
      });
      CustomSnackBar.errorSnackBar('Error loading data: $e');
    }
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Call diagnostic Cloud Function
      final callable = FirebaseFunctions.instance
          .httpsCallable('debugFCMTokenRegistration');
      final result = await callable.call({
        'userId': widget.userId,
      });

      setState(() {
        _diagnosticResults = Map<String, dynamic>.from(result.data);
        _isLoading = false;
      });

      if (_diagnosticResults!['success'] == true) {
        CustomSnackBar.successSnackBar('Diagnostics completed successfully');
      } else {
        CustomSnackBar.errorSnackBar(
            'Diagnostics failed: ${_diagnosticResults!['error']}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      CustomSnackBar.errorSnackBar('Error running diagnostics: $e');
    }
  }

  Future<void> _fixOvertimeApproverIds() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Call fix Cloud Function
      final callable =
      FirebaseFunctions.instance.httpsCallable('fixOvertimeApproverIds');
      final result = await callable.call({});

      if (result.data['success'] == true) {
        CustomSnackBar.successSnackBar(
            'Fixed ${result.data['results']['fixed']} approver IDs');
      } else {
        CustomSnackBar.errorSnackBar(
            'Fix failed: ${result.data['error']}');
      }

      // Reload data
      await _loadData();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      CustomSnackBar.errorSnackBar('Error fixing approver IDs: $e');
    }
  }

  Future<void> _forceTokenRefresh() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Force refresh FCM token
      final fcmTokenService = getIt<FcmTokenService>();
      await fcmTokenService.forceTokenRefresh(widget.userId);

      // Reload token
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _currentToken = prefs.getString('fcm_token') ?? 'Not found';
        _isLoading = false;
      });

      CustomSnackBar.successSnackBar('FCM token refreshed successfully');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      CustomSnackBar.errorSnackBar('Error refreshing token: $e');
    }
  }

  Future<void> _setupAsApprover() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get user details
      final userDoc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.userId)
          .get();

      if (!userDoc.exists) {
        throw Exception('User document not found');
      }

      // Extract name
      final userData = userDoc.data()!;
      final name = userData['name'] ?? userData['employeeName'] ?? 'Unknown User';

      // Call Cloud Function to setup as approver
      final callable =
      FirebaseFunctions.instance.httpsCallable('setupOvertimeApprover');
      final result = await callable.call({
        'employeeId': widget.userId,
        'employeeName': name,
      });

      if (result.data['success'] == true) {
        CustomSnackBar.successSnackBar('Setup as overtime approver completed successfully');
      } else {
        CustomSnackBar.errorSnackBar(
            'Setup failed: ${result.data['error'] ?? 'Unknown error'}');
      }

      // Reload data
      await _loadData();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      CustomSnackBar.errorSnackBar('Error setting up as approver: $e');
    }
  }

  Future<void> _testSendNotification() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Call test notification Cloud Function
      final callable =
      FirebaseFunctions.instance.httpsCallable('sendTestNotification');
      final result = await callable.call({
        'targetUserId': widget.userId,
        'title': 'Admin Test Notification',
        'body': 'This is a test notification sent from the admin panel at ${DateTime.now()}',
      });

      setState(() {
        _isLoading = false;
      });

      if (result.data['success'] == true) {
        CustomSnackBar.successSnackBar('Test notification sent successfully');
      } else {
        CustomSnackBar.errorSnackBar(
            'Sending test notification failed: ${result.data['error']}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      CustomSnackBar.errorSnackBar('Error sending test notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Admin'),
        backgroundColor: scaffoldTopGradientClr,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scaffoldTopGradientClr,
              scaffoldBottomGradientClr,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                title: 'User Information',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User ID: ${widget.userId}',
                        style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('Current FCM Token:',
                        style: const TextStyle(color: Colors.white)),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _currentToken.isNotEmpty
                            ? '${_currentToken.substring(0, 20)}...'
                            : 'No token found',
                        style: TextStyle(
                          color: _currentToken.isNotEmpty
                              ? Colors.green
                              : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Actions',
                child: Column(
                  children: [
                    _buildActionButton(
                      label: 'Run Diagnostics',
                      icon: Icons.bug_report,
                      onPressed: _runDiagnostics,
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      label: 'Force Token Refresh',
                      icon: Icons.refresh,
                      onPressed: _forceTokenRefresh,
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      label: 'Fix Approver IDs',
                      icon: Icons.build,
                      onPressed: _fixOvertimeApproverIds,
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      label: 'Setup as Approver',
                      icon: Icons.admin_panel_settings,
                      onPressed: _setupAsApprover,
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      label: 'Test Send Notification',
                      icon: Icons.send,
                      onPressed: _testSendNotification,
                    ),
                  ],
                ),
              ),
              if (_diagnosticResults != null) ...[
                const SizedBox(height: 16),
                _buildSection(
                  title: 'Diagnostic Results',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Token exists: ${_diagnosticResults!['tokenExists'] ? '✅' : '❌'}',
                        style: TextStyle(
                          color: _diagnosticResults!['tokenExists']
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      Text(
                        'Alt token found: ${_diagnosticResults!['altTokenFound'] ? '✅' : '❌'}',
                        style: TextStyle(
                          color: _diagnosticResults!['altTokenFound']
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      Text(
                        'Is active approver: ${_diagnosticResults!['isActiveApprover'] ? '✅' : '❌'}',
                        style: TextStyle(
                          color: _diagnosticResults!['isActiveApprover']
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      Text(
                        'Fixes applied: ${_diagnosticResults!['fixesApplied'] ? '✅' : '❌'}',
                        style: TextStyle(
                          color: _diagnosticResults!['fixesApplied']
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      Text(
                        'Message: ${_diagnosticResults!['message']}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildSection(
                title: 'Approver Documents',
                child: Column(
                  children: _approverDocuments.map((doc) {
                    final isActive = doc['isActive'] == true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive
                              ? Colors.green.withOpacity(0.5)
                              : Colors.grey.withOpacity(0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Document ID: ${doc['id']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.green
                                      : Colors.grey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isActive ? 'ACTIVE' : 'INACTIVE',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Approver ID: ${doc['approverId']}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            'Name: ${doc['approverName'] ?? 'Unknown'}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            'Setup at: ${doc['setupAt']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          if (doc['migratedTo'] != null)
                            Text(
                              'Migrated to: ${doc['migratedTo']}',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          if (doc['migratedFrom'] != null)
                            Text(
                              'Migrated from: ${doc['migratedFrom']}',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Recent Errors',
                child: Column(
                  children: _recentErrors.isEmpty
                      ? [
                    const Text(
                      'No recent errors found',
                      style: TextStyle(color: Colors.white),
                    )
                  ]
                      : _recentErrors.map((error) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Type: ${error['type'] ?? 'Unknown'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Error: ${error['error'] ?? 'None'}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          if (error['approverId'] != null)
                            Text(
                              'Approver ID: ${error['approverId']}',
                              style: const TextStyle(
                                  color: Colors.white),
                            ),
                          if (error['requesterId'] != null)
                            Text(
                              'Requester ID: ${error['requesterId']}',
                              style: const TextStyle(
                                  color: Colors.white),
                            ),
                          Text(
                            'Time: ${error['timestamp']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          backgroundColor: accentColor,
        ),
      ),
    );
  }
}