// lib/debug/debug_data_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phoenician_face_auth/services/database_helper.dart';
import 'package:phoenician_face_auth/services/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phoenician_face_auth/common/utils/custom_snackbar.dart';

class DebugDataScreen extends StatefulWidget {
  final String employeeId;

  const DebugDataScreen({Key? key, required this.employeeId}) : super(key: key);

  @override
  _DebugDataScreenState createState() => _DebugDataScreenState();
}

class _DebugDataScreenState extends State<DebugDataScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  // Database data
  List<Map<String, dynamic>> attendanceData = [];
  List<Map<String, dynamic>> locationData = [];
  List<Map<String, dynamic>> polygonLocationData = [];

  // SharedPreferences data
  Map<String, dynamic> sharedPrefsData = {};

  bool _isLoading = true;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    try {
      await _loadDatabaseData();
      await _loadSharedPreferencesData();
    } catch (e) {
      debugPrint("Error loading debug data: $e");
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadDatabaseData() async {
    try {
      final dbHelper = getIt<DatabaseHelper>();

      // Load attendance data
      final attendance = await dbHelper.query('attendance');

      // Load location data
      final locations = await dbHelper.query('locations');

      // Load polygon location data
      final polygonLocations = await dbHelper.query('polygon_locations');

      setState(() {
        attendanceData = attendance;
        locationData = locations;
        polygonLocationData = polygonLocations;
      });

      debugPrint("✅ Database data loaded:");
      debugPrint("   - Attendance records: ${attendance.length}");
      debugPrint("   - Location records: ${locations.length}");
      debugPrint("   - Polygon location records: ${polygonLocations.length}");

    } catch (e) {
      debugPrint("❌ Error loading database data: $e");
    }
  }

  Future<void> _loadSharedPreferencesData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Set<String> keys = prefs.getKeys();

      Map<String, dynamic> data = {};
      for (String key in keys) {
        var value = prefs.get(key);
        data[key] = value;
      }

      setState(() {
        sharedPrefsData = data;
      });

      debugPrint("✅ SharedPreferences data loaded: ${keys.length} keys");

    } catch (e) {
      debugPrint("❌ Error loading SharedPreferences data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0A0E1A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("🐛 Debug Data Viewer"),
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: _isDarkMode ? Colors.white : Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: _isDarkMode ? Colors.white : Colors.black87,
          unselectedLabelColor: _isDarkMode ? Colors.grey : Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(icon: Icon(Icons.access_time), text: "Attendance"),
            Tab(icon: Icon(Icons.location_on), text: "Locations"),
            Tab(icon: Icon(Icons.hexagon), text: "Polygons"),
            Tab(icon: Icon(Icons.settings), text: "Preferences"),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadAllData,
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
          ),
          IconButton(
            onPressed: _exportAllData,
            icon: const Icon(Icons.download),
            tooltip: "Export Data",
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text("🌙 Toggle Dark Mode"),
                onTap: () => setState(() => _isDarkMode = !_isDarkMode),
              ),
              PopupMenuItem(
                child: const Text("🗑️ Clear All Data"),
                onTap: _showClearDataDialog,
              ),
              PopupMenuItem(
                child: const Text("📊 Database Stats"),
                onTap: _showDatabaseStats,
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildAttendanceTab(),
          _buildLocationsTab(),
          _buildPolygonLocationsTab(),
          _buildSharedPreferencesTab(),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
    return Column(
      children: [
        _buildSectionHeader(
          "📅 Attendance Records",
          attendanceData.length,
          Icons.access_time,
        ),
        Expanded(
          child: attendanceData.isEmpty
              ? _buildEmptyState("No attendance records found")
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: attendanceData.length,
            itemBuilder: (context, index) {
              final record = attendanceData[index];
              return _buildAttendanceCard(record);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLocationsTab() {
    return Column(
      children: [
        _buildSectionHeader(
          "📍 Location Records",
          locationData.length,
          Icons.location_on,
        ),
        Expanded(
          child: locationData.isEmpty
              ? _buildEmptyState("No location records found")
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: locationData.length,
            itemBuilder: (context, index) {
              final record = locationData[index];
              return _buildLocationCard(record);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPolygonLocationsTab() {
    return Column(
      children: [
        _buildSectionHeader(
          "🗺️ Polygon Locations",
          polygonLocationData.length,
          Icons.hexagon,
        ),
        Expanded(
          child: polygonLocationData.isEmpty
              ? _buildEmptyState("No polygon location records found")
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: polygonLocationData.length,
            itemBuilder: (context, index) {
              final record = polygonLocationData[index];
              return _buildPolygonLocationCard(record);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSharedPreferencesTab() {
    return Column(
      children: [
        _buildSectionHeader(
          "⚙️ SharedPreferences",
          sharedPrefsData.length,
          Icons.settings,
        ),
        Expanded(
          child: sharedPrefsData.isEmpty
              ? _buildEmptyState("No preferences found")
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sharedPrefsData.keys.length,
            itemBuilder: (context, index) {
              final key = sharedPrefsData.keys.elementAt(index);
              final value = sharedPrefsData[key];
              return _buildPreferenceCard(key, value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$count items stored locally",
                  style: TextStyle(
                    fontSize: 14,
                    color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: count > 0 ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: count > 0 ? Colors.green : Colors.orange,
              ),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: count > 0 ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "👤 ${record['employee_id'] ?? 'Unknown'}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (record['is_synced'] == 1) ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (record['is_synced'] == 1) ? "✅ Synced" : "⏳ Pending",
                    style: TextStyle(
                      color: (record['is_synced'] == 1) ? Colors.green : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow("📅 Date", record['date']?.toString() ?? 'Not set'),
            _buildDetailRow("🕐 Check In", record['check_in']?.toString() ?? 'Not recorded'),
            _buildDetailRow("🕑 Check Out", record['check_out']?.toString() ?? 'Not recorded'),
            _buildDetailRow("📍 Location", record['location_id']?.toString() ?? 'Unknown'),
            if (record['raw_data'] != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _showRawData("Attendance Raw Data", record['raw_data']),
                icon: const Icon(Icons.data_object, size: 16),
                label: const Text("View Raw Data"),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: (record['is_active'] == 1) ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record['name']?.toString() ?? 'Unnamed Location',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow("📍 Address", record['address']?.toString() ?? 'No address'),
            _buildDetailRow("🌐 Latitude", record['latitude']?.toString() ?? '0.0'),
            _buildDetailRow("🌐 Longitude", record['longitude']?.toString() ?? '0.0'),
            _buildDetailRow("📏 Radius", "${record['radius']?.toString() ?? '0'}m"),
            _buildDetailRow("🏃 Active", (record['is_active'] == 1) ? "Yes" : "No"),
          ],
        ),
      ),
    );
  }

  Widget _buildPolygonLocationCard(Map<String, dynamic> record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record['name']?.toString() ?? 'Unnamed Polygon',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow("📝 Description", record['description']?.toString() ?? 'No description'),
            _buildDetailRow("🌐 Center Lat", record['center_latitude']?.toString() ?? '0.0'),
            _buildDetailRow("🌐 Center Lng", record['center_longitude']?.toString() ?? '0.0'),
            _buildDetailRow("🏃 Active", (record['is_active'] == 1) ? "Yes" : "No"),
            if (record['coordinates'] != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _showRawData("Polygon Coordinates", record['coordinates']),
                icon: const Icon(Icons.hexagon, size: 16),
                label: const Text("View Coordinates"),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceCard(String key, dynamic value) {
    String displayValue = value.toString();
    if (displayValue.length > 100) {
      displayValue = displayValue.substring(0, 100) + "...";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    key,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _copyToClipboard(key, value.toString()),
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: "Copy Value",
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                displayValue,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: _isDarkMode ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ),
            if (value.toString().length > 100) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _showRawData("Preference: $key", value.toString()),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text("View Full Value"),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: _isDarkMode ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadAllData,
            icon: const Icon(Icons.refresh),
            label: const Text("Refresh"),
          ),
        ],
      ),
    );
  }

  void _showRawData(String title, String data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          title,
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                data,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: _isDarkMode ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _copyToClipboard(title, data),
            child: const Text("Copy"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String title, String data) {
    Clipboard.setData(ClipboardData(text: data));
    CustomSnackBar.successSnackBar(context, "Copied to clipboard: $title");
  }

  void _exportAllData() async {
    try {
      Map<String, dynamic> allData = {
        'export_timestamp': DateTime.now().toIso8601String(),
        'employee_id': widget.employeeId,
        'database_data': {
          'attendance': attendanceData,
          'locations': locationData,
          'polygon_locations': polygonLocationData,
        },
        'shared_preferences': sharedPrefsData,
        'stats': {
          'total_attendance_records': attendanceData.length,
          'total_location_records': locationData.length,
          'total_polygon_records': polygonLocationData.length,
          'total_preferences': sharedPrefsData.length,
        }
      };

      String jsonData = const JsonEncoder.withIndent('  ').convert(allData);

      await Clipboard.setData(ClipboardData(text: jsonData));

      CustomSnackBar.successSnackBar(context, "✅ All data exported to clipboard!");

      print("=== EXPORTED DATA ===");
      print(jsonData);

    } catch (e) {
      CustomSnackBar.errorSnackBar(context, "❌ Export failed: $e");
    }
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              "⚠️ Clear All Data",
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: const Text(
          "This will permanently delete ALL local data including attendance records, locations, and preferences. This action cannot be undone!\n\nAre you sure?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Clear All Data", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _clearAllData() async {
    try {
      final dbHelper = getIt<DatabaseHelper>();

      // Clear database tables
      await dbHelper.delete('attendance');
      await dbHelper.delete('locations');
      await dbHelper.delete('polygon_locations');

      // Clear SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Reload data
      await _loadAllData();

      CustomSnackBar.successSnackBar(context, "🗑️ All local data cleared!");

    } catch (e) {
      CustomSnackBar.errorSnackBar(context, "❌ Failed to clear data: $e");
    }
  }

  void _showDatabaseStats() {
    int totalRecords = attendanceData.length + locationData.length + polygonLocationData.length;
    int syncedAttendance = attendanceData.where((r) => r['is_synced'] == 1).length;
    int pendingAttendance = attendanceData.length - syncedAttendance;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.analytics, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              "📊 Database Statistics",
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow("Total Records", totalRecords.toString()),
            _buildStatRow("Attendance Records", attendanceData.length.toString()),
            _buildStatRow("- Synced", syncedAttendance.toString()),
            _buildStatRow("- Pending Sync", pendingAttendance.toString()),
            _buildStatRow("Location Records", locationData.length.toString()),
            _buildStatRow("Polygon Records", polygonLocationData.length.toString()),
            _buildStatRow("Preferences", sharedPrefsData.length.toString()),
            const Divider(),
            _buildStatRow("Employee ID", widget.employeeId),
            _buildStatRow("Last Refresh", DateTime.now().toString().split('.')[0]),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}