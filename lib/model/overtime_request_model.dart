// lib/model/overtime_request_model.dart - FIXED BACKWARD COMPATIBLE VERSION

import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ Overtime request status enum
enum OvertimeRequestStatus {
  pending,
  approved,
  rejected,
  cancelled,
}

extension OvertimeRequestStatusExtension on OvertimeRequestStatus {
  String get displayName {
    switch (this) {
      case OvertimeRequestStatus.pending:
        return 'Pending';
      case OvertimeRequestStatus.approved:
        return 'Approved';
      case OvertimeRequestStatus.rejected:
        return 'Rejected';
      case OvertimeRequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get value {
    switch (this) {
      case OvertimeRequestStatus.pending:
        return 'pending';
      case OvertimeRequestStatus.approved:
        return 'approved';
      case OvertimeRequestStatus.rejected:
        return 'rejected';
      case OvertimeRequestStatus.cancelled:
        return 'cancelled';
    }
  }
}

// ✅ Multi-project entry model
class OvertimeProjectEntry {
  final String projectName;
  final String projectCode;
  final DateTime startTime;
  final DateTime endTime;
  final List<String> employeeIds;

  OvertimeProjectEntry({
    required this.projectName,
    required this.projectCode,
    required this.startTime,
    required this.endTime,
    required this.employeeIds,
  });

  double get durationInHours {
    return endTime.difference(startTime).inMinutes / 60.0;
  }

  Map<String, dynamic> toMap() {
    return {
      'projectName': projectName,
      'projectCode': projectCode,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'employeeIds': employeeIds,
      'duration': durationInHours,
    };
  }

  factory OvertimeProjectEntry.fromMap(Map<String, dynamic> map) {
    return OvertimeProjectEntry(
      projectName: map['projectName'] ?? '',
      projectCode: map['projectCode'] ?? '',
      startTime: (map['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (map['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      employeeIds: List<String>.from(map['employeeIds'] ?? []),
    );
  }

  OvertimeProjectEntry copyWith({
    String? projectName,
    String? projectCode,
    DateTime? startTime,
    DateTime? endTime,
    List<String>? employeeIds,
  }) {
    return OvertimeProjectEntry(
      projectName: projectName ?? this.projectName,
      projectCode: projectCode ?? this.projectCode,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      employeeIds: employeeIds ?? this.employeeIds,
    );
  }
}

// ✅ FIXED: Main overtime request model with backward compatibility
class OvertimeRequest {
  final String id;
  final String requesterId;
  final String requesterName;
  final String approverEmpId;
  final String approverName;
  final String projectName;
  final String projectCode;
  final DateTime startTime;
  final DateTime endTime;
  final List<String> employeeIds;
  final DateTime requestTime;
  final OvertimeRequestStatus status;
  final String? responseMessage;
  final DateTime? responseTime;

  // ✅ BACKWARD COMPATIBILITY: Add missing fields that your existing code expects
  final DateTime? approvedTime;
  final String? rejectionReason;

  // ✅ NEW: Multi-project support fields
  final int totalProjects;
  final int totalEmployeeCount;
  final double totalDurationHours;
  final List<OvertimeProjectEntry> projects;

  // ✅ Additional metadata
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int version;
  final bool isActive;
  final Map<String, dynamic>? metadata;

  OvertimeRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.approverEmpId,
    required this.approverName,
    required this.projectName,
    required this.projectCode,
    required this.startTime,
    required this.endTime,
    required this.employeeIds,
    required this.requestTime,
    required this.status,
    this.responseMessage,
    this.responseTime,
    // ✅ BACKWARD COMPATIBILITY
    this.approvedTime,
    this.rejectionReason,
    // ✅ NEW FIELDS
    this.totalProjects = 1,
    this.totalEmployeeCount = 0,
    this.totalDurationHours = 0.0,
    this.projects = const [],
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.version = 1,
    this.isActive = true,
    this.metadata,
  });

  // ✅ Helper properties
  String get projectsSummary {
    if (totalProjects == 1) {
      return projectName;
    } else {
      return "$totalProjects Projects";
    }
  }

  String get statusDisplayName => status.displayName;

  bool get isPending => status == OvertimeRequestStatus.pending;
  bool get isApproved => status == OvertimeRequestStatus.approved;
  bool get isRejected => status == OvertimeRequestStatus.rejected;
  bool get isCancelled => status == OvertimeRequestStatus.cancelled;

  String get durationDisplay {
    if (totalProjects > 1) {
      return "${totalDurationHours.toStringAsFixed(1)} hours total";
    } else {
      double hours = endTime.difference(startTime).inMinutes / 60.0;
      return "${hours.toStringAsFixed(1)} hours";
    }
  }

  String get employeeCountDisplay {
    return "$totalEmployeeCount ${totalEmployeeCount == 1 ? 'employee' : 'employees'}";
  }

  // ✅ FIXED: fromMap with correct parameter order to match your existing code
  factory OvertimeRequest.fromMap(String id, Map<String, dynamic> map) {
    // Parse status
    OvertimeRequestStatus status = OvertimeRequestStatus.pending;
    if (map['status'] != null) {
      switch (map['status'].toString().toLowerCase()) {
        case 'approved':
          status = OvertimeRequestStatus.approved;
          break;
        case 'rejected':
          status = OvertimeRequestStatus.rejected;
          break;
        case 'cancelled':
          status = OvertimeRequestStatus.cancelled;
          break;
        case 'pending':
        default:
          status = OvertimeRequestStatus.pending;
          break;
      }
    }

    // Parse projects
    List<OvertimeProjectEntry> projects = [];
    if (map['projects'] != null && map['projects'] is List) {
      for (var projectData in map['projects']) {
        if (projectData is Map<String, dynamic>) {
          projects.add(OvertimeProjectEntry.fromMap(projectData));
        }
      }
    } else {
      // Create single project from legacy data
      projects.add(OvertimeProjectEntry(
        projectName: map['projectName'] ?? '',
        projectCode: map['projectCode'] ?? '',
        startTime: (map['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        endTime: (map['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        employeeIds: List<String>.from(map['employeeIds'] ?? []),
      ));
    }

    return OvertimeRequest(
      id: id,
      requesterId: map['requesterId'] ?? '',
      requesterName: map['requesterName'] ?? '',
      approverEmpId: map['approverEmpId'] ?? '',
      approverName: map['approverName'] ?? '',
      projectName: map['projectName'] ?? '',
      projectCode: map['projectCode'] ?? '',
      startTime: (map['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (map['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      employeeIds: List<String>.from(map['employeeIds'] ?? []),
      requestTime: (map['requestTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: status,
      responseMessage: map['responseMessage'],
      responseTime: (map['responseTime'] as Timestamp?)?.toDate(),

      // ✅ BACKWARD COMPATIBILITY: Handle old field names
      approvedTime: (map['approvedTime'] as Timestamp?)?.toDate() ??
          (status == OvertimeRequestStatus.approved ? (map['responseTime'] as Timestamp?)?.toDate() : null),
      rejectionReason: map['rejectionReason'] ??
          (status == OvertimeRequestStatus.rejected ? map['responseMessage'] : null),

      // Multi-project fields
      totalProjects: map['totalProjects'] ?? projects.length,
      totalEmployeeCount: map['totalEmployees'] ?? (map['employeeIds'] as List?)?.length ?? 0,
      totalDurationHours: map['totalHours']?.toDouble() ??
          projects.fold(0.0, (sum, p) => sum + p.durationInHours),
      projects: projects,

      // Metadata fields
      createdBy: map['createdBy'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      version: map['version'] ?? 1,
      isActive: map['isActive'] ?? true,
      metadata: map['metadata'],
    );
  }

  // ✅ BACKWARD COMPATIBILITY: Alternative factory method for different parameter order
  factory OvertimeRequest.fromMapAlt(Map<String, dynamic> map, String id) {
    return OvertimeRequest.fromMap(id, map);
  }

  // ✅ ADDED: fromLocalMap method that your repository expects
  factory OvertimeRequest.fromLocalMap(Map<String, dynamic> map) {
    // Parse status
    OvertimeRequestStatus status = OvertimeRequestStatus.pending;
    if (map['status'] != null) {
      switch (map['status'].toString().toLowerCase()) {
        case 'approved':
          status = OvertimeRequestStatus.approved;
          break;
        case 'rejected':
          status = OvertimeRequestStatus.rejected;
          break;
        case 'cancelled':
          status = OvertimeRequestStatus.cancelled;
          break;
        case 'pending':
        default:
          status = OvertimeRequestStatus.pending;
          break;
      }
    }

    return OvertimeRequest(
      id: map['id'] ?? '',
      requesterId: map['requesterId'] ?? '',
      requesterName: map['requesterName'] ?? '',
      approverEmpId: map['approverEmpId'] ?? '',
      approverName: map['approverName'] ?? '',
      projectName: map['projectName'] ?? '',
      projectCode: map['projectCode'] ?? '',
      startTime: map['startTime'] != null
          ? DateTime.parse(map['startTime'])
          : DateTime.now(),
      endTime: map['endTime'] != null
          ? DateTime.parse(map['endTime'])
          : DateTime.now(),
      employeeIds: List<String>.from(map['employeeIds'] ?? []),
      requestTime: map['requestTime'] != null
          ? DateTime.parse(map['requestTime'])
          : DateTime.now(),
      status: status,
      responseMessage: map['responseMessage'],
      responseTime: map['responseTime'] != null
          ? DateTime.parse(map['responseTime'])
          : null,

      // BACKWARD COMPATIBILITY
      approvedTime: map['approvedTime'] != null
          ? DateTime.parse(map['approvedTime'])
          : null,
      rejectionReason: map['rejectionReason'],

      // Multi-project fields
      totalProjects: map['totalProjects'] ?? 1,
      totalEmployeeCount: map['totalEmployeeCount'] ?? 0,
      totalDurationHours: map['totalDurationHours']?.toDouble() ?? 0.0,

      // Metadata
      version: map['version'] ?? 1,
      isActive: map['isActive'] ?? true,
    );
  }

  // ✅ Create from Firestore document
  factory OvertimeRequest.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return OvertimeRequest.fromMap(doc.id, data);
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'requesterId': requesterId,
      'requesterName': requesterName,
      'approverEmpId': approverEmpId,
      'approverName': approverName,
      'projectName': projectName,
      'projectCode': projectCode,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'employeeIds': employeeIds,
      'requestTime': Timestamp.fromDate(requestTime),
      'status': status.value,
      'responseMessage': responseMessage,
      'responseTime': responseTime != null ? Timestamp.fromDate(responseTime!) : null,

      // BACKWARD COMPATIBILITY
      'approvedTime': approvedTime != null ? Timestamp.fromDate(approvedTime!) : null,
      'rejectionReason': rejectionReason,

      // Multi-project fields
      'totalProjects': totalProjects,
      'totalEmployees': totalEmployeeCount,
      'totalHours': totalDurationHours,
      'projects': projects.map((p) => p.toMap()).toList(),

      // Metadata fields
      'createdBy': createdBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'version': version,
      'isActive': isActive,
      'metadata': metadata,
    };
  }

  // Convert to local map (for local database)
  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'approverEmpId': approverEmpId,
      'approverName': approverName,
      'projectName': projectName,
      'projectCode': projectCode,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'employeeIds': employeeIds,
      'requestTime': requestTime.toIso8601String(),
      'status': status.value,
      'responseMessage': responseMessage,
      'responseTime': responseTime?.toIso8601String(),

      // BACKWARD COMPATIBILITY
      'approvedTime': approvedTime?.toIso8601String(),
      'rejectionReason': rejectionReason,

      // Multi-project fields
      'totalProjects': totalProjects,
      'totalEmployeeCount': totalEmployeeCount,
      'totalDurationHours': totalDurationHours,

      // Metadata
      'version': version,
      'isActive': isActive,
    };
  }

  // Copy with method for updates
  OvertimeRequest copyWith({
    String? id,
    String? requesterId,
    String? requesterName,
    String? approverEmpId,
    String? approverName,
    String? projectName,
    String? projectCode,
    DateTime? startTime,
    DateTime? endTime,
    List<String>? employeeIds,
    DateTime? requestTime,
    OvertimeRequestStatus? status,
    String? responseMessage,
    DateTime? responseTime,
    DateTime? approvedTime,
    String? rejectionReason,
    int? totalProjects,
    int? totalEmployeeCount,
    double? totalDurationHours,
    List<OvertimeProjectEntry>? projects,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return OvertimeRequest(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      approverEmpId: approverEmpId ?? this.approverEmpId,
      approverName: approverName ?? this.approverName,
      projectName: projectName ?? this.projectName,
      projectCode: projectCode ?? this.projectCode,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      employeeIds: employeeIds ?? this.employeeIds,
      requestTime: requestTime ?? this.requestTime,
      status: status ?? this.status,
      responseMessage: responseMessage ?? this.responseMessage,
      responseTime: responseTime ?? this.responseTime,
      approvedTime: approvedTime ?? this.approvedTime,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      totalProjects: totalProjects ?? this.totalProjects,
      totalEmployeeCount: totalEmployeeCount ?? this.totalEmployeeCount,
      totalDurationHours: totalDurationHours ?? this.totalDurationHours,
      projects: projects ?? this.projects,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'OvertimeRequest(id: $id, projectName: $projectName, status: ${status.displayName}, totalProjects: $totalProjects, totalEmployees: $totalEmployeeCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OvertimeRequest &&
        other.id == id &&
        other.requesterId == requesterId &&
        other.status == status;
  }

  @override
  int get hashCode {
    return id.hashCode ^ requesterId.hashCode ^ status.hashCode;
  }
}

// ✅ Employee list model for saved lists
class EmployeeList {
  final String id;
  final String requesterId;
  final List<String> employeeIds;
  final Map<String, int> designationBreakdown;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int employeeCount;

  EmployeeList({
    required this.id,
    required this.requesterId,
    required this.employeeIds,
    required this.designationBreakdown,
    required this.createdAt,
    required this.updatedAt,
    required this.employeeCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'requesterId': requesterId,
      'employeeIds': employeeIds,
      'designationBreakdown': designationBreakdown,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'employeeCount': employeeCount,
    };
  }

  factory EmployeeList.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return EmployeeList.fromMap(doc.id, data);
  }

  factory EmployeeList.fromMap(String id, Map<String, dynamic> map) {
    return EmployeeList(
      id: id,
      requesterId: map['requesterId'] ?? '',
      employeeIds: List<String>.from(map['employeeIds'] ?? []),
      designationBreakdown: Map<String, int>.from(map['designationBreakdown'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      employeeCount: map['employeeCount'] ?? 0,
    );
  }
}

// ✅ Overtime statistics model
class OvertimeStatistics {
  final int totalRequests;
  final int pendingRequests;
  final int approvedRequests;
  final int rejectedRequests;
  final int cancelledRequests;
  final double totalHours;
  final Map<String, int> projectBreakdown;
  final Map<String, int> monthlyBreakdown;

  OvertimeStatistics({
    required this.totalRequests,
    required this.pendingRequests,
    required this.approvedRequests,
    required this.rejectedRequests,
    required this.cancelledRequests,
    required this.totalHours,
    required this.projectBreakdown,
    required this.monthlyBreakdown,
  });

  double get approvalRate {
    int totalProcessed = approvedRequests + rejectedRequests;
    if (totalProcessed == 0) return 0.0;
    return (approvedRequests / totalProcessed) * 100;
  }

  String get mostRequestedProject {
    if (projectBreakdown.isEmpty) return 'None';
    return projectBreakdown.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  factory OvertimeStatistics.fromRequests(List<OvertimeRequest> requests) {
    int totalRequests = requests.length;
    int pending = requests.where((r) => r.isPending).length;
    int approved = requests.where((r) => r.isApproved).length;
    int rejected = requests.where((r) => r.isRejected).length;
    int cancelled = requests.where((r) => r.isCancelled).length;

    double totalHours = requests.fold(0.0, (sum, r) => sum + r.totalDurationHours);

    Map<String, int> projectBreakdown = {};
    Map<String, int> monthlyBreakdown = {};

    for (var request in requests) {
      // Project breakdown
      String project = request.totalProjects > 1 ? 'Multi-Project' : request.projectName;
      projectBreakdown[project] = (projectBreakdown[project] ?? 0) + 1;

      // Monthly breakdown
      String month = '${request.requestTime.year}-${request.requestTime.month.toString().padLeft(2, '0')}';
      monthlyBreakdown[month] = (monthlyBreakdown[month] ?? 0) + 1;
    }

    return OvertimeStatistics(
      totalRequests: totalRequests,
      pendingRequests: pending,
      approvedRequests: approved,
      rejectedRequests: rejected,
      cancelledRequests: cancelled,
      totalHours: totalHours,
      projectBreakdown: projectBreakdown,
      monthlyBreakdown: monthlyBreakdown,
    );
  }
}