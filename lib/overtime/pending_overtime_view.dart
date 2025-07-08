// lib/overtime/pending_overtime_view.dart - ENHANCED WITH MULTI-PROJECT SUPPORT

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phoenician_face_auth/constants/theme.dart';
import 'package:phoenician_face_auth/model/overtime_request_model.dart';
import 'package:phoenician_face_auth/common/utils/custom_snackbar.dart';
import 'package:phoenician_face_auth/overtime/overtime_request_details.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingOvertimeView extends StatefulWidget {
  final String approverId;

  const PendingOvertimeView({
    Key? key,
    required this.approverId,
  }) : super(key: key);

  @override
  State<PendingOvertimeView> createState() => _PendingOvertimeViewState();
}

class _PendingOvertimeViewState extends State<PendingOvertimeView> {
  List<OvertimeRequest> _pendingRequests = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('overtime_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('requestTime', descending: true)
          .get();

      List<OvertimeRequest> requests = [];

      for (var doc in snapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String docApproverId = data['approverEmpId']?.toString() ?? '';

          bool isMatch = docApproverId == widget.approverId ||
              docApproverId == widget.approverId.replaceAll('EMP', '') ||
              docApproverId == 'EMP${widget.approverId}' ||
              widget.approverId == docApproverId.replaceAll('EMP', '') ||
              widget.approverId == 'EMP$docApproverId';

          if (isMatch) {
            // ✅ NEW: Use enhanced fromMap that handles multi-project format
            // ✅ CORRECT - parameters in correct order
            OvertimeRequest request = OvertimeRequest.fromMap(doc.id, data);
            requests.add(request);
          }
        } catch (e) {
          print("Error parsing request ${doc.id}: $e");
          continue;
        }
      }

      setState(() {
        _pendingRequests = requests;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error loading requests: $e";
      });

