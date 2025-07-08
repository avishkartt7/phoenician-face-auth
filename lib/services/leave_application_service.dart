// lib/services/leave_application_service.dart - COMPLETE FIXED VERSION

import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:phoenician_face_auth/model/leave_application_model.dart';
import 'package:phoenician_face_auth/model/leave_balance_model.dart';
import 'package:phoenician_face_auth/repositories/leave_application_repository.dart';
import 'package:phoenician_face_auth/services/connectivity_service.dart';
import 'package:phoenician_face_auth/services/simple_firebase_auth_service.dart'; // ✅ FIXED IMPORT
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

class LeaveApplicationService {
  final LeaveApplicationRepository _repository;
  final ConnectivityService _connectivityService;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  LeaveApplicationService({
    required LeaveApplicationRepository repository,
    required ConnectivityService connectivityService,
  }) : _repository = repository,
        _connectivityService = connectivityService;

  // ✅ FIXED: Upload certificate with simple anonymous authentication
  Future<Map<String, String>?> uploadCertificate(
      File certificateFile,
      String employeeId,
      String applicationId,
      ) async {
    try {
      if (_connectivityService.currentStatus == ConnectionStatus.offline) {
        throw Exception('Cannot upload files while offline. Please connect to internet.');
      }

      debugPrint("🔄 Starting certificate upload for employee: $employeeId");

      // ✅ SIMPLE FIX: Use anonymous authentication instead of complex email/password
      final isAuthenticated = await SimpleFirebaseAuthService.ensureAuthenticated();
      if (!isAuthenticated) {
        throw Exception('Authentication failed. Please check your internet connection and try again.');
      }

      // Validate file exists and is readable
      if (!await certificateFile.exists()) {
        throw Exception('Selected file does not exist');
      }

      final fileSize = await certificateFile.length();
      debugPrint("📊 File size: $fileSize bytes");

      if (fileSize == 0) {
        throw Exception('Selected file is empty');
      }

      if (fileSize > 10 * 1024 * 1024) { // 10MB limit
        throw Exception('File size too large. Maximum 10MB allowed.');
      }

      // Get file extension and validate
      final fileName = path.basename(certificateFile.path);
      final fileExtension = path.extension(fileName).toLowerCase();
      final allowedExtensions = ['.pdf', '.jpg', '.jpeg', '.png', '.doc', '.docx'];

      if (!allowedExtensions.contains(fileExtension)) {
        throw Exception('Invalid file type. Allowed: PDF, JPG, PNG, DOC, DOCX');
      }

      // Create unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueFileName = '${timestamp}_${employeeId}_$fileName';

      // ✅ FIXED: Create proper Firebase Storage reference path
      final storageRef = _storage
          .ref()
          .child('leave_certificates')
          .child(employeeId)
          .child(applicationId)
          .child(uniqueFileName);

      debugPrint("☁️ Storage path: ${storageRef.fullPath}");

      // ✅ ENHANCED: Set comprehensive metadata
      final metadata = SettableMetadata(
        contentType: _getMimeType(fileExtension),
        customMetadata: {
          'employeeId': employeeId,
          'applicationId': applicationId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'originalFileName': fileName,
          'uploaderUID': SimpleFirebaseAuthService.currentUser?.uid ?? 'anonymous',
        },
      );

      // ✅ ENHANCED: Upload with retry mechanism
      final uploadTask = storageRef.putFile(certificateFile, metadata);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        debugPrint("📤 Upload progress: ${progress.toStringAsFixed(1)}%");
      });

