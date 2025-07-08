// lib/model/leave_application_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

enum LeaveType {
  annual,
  maternity,
  paternity,
  sick,
  unpaid,
  emergency,
  compensate,
}

extension LeaveTypeExtension on LeaveType {
  String get displayName {
    switch (this) {
      case LeaveType.annual:
        return 'Annual Leave';
      case LeaveType.maternity:
        return 'Maternity Leave';
      case LeaveType.paternity:
        return 'Paternity Leave';
      case LeaveType.sick:
        return 'Sick Leave';
      case LeaveType.unpaid:
        return 'Unpaid Leave';
      case LeaveType.emergency:
        return 'Emergency Leave';
      case LeaveType.compensate:
        return 'Compensate Leave';
    }
  }

  String get name {
    return toString().split('.').last;
  }

  // Updated leave allocation info
  String get allocationInfo {
    switch (this) {
      case LeaveType.annual:
        return '30 days per year';
      case LeaveType.sick:
        return '15 days per year';
      case LeaveType.maternity:
        return '10 days per year';
      case LeaveType.paternity:
        return '10 days per year';
      case LeaveType.emergency:
        return '10 days per year';
      case LeaveType.compensate:
        return 'Earned through overtime';
      case LeaveType.unpaid:
        return 'Unlimited';
    }
  }

  // Check if certificate is required for this leave type
  bool get requiresCertificate {
    switch (this) {
      case LeaveType.sick:
        return true; // Always require certificate for sick leave
      case LeaveType.annual:
      case LeaveType.maternity:
      case LeaveType.paternity:
      case LeaveType.emergency:
      case LeaveType.compensate:
      case LeaveType.unpaid:
        return false;
    }
  }

  static LeaveType fromString(String value) {
    return LeaveType.values.firstWhere(
          (type) => type.name == value,
      orElse: () => LeaveType.annual,
    );
  }
}

enum LeaveStatus {
  pending,
  approved,
  rejected,
  cancelled,
}

