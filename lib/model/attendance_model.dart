// lib/model/attendance_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceRecord {
  final String date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String location;
  final String workStatus;
  final double totalHours;
  final double regularHours;
  final double overtimeHours;
  final bool isWithinGeofence;
  final Map<String, dynamic> rawData;

  AttendanceRecord({
    required this.date,
    this.checkIn,
    this.checkOut,
    required this.location,
    required this.workStatus,
    required this.totalHours,
    required this.regularHours,
    required this.overtimeHours,
    required this.isWithinGeofence,
    required this.rawData,
  });

  factory AttendanceRecord.fromFirestore(Map<String, dynamic> data) {
    DateTime? checkIn;
    DateTime? checkOut;

    if (data['checkIn'] != null) {
      checkIn = (data['checkIn'] as Timestamp).toDate();
    }

    if (data['checkOut'] != null) {
      checkOut = (data['checkOut'] as Timestamp).toDate();
    }

    // Calculate hours
    double totalHours = 0.0;
    double overtimeHours = 0.0;
    double regularHours = 0.0;

    if (checkIn != null && checkOut != null) {
      Duration workDuration = checkOut.difference(checkIn);
      totalHours = workDuration.inMinutes / 60.0;

      // Standard work day is 8 hours
      const double standardWorkHours = 8.0;

      if (totalHours > standardWorkHours) {
        regularHours = standardWorkHours;
        overtimeHours = totalHours - standardWorkHours;
      } else {
        regularHours = totalHours;
        overtimeHours = 0.0;
      }
    }

    // Override with stored overtime hours if available
    if (data.containsKey('overtimeHours')) {
      overtimeHours = (data['overtimeHours'] ?? 0.0).toDouble();
    }

    return AttendanceRecord(
      date: data['date'] ?? '',
      checkIn: checkIn,
      checkOut: checkOut,
      location: data['location'] ?? 'Unknown',
      workStatus: data['workStatus'] ?? 'Unknown',
      totalHours: totalHours,
      regularHours: regularHours,
      overtimeHours: overtimeHours,
      isWithinGeofence: data['isWithinGeofence'] ?? false,
      rawData: data,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'checkIn': checkIn?.toIso8601String(),
      'checkOut': checkOut?.toIso8601String(),
      'location': location,
      'workStatus': workStatus,
      'totalHours': totalHours,
      'regularHours': regularHours,
      'overtimeHours': overtimeHours,
      'isWithinGeofence': isWithinGeofence,
      'rawData': rawData,
    };
  }

  // Helper methods
  bool get hasCheckIn => checkIn != null;
  bool get hasCheckOut => checkOut != null;
  bool get isCompleteDay => hasCheckIn && hasCheckOut;
  bool get hasOvertime => overtimeHours > 0;

  String get formattedCheckIn => hasCheckIn
      ? DateFormat('HH:mm').format(checkIn!)
      : '-';

  String get formattedCheckOut => hasCheckOut
      ? DateFormat('HH:mm').format(checkOut!)
      : '-';

  String get formattedTotalHours => totalHours > 0
      ? '${totalHours.toStringAsFixed(1)}h'
      : '-';

  String get formattedOvertimeHours => overtimeHours > 0
      ? '${overtimeHours.toStringAsFixed(1)}h'
      : '-';

  String get formattedDate {
    try {
      DateTime dateTime = DateFormat('yyyy-MM-dd').parse(date);
      return DateFormat('MMM dd, yyyy').format(dateTime);
    } catch (e) {
      return date;
    }
  }

  String get dayOfWeek {
    try {
      DateTime dateTime = DateFormat('yyyy-MM-dd').parse(date);
      return DateFormat('EEE').format(dateTime);
    } catch (e) {
      return '';
    }
  }
}

// Monthly summary class
class MonthlyAttendanceSummary {
  final String month;
  final int totalDays;
  final double totalWorkHours;
  final double totalOvertimeHours;
  final int daysWithOvertime;
  final List<AttendanceRecord> records;

  MonthlyAttendanceSummary({
    required this.month,
    required this.totalDays,
    required this.totalWorkHours,
    required this.totalOvertimeHours,
    required this.daysWithOvertime,
    required this.records,
  });

  factory MonthlyAttendanceSummary.fromRecords(
      String month,
      List<AttendanceRecord> records,
      ) {
    int totalDays = records.length;
    double totalWorkHours = 0;
    double totalOvertimeHours = 0;
    int daysWithOvertime = 0;

    for (var record in records) {
      totalWorkHours += record.totalHours;
      totalOvertimeHours += record.overtimeHours;
      if (record.hasOvertime) daysWithOvertime++;
    }

    return MonthlyAttendanceSummary(
      month: month,
      totalDays: totalDays,
      totalWorkHours: totalWorkHours,
      totalOvertimeHours: totalOvertimeHours,
      daysWithOvertime: daysWithOvertime,
      records: records,
    );
  }

  double get averageHoursPerDay => totalDays > 0 ? totalWorkHours / totalDays : 0.0;
  double get averageOvertimePerDay => totalDays > 0 ? totalOvertimeHours / totalDays : 0.0;
  double get overtimePercentage => totalDays > 0 ? (daysWithOvertime / totalDays) * 100 : 0.0;
}