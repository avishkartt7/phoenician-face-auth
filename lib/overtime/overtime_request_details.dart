// lib/overtime/overtime_request_details.dart (continued)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phoenician_face_auth/constants/theme.dart';
import 'package:phoenician_face_auth/model/overtime_request_model.dart';

class OvertimeRequestDetails extends StatefulWidget {
  final OvertimeRequest request;

  const OvertimeRequestDetails({
    Key? key,
    required this.request,
  }) : super(key: key);

  @override
  State<OvertimeRequestDetails> createState() => _OvertimeRequestDetailsState();
}

class _OvertimeRequestDetailsState extends State<OvertimeRequestDetails> {
  List<Map<String, dynamic>> _employeeDetails = [];
  Map<String, dynamic>? _requesterDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployeeDetails();
  }

  Future<void> _loadEmployeeDetails() async {
    try {
      List<Map<String, dynamic>> details = [];

      // Get details for each employee
      for (String empId in widget.request.employeeIds) {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('employees')
            .doc(empId)
            .get();

        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          details.add(data);
        }
      }

      // Get requester details
      DocumentSnapshot requesterDoc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.request.requesterId)
          .get();

      if (mounted) {
        setState(() {
          _employeeDetails = details;
          if (requesterDoc.exists) {
            _requesterDetails = {
              'id': requesterDoc.id,
              ...requesterDoc.data() as Map<String, dynamic>,
            };
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildCard({required String title, required Widget content}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
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
            padding: const EdgeInsets.all(16),
            child: content,
          ),
        ],
      ),
    );
  }

  // Add to all three switch methods:


  Widget _buildDetailRow({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Overtime Request Details"),
        backgroundColor: scaffoldTopGradientClr,
      ),
      body: Container(
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: accentColor))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Request Status Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getStatusColor(widget.request.status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusColor(widget.request.status).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(widget.request.status),
                      color: _getStatusColor(widget.request.status),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getStatusText(widget.request.status),
                          style: TextStyle(
                            color: _getStatusColor(widget.request.status),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.request.responseMessage != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.request.responseMessage!,
                            style: TextStyle(
                              color: _getStatusColor(widget.request.status).withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Project Details Card
              _buildCard(
                title: "Project Details",
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      label: "Project Name",
                      value: widget.request.projectName,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      label: "Project Code",
                      value: widget.request.projectCode,
                    ),
                  ],
                ),
              ),

              // Time Details Card
              _buildCard(
                title: "Overtime Duration",
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      label: "Start Time",
                      value: DateFormat('h:mm a').format(widget.request.startTime),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      label: "End Time",
                      value: DateFormat('h:mm a').format(widget.request.endTime),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      label: "Duration",
                      value: "${widget.request.endTime.difference(widget.request.startTime).inHours} hours",
                    ),
                  ],
                ),
              ),

              // Requester Details Card
              if (_requesterDetails != null)
                _buildCard(
                  title: "Requested By",
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        label: "Name",
                        value: _requesterDetails!['name'] ?? 'Unknown',
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        label: "Designation",
                        value: _requesterDetails!['designation'] ?? 'N/A',
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        label: "Department",
                        value: _requesterDetails!['department'] ?? 'N/A',
                      ),
                    ],
                  ),
                ),

              // Employees List Card
              _buildCard(
                title: "Selected Employees",
                content: Column(
                  children: _employeeDetails.map((employee) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: accentColor.withOpacity(0.2),
                          child: Text(
                            (employee['name'] as String? ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employee['name'] ?? 'Unknown',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                employee['designation'] ?? 'No designation',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(OvertimeRequestStatus status) {
    switch (status) {
      case OvertimeRequestStatus.pending:
        return Colors.orange;
      case OvertimeRequestStatus.approved:
        return Colors.green;
      case OvertimeRequestStatus.rejected:
        return Colors.red;
      case OvertimeRequestStatus.cancelled:  // ✅ ADD THIS LINE
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(OvertimeRequestStatus status) {
    switch (status) {
      case OvertimeRequestStatus.pending:
        return Icons.pending;
      case OvertimeRequestStatus.approved:
        return Icons.check_circle;
      case OvertimeRequestStatus.rejected:
        return Icons.cancel;
      case OvertimeRequestStatus.cancelled:  // ✅ ADD THIS LINE
        return Icons.cancel_outlined;
    }
  }

  String _getStatusText(OvertimeRequestStatus status) {
    switch (status) {
      case OvertimeRequestStatus.pending:
        return "Pending Approval";
      case OvertimeRequestStatus.approved:
        return "Approved";
      case OvertimeRequestStatus.rejected:
        return "Rejected";
      case OvertimeRequestStatus.cancelled:  // ✅ ADD THIS LINE
        return "Cancelled";
    }
  }
}