      if (mounted) {
        CustomSnackBar.errorSnackBar("Error loading requests: $e");
      }
    }
  }

  String _getFormattedDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final requestDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (requestDate == today) {
      return 'Today';
    } else if (requestDate == today.subtract(Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM dd, yyyy').format(dateTime);
    }
  }

  String _getFormattedDay(DateTime dateTime) {
    return DateFormat('EEEE').format(dateTime);
  }

  Future<void> _handleRequestAction(
      OvertimeRequest request,
      OvertimeRequestStatus status,
      String? message,
      ) async {
    try {
      setState(() => _isProcessing = true);

      await FirebaseFirestore.instance
          .collection('overtime_requests')
          .doc(request.id)
          .update({
        'status': status.toString().split('.').last,
        'responseMessage': message,
        'responseTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _isProcessing = false);

      if (mounted) {
        CustomSnackBar.successSnackBar(
            "Request ${status == OvertimeRequestStatus.approved ? 'approved' : 'rejected'} successfully"
        );
        _loadPendingRequests();
      }

    } catch (e) {
      setState(() => _isProcessing = false);

      if (mounted) {
        CustomSnackBar.errorSnackBar("Error updating request: $e");
      }
    }
  }

  void _showResponseDialog(OvertimeRequest request, bool isApproving) {
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isApproving ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isApproving ? Icons.check_circle_outline : Icons.cancel_outlined,
                color: isApproving ? Colors.green : Colors.red,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                isApproving ? "Approve Request" : "Reject Request",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isApproving ? Colors.green : Colors.red,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ ENHANCED: Multi-project summary
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.totalProjects > 1 ? "Multi-Project Request:" : "Project Details:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 8),

                    // ✅ NEW: Show project summary or individual project
                    if (request.totalProjects == 1) ...[
                      Text(
                        "${request.projectName} (${request.projectCode})",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Time: ${DateFormat('h:mm a').format(request.startTime)} - ${DateFormat('h:mm a').format(request.endTime)}",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ] else ...[
                      // Multi-project summary
                      Text(
                        "${request.totalProjects} Projects - ${request.totalDurationHours.toStringAsFixed(1)} hours total",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      SizedBox(height: 8),

                      // Show first few projects
                      ...request.projects.take(3).map((project) => Padding(
                        padding: EdgeInsets.only(left: 16, bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.arrow_right, size: 16, color: Colors.grey.shade600),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "${project.projectName} (${DateFormat('h:mm a').format(project.startTime)}-${DateFormat('h:mm a').format(project.endTime)})",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )).toList(),

                      if (request.projects.length > 3)
                        Padding(
                          padding: EdgeInsets.only(left: 16),
                          child: Text(
                            "... and ${request.projects.length - 3} more projects",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],

                    SizedBox(height: 8),
                    Text(
                      "Requested by: ${request.requesterName}",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                decoration: InputDecoration(
                  labelText: "Response Message ${isApproving ? '(Optional)' : '(Required)'}",
                  hintText: isApproving
                      ? "Add approval comments..."
                      : "Please provide reason for rejection...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isApproving ? Colors.green : Colors.red,
                      width: 2,
                    ),
                  ),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (!isApproving && messageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Please provide a reason for rejection"),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              _handleRequestAction(
                request,
                isApproving ? OvertimeRequestStatus.approved : OvertimeRequestStatus.rejected,
                messageController.text.trim(),
              );
            },
            icon: Icon(isApproving ? Icons.check : Icons.close),
            label: Text(isApproving ? "Approve" : "Reject"),
            style: ElevatedButton.styleFrom(
              backgroundColor: isApproving ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showRequesterDetails(OvertimeRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Icon(Icons.person, color: Colors.blue.shade700),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Request Details",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow("Requester", request.requesterName),
              _buildDetailRow("Employee ID", request.requesterId),
              _buildDetailRow("Request Date", _getFormattedDate(request.requestTime)),
              _buildDetailRow("Request Day", _getFormattedDay(request.requestTime)),
              _buildDetailRow("Request Time", DateFormat('h:mm a').format(request.requestTime)),

              SizedBox(height: 16),

              // ✅ ENHANCED: Multi-project information
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.totalProjects > 1 ? "Multi-Project Request:" : "Project Information:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    SizedBox(height: 8),

                    if (request.totalProjects == 1) ...[
                      Text("${request.projectName} (${request.projectCode})"),
                      Text("${request.totalEmployeeCount} employees selected"),
                      Text("${DateFormat('h:mm a').format(request.startTime)} - ${DateFormat('h:mm a').format(request.endTime)}"),
                    ] else ...[
                      Text("${request.totalProjects} projects"),
                      Text("${request.totalEmployeeCount} employees selected"),
                      Text("${request.totalDurationHours.toStringAsFixed(1)} total hours"),
                      SizedBox(height: 8),
                      Text(
                        "Projects:",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      ...request.projects.map((project) => Padding(
                        padding: EdgeInsets.only(left: 8, top: 2),
                        child: Text(
                          "• ${project.projectName} (${DateFormat('h:mm a').format(project.startTime)}-${DateFormat('h:mm a').format(project.endTime)})",
                          style: TextStyle(fontSize: 12),
                        ),
                      )).toList(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => OvertimeRequestDetails(request: request),
                ),
              );
            },
            child: Text("View Full Details"),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Overtime Approvals",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              "${_pendingRequests.length} pending request${_pendingRequests.length != 1 ? 's' : ''}",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _loadPendingRequests,
            tooltip: "Refresh",
          ),
          SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
            ),
            SizedBox(height: 16),
            Text(
              "Loading pending requests...",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: Colors.red.shade400,
                ),
              ),
              SizedBox(height: 24),
              Text(
                "Error Loading Requests",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadPendingRequests,
                icon: Icon(Icons.refresh),
                label: Text("Try Again"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_pendingRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  size: 64,
                  color: Colors.green.shade400,
                ),
              ),
              SizedBox(height: 24),
              Text(
                "All Caught Up!",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              SizedBox(height: 12),
              Text(
                "No pending overtime requests to review",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              TextButton.icon(
                onPressed: _loadPendingRequests,
                icon: Icon(Icons.refresh),
                label: Text("Check Again"),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final request = _pendingRequests[index];
        return _buildRequestCard(request, index);
      },
    );
  }

  // ✅ ENHANCED: Request card with multi-project support
  Widget _buildRequestCard(OvertimeRequest request, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with project info
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: request.totalProjects > 1 ? Colors.purple.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Text(
                        "Request #${index + 1}",
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Spacer(),

                    // ✅ NEW: Multi-project indicator
                    if (request.totalProjects > 1)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.purple.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.view_timeline, color: Colors.purple.shade700, size: 16),
                            SizedBox(width: 4),
                            Text(
                              "${request.totalProjects} Projects",
                              style: TextStyle(
                                color: Colors.purple.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people, color: Colors.blue.shade700, size: 16),
                          SizedBox(width: 4),
                          Text(
                            "${request.totalEmployeeCount} Employees",
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => OvertimeRequestDetails(request: request),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ✅ ENHANCED: Show project summary
                              Text(
                                request.projectsSummary,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              SizedBox(height: 4),

                              // ✅ NEW: Different info for single vs multi-project
                              if (request.totalProjects == 1)
                                Text(
                                  "Code: ${request.projectCode}",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              else
                                Text(
                                  "Total Duration: ${request.totalDurationHours.toStringAsFixed(1)} hours",
                                  style: TextStyle(
                                    color: Colors.purple.shade700,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey.shade400,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Request details
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Requester info - clickable
                GestureDetector(
                  onTap: () => _showRequesterDetails(request),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.person_outline,
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Requested by:",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                request.requesterName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Date and time info
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_today, color: Colors.purple.shade600, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  "Request Date",
                                  style: TextStyle(
                                    color: Colors.purple.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            Text(
                              _getFormattedDate(request.requestTime),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _getFormattedDay(request.requestTime),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  request.totalProjects > 1 ? Icons.view_timeline : Icons.access_time,
                                  color: Colors.teal.shade600,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  request.totalProjects > 1 ? "Total Duration" : "Overtime Hours",
                                  style: TextStyle(
                                    color: Colors.teal.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),

                            // ✅ ENHANCED: Different display for single vs multi-project
                            if (request.totalProjects == 1) ...[
                              Text(
                                "${DateFormat('h:mm a').format(request.startTime)}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                "to ${DateFormat('h:mm a').format(request.endTime)}",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ] else ...[
                              Text(
                                "${request.totalDurationHours.toStringAsFixed(1)} hours",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                "across ${request.totalProjects} projects",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : () => _showResponseDialog(request, false),
                        icon: Icon(Icons.close_rounded, size: 18),
                        label: Text("Reject"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade600,
                          side: BorderSide(color: Colors.red.shade300, width: 1.5),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : () => _showResponseDialog(request, true),
                        icon: _isProcessing
                            ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : Icon(Icons.check_rounded, size: 18),
                        label: Text(_isProcessing ? "Processing..." : "Approve"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}