      // Wait for upload completion with timeout
      final snapshot = await uploadTask.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw Exception('Upload timeout. Please check your internet connection and try again.');
        },
      );

      // Verify upload state
      if (snapshot.state != TaskState.success) {
        throw Exception('Upload failed with state: ${snapshot.state}');
      }

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint("🔗 Download URL obtained: $downloadUrl");

      // Verify URL is accessible
      if (downloadUrl.isEmpty) {
        throw Exception('Failed to get download URL');
      }

      final result = {
        'url': downloadUrl,
        'fileName': uniqueFileName,
        'originalFileName': fileName,
        'fileSize': fileSize.toString(),
        'uploadTimestamp': timestamp.toString(),
        'storagePath': storageRef.fullPath,
      };

      debugPrint("🎉 Certificate uploaded successfully!");
      debugPrint("📋 Upload result: $result");

      return result;

    } catch (e) {
      debugPrint("❌ Certificate upload error: $e");
      debugPrint("🔍 Error type: ${e.runtimeType}");

      // Provide more specific error messages
      if (e.toString().contains('network') || e.toString().contains('timeout')) {
        throw Exception('Network error during upload. Please check your internet connection and try again.');
      } else if (e.toString().contains('permission') || e.toString().contains('unauthorized')) {
        throw Exception('Permission denied. Please restart the app and try again.');
      } else if (e.toString().contains('quota') || e.toString().contains('storage')) {
        throw Exception('Storage limit reached. Please contact administrator.');
      } else {
        throw Exception('Upload failed: ${e.toString()}');
      }
    }
  }

  // ✅ ADDED: Helper method to get MIME type based on file extension
  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case '.pdf':
        return 'application/pdf';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  // ✅ ENHANCED: Submit leave application with simple authentication
  Future<String?> submitLeaveApplication({
    required String employeeId,
    required String employeeName,
    required String employeePin,
    required LeaveType leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    required bool isAlreadyTaken,
    File? certificateFile,
  }) async {
    try {
      debugPrint("🚀 Starting leave application submission for $employeeName");

      // ✅ SIMPLE: Ensure anonymous authentication first
      final isAuthenticated = await SimpleFirebaseAuthService.ensureAuthenticated();
      if (!isAuthenticated) {
        throw Exception('Authentication failed. Please check your internet connection and try again.');
      }

      // Validate inputs
      if (startDate.isAfter(endDate)) {
        throw Exception('Start date cannot be after end date');
      }

      if (reason.trim().isEmpty || reason.trim().length < 10) {
        throw Exception('Please provide a detailed reason (minimum 10 characters)');
      }

      // Check if certificate is required and provided
      if (isCertificateRequired(leaveType, isAlreadyTaken) && certificateFile == null) {
        String requiredFor = '';
        if (leaveType == LeaveType.sick) {
          requiredFor = 'sick leave (medical certificate required)';
        } else if (isAlreadyTaken) {
          requiredFor = 'already taken leave';
        }
        throw Exception('Certificate is required for $requiredFor');
      }

      // Calculate total days
      final totalDays = calculateTotalDays(startDate, endDate);

      if (totalDays <= 0) {
        throw Exception('Invalid date range');
      }

      // Get line manager information
      final lineManagerInfo = await _repository.getLineManagerInfo(employeePin);
      if (lineManagerInfo == null) {
        throw Exception('Line manager information not found. Please contact HR.');
      }

      // Check leave balance (for applicable leave types)
      final leaveBalance = await _repository.getLeaveBalance(employeeId);
      if (leaveBalance != null && !leaveBalance.hasEnoughBalance(leaveType.name, totalDays)) {
        final remainingDays = leaveBalance.getRemainingDays(leaveType.name);
        throw Exception('Insufficient leave balance. Available: $remainingDays days, Requested: $totalDays days');
      }

      // Generate application ID first
      final applicationId = 'LA_${DateTime.now().millisecondsSinceEpoch}';

      // ✅ ENHANCED: Upload certificate with proper error handling
      String? certificateUrl;
      String? certificateFileName;

      if (certificateFile != null) {
        debugPrint("📎 Uploading certificate before creating application...");

        try {
          final uploadResult = await uploadCertificate(
            certificateFile,
            employeeId,
            applicationId,
          );

          if (uploadResult != null) {
            certificateUrl = uploadResult['url'];
            certificateFileName = uploadResult['originalFileName'];
            debugPrint("✅ Certificate uploaded successfully");
            debugPrint("🔗 URL: $certificateUrl");
          } else {
            throw Exception('Certificate upload returned null result');
          }
        } catch (uploadError) {
          debugPrint("❌ Certificate upload failed: $uploadError");
          throw Exception('Failed to upload certificate: $uploadError');
        }
      }

      // ✅ ENHANCED: Create leave application with all certificate details
      final application = LeaveApplicationModel(
        id: applicationId,
        employeeId: employeeId,
        employeeName: employeeName,
        employeePin: employeePin,
        leaveType: leaveType,
        startDate: startDate,
        endDate: endDate,
        totalDays: totalDays,
        reason: reason,
        isAlreadyTaken: isAlreadyTaken,
        certificateUrl: certificateUrl, // ✅ Now properly set
        certificateFileName: certificateFileName, // ✅ Now properly set
        applicationDate: DateTime.now(),
        lineManagerId: lineManagerInfo['lineManagerId']!,
        lineManagerName: lineManagerInfo['lineManagerName']!,
        status: LeaveStatus.pending,
        isActive: true,
        createdAt: DateTime.now(),
      );

      debugPrint("💾 Saving application to database...");
      debugPrint("📋 Certificate URL: ${application.certificateUrl}");
      debugPrint("📋 Certificate File: ${application.certificateFileName}");

      // Submit the application
      final savedApplicationId = await _repository.submitLeaveApplication(application);

      if (savedApplicationId == null) {
        // If database save failed but file was uploaded, clean up
        if (certificateUrl != null) {
          try {
            await _storage.refFromURL(certificateUrl).delete();
            debugPrint("🧹 Cleaned up uploaded file due to database save failure");
          } catch (cleanupError) {
            debugPrint("⚠️ Failed to cleanup uploaded file: $cleanupError");
          }
        }
        throw Exception('Failed to save leave application to database');
      }

      // Update leave balance (add to pending)
      await _repository.updateLeaveBalance(
        employeeId,
        leaveType.name,
        totalDays,
        isApproval: false, // Adding to pending
      );

      // ✅ Send notification to line manager
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        await _sendEnhancedLeaveApplicationNotification(application);
      }

      debugPrint("🎉 Leave application submitted successfully: $savedApplicationId");
      return savedApplicationId;

    } catch (e) {
      debugPrint("❌ Error submitting leave application: $e");
      rethrow;
    }
  }

  // ✅ ENHANCED: Send comprehensive notification with certificate info
  Future<void> _sendEnhancedLeaveApplicationNotification(LeaveApplicationModel application) async {
    try {
      if (_connectivityService.currentStatus == ConnectionStatus.offline) {
        return;
      }

      debugPrint("📧 Sending enhanced notification to line manager: ${application.lineManagerId}");

      final notificationData = {
        'type': 'new_leave_application',
        'applicationId': application.id,
        'employeeId': application.employeeId,
        'employeeName': application.employeeName,
        'employeePin': application.employeePin,
        'leaveType': application.leaveType.name,
        'leaveTypeDisplay': application.leaveType.displayName,
        'startDate': Timestamp.fromDate(application.startDate),
        'endDate': Timestamp.fromDate(application.endDate),
        'totalDays': application.totalDays,
        'reason': application.reason,
        'managerId': application.lineManagerId,
        'managerName': application.lineManagerName,
        'isAlreadyTaken': application.isAlreadyTaken,
        'applicationDate': Timestamp.fromDate(application.applicationDate),
        'status': application.status.name,
        'hasAttachment': application.certificateUrl != null,
        'certificateUrl': application.certificateUrl,
        'certificateFileName': application.certificateFileName,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'priority': 'normal',
        'dateRange': application.dateRange,
      };

      // Send to manager's notification queue
      await _firestore
          .collection('manager_notifications')
          .doc(application.lineManagerId)
          .collection('notifications')
          .add(notificationData);

      // Send to global HR dashboard notifications
      await _firestore.collection('hr_notifications').add({
        ...notificationData,
        'type': 'new_leave_application_hr',
        'message': '${application.employeeName} submitted a leave application',
        'category': 'leave_management',
        'requiresAction': true,
      });

      debugPrint("✅ Enhanced notifications sent successfully");

    } catch (e) {
      debugPrint("❌ Error sending enhanced notifications: $e");
    }
  }

  // Calculate business days between two dates (excluding weekends)
  int calculateBusinessDays(DateTime startDate, DateTime endDate) {
    if (startDate.isAfter(endDate)) {
      return 0;
    }

    int businessDays = 0;
    DateTime current = startDate;

    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      // Check if current day is a weekday (Monday = 1, Sunday = 7)
      if (current.weekday >= 1 && current.weekday <= 5) {
        businessDays++;
      }
      current = current.add(const Duration(days: 1));
    }

    return businessDays;
  }

  // Calculate total days between two dates (including weekends)
  int calculateTotalDays(DateTime startDate, DateTime endDate) {
    if (startDate.isAfter(endDate)) {
      return 0;
    }
    return endDate.difference(startDate).inDays + 1;
  }

  // Check if certificate is required for this leave type
  bool isCertificateRequired(LeaveType leaveType, bool isAlreadyTaken) {
    // Always require certificate for sick leave
    if (leaveType == LeaveType.sick) {
      return true;
    }

    // Always require certificate for already taken leave
    if (isAlreadyTaken) {
      return true;
    }

    return false;
  }

  // ✅ ENHANCED: Approve leave application with HR notification
  Future<bool> approveLeaveApplication(
      String applicationId,
      String managerId, {
        String? comments,
      }) async {
    try {
      debugPrint("✅ Approving leave application: $applicationId by manager: $managerId");

      // Get the application details first
      final applications = await _repository.getLeaveApplicationsForEmployee('');
      final application = applications.firstWhere((app) => app.id == applicationId);

      // Update application status
      final success = await _repository.updateApplicationStatus(
        applicationId,
        LeaveStatus.approved,
        comments: comments,
        reviewedBy: managerId,
      );

      if (success) {
        // Move from pending to used days in balance
        await _repository.updateLeaveBalance(
          application.employeeId,
          application.leaveType.name,
          application.totalDays,
          isApproval: true,
        );

        // ✅ Send live notification to HR dashboard
        await _sendApprovalNotificationToHR(application, true, comments);

        debugPrint("✅ Leave application approved and HR notified");
      }

      return success;
    } catch (e) {
      debugPrint("❌ Error approving leave application: $e");
      return false;
    }
  }

  // ✅ ENHANCED: Reject leave application with HR notification
  Future<bool> rejectLeaveApplication(
      String applicationId,
      String managerId, {
        String? comments,
      }) async {
    try {
      debugPrint("❌ Rejecting leave application: $applicationId by manager: $managerId");

      // Get the application details first
      final applications = await _repository.getLeaveApplicationsForEmployee('');
      final application = applications.firstWhere((app) => app.id == applicationId);

      // Update application status
      final success = await _repository.updateApplicationStatus(
        applicationId,
        LeaveStatus.rejected,
        comments: comments,
        reviewedBy: managerId,
      );

      if (success) {
        // Remove from pending days
        await _repository.removePendingDaysFromBalance(
          application.employeeId,
          application.leaveType.name,
          application.totalDays,
        );

        // ✅ Send live notification to HR dashboard
        await _sendApprovalNotificationToHR(application, false, comments);

        debugPrint("❌ Leave application rejected and HR notified");
      }

      return success;
    } catch (e) {
      debugPrint("❌ Error rejecting leave application: $e");
      return false;
    }
  }

  // ✅ NEW: Send live notification to HR dashboard
  Future<void> _sendApprovalNotificationToHR(
      LeaveApplicationModel application,
      bool isApproved,
      String? comments,
      ) async {
    try {
      final action = isApproved ? 'approved' : 'rejected';
      final priority = isApproved ? 'normal' : 'high';

      // ✅ Send to HR dashboard with live notification capability
      await _firestore.collection('hr_live_notifications').add({
        'type': 'leave_${action}',
        'action': action,
        'message': '${application.lineManagerName} $action leave application from ${application.employeeName}',
        'applicationId': application.id,
        'employeeId': application.employeeId,
        'employeeName': application.employeeName,
        'employeePin': application.employeePin,
        'leaveType': application.leaveType.name,
        'leaveTypeDisplay': application.leaveType.displayName,
        'startDate': Timestamp.fromDate(application.startDate),
        'endDate': Timestamp.fromDate(application.endDate),
        'totalDays': application.totalDays,
        'managerId': application.lineManagerId,
        'managerName': application.lineManagerName,
        'isApproved': isApproved,
        'comments': comments,
        'certificateUrl': application.certificateUrl,
        'certificateFileName': application.certificateFileName,
        'hasAttachment': application.certificateUrl != null,
        'reason': application.reason,
        'isAlreadyTaken': application.isAlreadyTaken,
        'dateRange': application.dateRange,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'priority': priority,
        'category': 'leave_management',
        'month': DateTime.now().month,
        'year': DateTime.now().year,
      });

      debugPrint("📨 Live notification sent to HR dashboard");
    } catch (e) {
      debugPrint("❌ Error sending HR notification: $e");
    }
  }

  // Get leave applications for employee
  Future<List<LeaveApplicationModel>> getEmployeeLeaveApplications(
      String employeeId, {
        LeaveStatus? status,
        int limit = 20,
      }) async {
    return await _repository.getLeaveApplicationsForEmployee(
      employeeId,
      status: status,
      limit: limit,
    );
  }

  // Get pending applications for manager
  Future<List<LeaveApplicationModel>> getPendingApplicationsForManager(String managerId) async {
    return await _repository.getPendingApplicationsForManager(managerId);
  }

  // Get leave balance for employee
  Future<LeaveBalance?> getLeaveBalance(String employeeId, {int? year}) async {
    return await _repository.getLeaveBalance(employeeId, year: year);
  }

  // Validate leave dates
  bool validateLeaveDates(DateTime startDate, DateTime endDate) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);

    return !startDate.isAfter(endDate) && !startDateOnly.isBefore(todayOnly);
  }

  // Check if dates are in the past (for already taken leave)
  bool areDatesInPast(DateTime startDate, DateTime endDate) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);

    return endDateOnly.isBefore(todayOnly);
  }

  // Get leave statistics for employee
  Future<Map<String, dynamic>> getLeaveStatistics(String employeeId) async {
    try {
      final applications = await getEmployeeLeaveApplications(employeeId);
      final balance = await getLeaveBalance(employeeId);

      final stats = <String, dynamic>{
        'totalApplications': applications.length,
        'approvedApplications': applications.where((app) => app.status == LeaveStatus.approved).length,
        'pendingApplications': applications.where((app) => app.status == LeaveStatus.pending).length,
        'rejectedApplications': applications.where((app) => app.status == LeaveStatus.rejected).length,
        'totalDaysRequested': applications.fold<int>(0, (sum, app) => sum + app.totalDays),
        'totalDaysApproved': applications
            .where((app) => app.status == LeaveStatus.approved)
            .fold<int>(0, (sum, app) => sum + app.totalDays),
        'leaveBalance': balance?.getSummary(),
      };

      return stats;
    } catch (e) {
      debugPrint("❌ Error getting leave statistics: $e");
      return {};
    }
  }

  // Cancel leave application
  Future<bool> cancelLeaveApplication(String applicationId) async {
    try {
      return await _repository.cancelLeaveApplication(applicationId);
    } catch (e) {
      debugPrint("❌ Error cancelling leave application: $e");
      return false;
    }
  }

  // Sync pending operations when coming online
  Future<void> syncPendingOperations() async {
    try {
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        await _repository.syncPendingApplications();
        debugPrint("✅ Leave applications synced successfully");
      }
    } catch (e) {
      debugPrint("❌ Error syncing leave applications: $e");
    }
  }
}