// lib/dashboard/checkout_handler.dart - Fixed version

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phoenician_face_auth/checkout_request/create_request_view.dart';
import 'package:phoenician_face_auth/checkout_request/request_history_view.dart';
import 'package:phoenician_face_auth/common/utils/custom_snackbar.dart';
import 'package:phoenician_face_auth/repositories/check_out_request_repository.dart';
import 'package:phoenician_face_auth/model/check_out_request_model.dart';
import 'package:phoenician_face_auth/services/service_locator.dart';

class CheckoutHandler {
  // Method to handle check-out process
  static Future<bool> handleCheckOut({
    required BuildContext context,
    required String employeeId,
    required String employeeName,
    required bool isWithinGeofence,
    required Position? currentPosition,
    required VoidCallback onRegularCheckOut,
  }) async {
    // If within geofence, proceed with normal check-out
    if (isWithinGeofence) {
      onRegularCheckOut();
      return true;
    }

    // If not within geofence, we need to handle it differently
    if (currentPosition == null) {
      CustomSnackBar.errorSnackBar("Unable to get your current location. Please try again.");
      return false;
    }

    // Check if there's an approved request for today
    final repository = getIt<CheckOutRequestRepository>();
    final requests = await repository.getRequestsForEmployee(employeeId);

    // Filter for today's approved requests
    final today = DateTime.now();
    final approvedRequests = requests.where((req) =>
    req.status == CheckOutRequestStatus.approved &&
        req.requestTime.year == today.year &&
        req.requestTime.month == today.month &&
        req.requestTime.day == today.day
    ).toList();

    if (approvedRequests.isNotEmpty) {
      // There's already an approved request, proceed with check-out
      onRegularCheckOut();
      return true;
    }

    // Check for pending requests today
    final pendingRequests = requests.where((req) =>
    req.status == CheckOutRequestStatus.pending &&
        req.requestTime.year == today.year &&
        req.requestTime.month == today.month &&
        req.requestTime.day == today.day
    ).toList();

    if (pendingRequests.isNotEmpty) {
      // Already has a pending request, show it
      return await _showPendingRequestOptions(context, employeeId);
    }

    // No approved or pending requests yet, show the request form
    return await _showCreateRequestForm(
      context,
      employeeId,
      employeeName,
      currentPosition,
      null, // Adding null for lineManagerId
      false, // Adding false for isCheckIn - this is a checkout
    );
  }

  // Show pending request options
  static Future<bool> _showPendingRequestOptions(
      BuildContext context,
      String employeeId,
      [bool isCheckIn = false] // Make isCheckIn optional with a default value
      ) async {
    debugPrint("HANDLER: Showing pending request options dialog for ${isCheckIn ? 'check-in' : 'check-out'}");

    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Pending ${isCheckIn ? 'Check-In' : 'Check-Out'} Request"),
        content: Text(
            "You already have a pending request to ${isCheckIn ? 'check in' : 'check out'} from your current location. "
                "Do you want to view the status of your request or create a new one?"
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint("HANDLER: Dialog - Cancel button pressed");
              Navigator.pop(context, false);
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              debugPrint("HANDLER: Dialog - View Requests button pressed");
              Navigator.pop(context, false); // First pop the dialog with 'false' result

              // Show request history
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CheckOutRequestHistoryView(
                    employeeId: employeeId,
                  ),
                ),
              );

              debugPrint("HANDLER: Returned from request history with result: $result");
            },
            child: const Text("View Requests"),
          ),
          TextButton(
            onPressed: () {
              debugPrint("HANDLER: Dialog - Create New Request button pressed");
              Navigator.pop(context, true);
            },
            child: const Text("Create New Request"),
          ),
        ],
      ),
    );

    debugPrint("HANDLER: Dialog result: $result");
    return result == true;
  }

  // Show create request form
  static Future<bool> _showCreateRequestForm(
      BuildContext context,
      String employeeId,
      String employeeName,
      Position currentPosition,
      String? lineManagerId,
      bool isCheckIn,
      ) async {
    debugPrint("CheckInOutHandler: Creating ${isCheckIn ? 'check-in' : 'check-out'} request form");
    debugPrint("  Employee: $employeeId ($employeeName)");
    debugPrint("  Line manager ID: $lineManagerId");
    debugPrint("  IsCheckIn: $isCheckIn");
    debugPrint("  Position: ${currentPosition.latitude}, ${currentPosition.longitude}");

    try {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => CreateCheckOutRequestView(
            employeeId: employeeId,
            employeeName: employeeName,
            currentPosition: currentPosition,
            extra: {
              'lineManagerId': lineManagerId,
              'isCheckIn': isCheckIn, // Ensure this is passed correctly
            },
          ),
        ),
      );

      debugPrint("CheckInOutHandler: Request form returned with result: $result");
      return result ?? false;
    } catch (e) {
      debugPrint("CheckInOutHandler: Error showing create request form: $e");
      return false;
    }
  }

  // Show request history
  static Future<void> showRequestHistory(
      BuildContext context,
      String employeeId,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckOutRequestHistoryView(
          employeeId: employeeId,
        ),
      ),
    );
  }
}