extension LeaveStatusExtension on LeaveStatus {
  String get displayName {
    switch (this) {
      case LeaveStatus.pending:
        return 'Pending';
      case LeaveStatus.approved:
        return 'Approved';
      case LeaveStatus.rejected:
        return 'Rejected';
      case LeaveStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get name {
    return toString().split('.').last;
  }

  // Status color for UI
  String get colorCode {
    switch (this) {
      case LeaveStatus.pending:
        return '#FF9800'; // Orange
      case LeaveStatus.approved:
        return '#4CAF50'; // Green
      case LeaveStatus.rejected:
        return '#F44336'; // Red
      case LeaveStatus.cancelled:
        return '#9E9E9E'; // Grey
    }
  }

  static LeaveStatus fromString(String value) {
    return LeaveStatus.values.firstWhere(
          (status) => status.name == value,
      orElse: () => LeaveStatus.pending,
    );
  }
}

class LeaveApplicationModel {
  final String? id;
  final String employeeId;
  final String employeeName;
  final String employeePin;
  final LeaveType leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final String reason;
  final bool isAlreadyTaken;
  final String? certificateUrl;
  final String? certificateFileName;
  final LeaveStatus status;
  final DateTime applicationDate;
  final String lineManagerId;
  final String lineManagerName;
  final DateTime? reviewDate;
  final String? reviewComments;
  final String? reviewedBy;
  final bool isActive;
  final bool isSynced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LeaveApplicationModel({
    this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeePin,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.reason,
    this.isAlreadyTaken = false,
    this.certificateUrl,
    this.certificateFileName,
    this.status = LeaveStatus.pending,
    required this.applicationDate,
    required this.lineManagerId,
    required this.lineManagerName,
    this.reviewDate,
    this.reviewComments,
    this.reviewedBy,
    this.isActive = true,
    this.isSynced = false,
    this.createdAt,
    this.updatedAt,
  });

  // Create a copy with updated values
  LeaveApplicationModel copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? employeePin,
    LeaveType? leaveType,
    DateTime? startDate,
    DateTime? endDate,
    int? totalDays,
    String? reason,
    bool? isAlreadyTaken,
    String? certificateUrl,
    String? certificateFileName,
    LeaveStatus? status,
    DateTime? applicationDate,
    String? lineManagerId,
    String? lineManagerName,
    DateTime? reviewDate,
    String? reviewComments,
    String? reviewedBy,
    bool? isActive,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeaveApplicationModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      employeePin: employeePin ?? this.employeePin,
      leaveType: leaveType ?? this.leaveType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalDays: totalDays ?? this.totalDays,
      reason: reason ?? this.reason,
      isAlreadyTaken: isAlreadyTaken ?? this.isAlreadyTaken,
      certificateUrl: certificateUrl ?? this.certificateUrl,
      certificateFileName: certificateFileName ?? this.certificateFileName,
      status: status ?? this.status,
      applicationDate: applicationDate ?? this.applicationDate,
      lineManagerId: lineManagerId ?? this.lineManagerId,
      lineManagerName: lineManagerName ?? this.lineManagerName,
      reviewDate: reviewDate ?? this.reviewDate,
      reviewComments: reviewComments ?? this.reviewComments,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      isActive: isActive ?? this.isActive,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'employeePin': employeePin,
      'leaveType': leaveType.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalDays': totalDays,
      'reason': reason,
      'isAlreadyTaken': isAlreadyTaken,
      'certificateUrl': certificateUrl,
      'certificateFileName': certificateFileName,
      'status': status.name,
      'applicationDate': Timestamp.fromDate(applicationDate),
      'lineManagerId': lineManagerId,
      'lineManagerName': lineManagerName,
      'reviewDate': reviewDate != null ? Timestamp.fromDate(reviewDate!) : null,
      'reviewComments': reviewComments,
      'reviewedBy': reviewedBy,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Convert to Map for local database
  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'employee_pin': employeePin,
      'leave_type': leaveType.name,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'total_days': totalDays,
      'reason': reason,
      'is_already_taken': isAlreadyTaken ? 1 : 0,
      'certificate_url': certificateUrl,
      'certificate_file_name': certificateFileName,
      'status': status.name,
      'application_date': applicationDate.toIso8601String(),
      'line_manager_id': lineManagerId,
      'line_manager_name': lineManagerName,
      'review_date': reviewDate?.toIso8601String(),
      'review_comments': reviewComments,
      'reviewed_by': reviewedBy,
      'is_active': isActive ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Create from Firestore document
  factory LeaveApplicationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return LeaveApplicationModel(
      id: doc.id,
      employeeId: data['employeeId'] ?? '',
      employeeName: data['employeeName'] ?? '',
      employeePin: data['employeePin'] ?? '',
      leaveType: LeaveTypeExtension.fromString(data['leaveType'] ?? 'annual'),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      totalDays: data['totalDays'] ?? 0,
      reason: data['reason'] ?? '',
      isAlreadyTaken: data['isAlreadyTaken'] ?? false,
      certificateUrl: data['certificateUrl'],
      certificateFileName: data['certificateFileName'],
      status: LeaveStatusExtension.fromString(data['status'] ?? 'pending'),
      applicationDate: (data['applicationDate'] as Timestamp).toDate(),
      lineManagerId: data['lineManagerId'] ?? '',
      lineManagerName: data['lineManagerName'] ?? '',
      reviewDate: data['reviewDate'] != null ? (data['reviewDate'] as Timestamp).toDate() : null,
      reviewComments: data['reviewComments'],
      reviewedBy: data['reviewedBy'],
      isActive: data['isActive'] ?? true,
      isSynced: true, // Firestore data is always synced
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  // Create from local database map
  factory LeaveApplicationModel.fromMap(Map<String, dynamic> map) {
    return LeaveApplicationModel(
      id: map['id'],
      employeeId: map['employee_id'] ?? '',
      employeeName: map['employee_name'] ?? '',
      employeePin: map['employee_pin'] ?? '',
      leaveType: LeaveTypeExtension.fromString(map['leave_type'] ?? 'annual'),
      startDate: DateTime.parse(map['start_date']),
      endDate: DateTime.parse(map['end_date']),
      totalDays: map['total_days'] ?? 0,
      reason: map['reason'] ?? '',
      isAlreadyTaken: (map['is_already_taken'] ?? 0) == 1,
      certificateUrl: map['certificate_url'],
      certificateFileName: map['certificate_file_name'],
      status: LeaveStatusExtension.fromString(map['status'] ?? 'pending'),
      applicationDate: DateTime.parse(map['application_date']),
      lineManagerId: map['line_manager_id'] ?? '',
      lineManagerName: map['line_manager_name'] ?? '',
      reviewDate: map['review_date'] != null ? DateTime.parse(map['review_date']) : null,
      reviewComments: map['review_comments'],
      reviewedBy: map['reviewed_by'],
      isActive: (map['is_active'] ?? 1) == 1,
      isSynced: (map['is_synced'] ?? 0) == 1,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  // Formatted date range string
  String get dateRange {
    final formatter = DateFormat('dd/MM/yyyy');
    return '${formatter.format(startDate)} - ${formatter.format(endDate)}';
  }

  // Short date range for UI
  String get shortDateRange {
    final formatter = DateFormat('dd MMM');
    if (startDate.year == endDate.year && startDate.month == endDate.month) {
      return '${formatter.format(startDate)} - ${endDate.day} ${DateFormat('MMM yyyy').format(endDate)}';
    }
    return '${formatter.format(startDate)} - ${formatter.format(endDate)} ${endDate.year}';
  }

  // Check if the application can be cancelled
  bool get canBeCancelled {
    return status == LeaveStatus.pending && isActive;
  }

  // Check if the application can be reviewed
  bool get canBeReviewed {
    return status == LeaveStatus.pending && isActive;
  }

  // Get days until leave starts
  int get daysUntilLeave {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);

    if (startDateOnly.isBefore(todayOnly)) {
      return 0; // Leave has already started or passed
    }

    return startDateOnly.difference(todayOnly).inDays;
  }

  // Check if leave is upcoming
  bool get isUpcoming {
    return status == LeaveStatus.approved && daysUntilLeave > 0;
  }

  // Check if leave is current
  bool get isCurrent {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);

    return status == LeaveStatus.approved &&
        !todayOnly.isBefore(startDateOnly) &&
        !todayOnly.isAfter(endDateOnly);
  }

  // Get application age in days
  int get applicationAgeInDays {
    final now = DateTime.now();
    return now.difference(applicationDate).inDays;
  }

  // Check if application is urgent (pending for more than 3 days)
  bool get isUrgent {
    return status == LeaveStatus.pending && applicationAgeInDays > 3;
  }

  @override
  String toString() {
    return 'LeaveApplicationModel(id: $id, employeeName: $employeeName, leaveType: ${leaveType.displayName}, status: ${status.displayName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LeaveApplicationModel &&
        other.id == id &&
        other.employeeId == employeeId &&
        other.leaveType == leaveType &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode {
    return id.hashCode ^
    employeeId.hashCode ^
    leaveType.hashCode ^
    startDate.hashCode ^
    endDate.hashCode;
  }
}