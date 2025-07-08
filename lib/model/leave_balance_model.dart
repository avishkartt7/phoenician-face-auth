// lib/model/leave_balance_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveBalance {
  final String employeeId;
  final int year;
  final Map<String, int> totalDays;
  final Map<String, int> usedDays;
  final Map<String, int> pendingDays;
  final DateTime? lastUpdated;

  const LeaveBalance({
    required this.employeeId,
    required this.year,
    required this.totalDays,
    required this.usedDays,
    required this.pendingDays,
    this.lastUpdated,
  });

  // Create default leave balance for a new employee with updated allocations
  factory LeaveBalance.createDefault(String employeeId, {int? year}) {
    final currentYear = year ?? DateTime.now().year;

    return LeaveBalance(
      employeeId: employeeId,
      year: currentYear,
      totalDays: {
        'annual': 30,        // 30 days annual leave
        'sick': 15,          // 15 days sick leave
        'maternity': 60,     // 10 days maternity leave
        'paternity': 5,     // 10 days paternity leave
        'emergency': 15,     // 10 days emergency leave
        'compensate': 5,     // Compensate leave (earned)
        'unpaid': 0,         // Unpaid leave (unlimited)
      },
      usedDays: {
        'annual': 0,
        'sick': 0,
        'maternity': 0,
        'paternity': 0,
        'emergency': 0,
        'compensate': 0,
        'unpaid': 0,
      },
      pendingDays: {
        'annual': 0,
        'sick': 0,
        'maternity': 0,
        'paternity': 0,
        'emergency': 0,
        'compensate': 0,
        'unpaid': 0,
      },
      lastUpdated: DateTime.now(),
    );
  }

  // Create from Firestore document
  factory LeaveBalance.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return LeaveBalance(
      employeeId: data['employeeId'] ?? '',
      year: data['year'] ?? DateTime.now().year,
      totalDays: Map<String, int>.from(data['totalDays'] ?? {}),
      usedDays: Map<String, int>.from(data['usedDays'] ?? {}),
      pendingDays: Map<String, int>.from(data['pendingDays'] ?? {}),
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] as Timestamp).toDate()
          : null,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'year': year,
      'totalDays': totalDays,
      'usedDays': usedDays,
      'pendingDays': pendingDays,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  // Get remaining days for a specific leave type
  int getRemainingDays(String leaveType) {
    final total = totalDays[leaveType] ?? 0;
    final used = usedDays[leaveType] ?? 0;
    final pending = pendingDays[leaveType] ?? 0;

    // For unlimited leave types (unpaid), return a large number
    if (leaveType == 'unpaid') {
      return 999;
    }

    return total - used - pending;
  }

  // Check if employee has enough balance for requested days
  bool hasEnoughBalance(String leaveType, int requestedDays) {
    // Unlimited leave types
    if (leaveType == 'unpaid') {
      return true;
    }

    // Sick and emergency leave have special rules but still check balance
    if (leaveType == 'sick' || leaveType == 'emergency') {
      final remaining = getRemainingDays(leaveType);
      return remaining >= requestedDays;
    }

    final remaining = getRemainingDays(leaveType);
    return remaining >= requestedDays;
  }

  // Add used days (when leave is approved) and remove from pending
  LeaveBalance approveLeave(String leaveType, int days) {
    final newUsedDays = Map<String, int>.from(usedDays);
    final newPendingDays = Map<String, int>.from(pendingDays);

    // Add to used days
    newUsedDays[leaveType] = (newUsedDays[leaveType] ?? 0) + days;

    // Remove from pending days
    newPendingDays[leaveType] = (newPendingDays[leaveType] ?? 0) - days;
    if (newPendingDays[leaveType]! < 0) {
      newPendingDays[leaveType] = 0;
    }

    return LeaveBalance(
      employeeId: employeeId,
      year: year,
      totalDays: totalDays,
      usedDays: newUsedDays,
      pendingDays: newPendingDays,
      lastUpdated: DateTime.now(),
    );
  }

  // Add pending days (when leave is applied)
  LeaveBalance addPendingDays(String leaveType, int days) {
    final newPendingDays = Map<String, int>.from(pendingDays);
    newPendingDays[leaveType] = (newPendingDays[leaveType] ?? 0) + days;

    return LeaveBalance(
      employeeId: employeeId,
      year: year,
      totalDays: totalDays,
      usedDays: usedDays,
      pendingDays: newPendingDays,
      lastUpdated: DateTime.now(),
    );
  }

  // Remove pending days (when leave is rejected/cancelled)
  LeaveBalance removePendingDays(String leaveType, int days) {
    final newPendingDays = Map<String, int>.from(pendingDays);
    newPendingDays[leaveType] = (newPendingDays[leaveType] ?? 0) - days;

    // Ensure pending days don't go negative
    if (newPendingDays[leaveType]! < 0) {
      newPendingDays[leaveType] = 0;
    }

    return LeaveBalance(
      employeeId: employeeId,
      year: year,
      totalDays: totalDays,
      usedDays: usedDays,
      pendingDays: newPendingDays,
      lastUpdated: DateTime.now(),
    );
  }

  // Add compensate leave days (earned overtime compensation)
  LeaveBalance addCompensateDays(int days) {
    final newTotalDays = Map<String, int>.from(totalDays);
    newTotalDays['compensate'] = (newTotalDays['compensate'] ?? 0) + days;

    return LeaveBalance(
      employeeId: employeeId,
      year: year,
      totalDays: newTotalDays,
      usedDays: usedDays,
      pendingDays: pendingDays,
      lastUpdated: DateTime.now(),
    );
  }

  // Get summary of all leave types
  Map<String, Map<String, int>> getSummary() {
    final summary = <String, Map<String, int>>{};

    for (String leaveType in totalDays.keys) {
      final total = totalDays[leaveType] ?? 0;
      final used = usedDays[leaveType] ?? 0;
      final pending = pendingDays[leaveType] ?? 0;
      final remaining = total - used - pending;

      summary[leaveType] = {
        'total': total,
        'used': used,
        'pending': pending,
        'remaining': remaining < 0 ? 0 : remaining,
      };
    }

    return summary;
  }

  // Get total days taken this year
  int getTotalDaysTaken() {
    return usedDays.values.fold(0, (sum, days) => sum + days);
  }

  // Get total pending days
  int getTotalPendingDays() {
    return pendingDays.values.fold(0, (sum, days) => sum + days);
  }

  // Check if this is a new balance (no days used yet)
  bool get isNew {
    return getTotalDaysTaken() == 0 && getTotalPendingDays() == 0;
  }

  // Copy with updated values
  LeaveBalance copyWith({
    String? employeeId,
    int? year,
    Map<String, int>? totalDays,
    Map<String, int>? usedDays,
    Map<String, int>? pendingDays,
    DateTime? lastUpdated,
  }) {
    return LeaveBalance(
      employeeId: employeeId ?? this.employeeId,
      year: year ?? this.year,
      totalDays: totalDays ?? this.totalDays,
      usedDays: usedDays ?? this.usedDays,
      pendingDays: pendingDays ?? this.pendingDays,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() {
    return 'LeaveBalance(employeeId: $employeeId, year: $year, totalTaken: ${getTotalDaysTaken()})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LeaveBalance &&
        other.employeeId == employeeId &&
        other.year == year;
  }

  @override
  int get hashCode {
    return employeeId.hashCode ^ year.hashCode;
  }
}