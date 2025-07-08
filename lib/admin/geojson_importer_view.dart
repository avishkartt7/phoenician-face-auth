// lib/admin/geojson_importer_view.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phoenician_face_auth/constants/theme.dart';
import 'package:phoenician_face_auth/utils/enhanced_geofence_util.dart';
import 'package:phoenician_face_auth/common/utils/custom_snackbar.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:phoenician_face_auth/admin/polygon_map_view.dart';
import 'package:phoenician_face_auth/repositories/polygon_location_repository.dart';
import 'package:phoenician_face_auth/services/service_locator.dart';
import 'package:flutter/material.dart';

import 'package:phoenician_face_auth/utils/enhanced_geofence_util.dart';
import 'package:phoenician_face_auth/common/utils/custom_snackbar.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:phoenician_face_auth/admin/map_navigation.dart'; // Add this import


class GeoJsonImporterView extends StatefulWidget {
  const GeoJsonImporterView({Key? key}) : super(key: key);

  @override
  State<GeoJsonImporterView> createState() => _GeoJsonImporterViewState();
}

class _GeoJsonImporterViewState extends State<GeoJsonImporterView> {
  final TextEditingController _geoJsonController = TextEditingController();
  bool _isLoading = false;
  bool _isImported = false;
  String _importedInfo = '';
  List<dynamic> _locations = [];

  @override
  void initState() {
    super.initState();
    _checkExistingLocations();
  }

  Future<void> _checkExistingLocations() async {
    try {
      final repository = getIt<PolygonLocationRepository>();
      final existingLocations = await repository.getActivePolygonLocations();

      setState(() {
        _locations = existingLocations;
      });
    } catch (e) {
      debugPrint('Error checking existing locations: $e');
    }
  }

  @override
  void dispose() {
    _geoJsonController.dispose();
    super.dispose();
  }

  Future<void> _importFromText() async {
    final String geoJsonText = _geoJsonController.text;

    if (geoJsonText.isEmpty) {
      CustomSnackBar.errorSnackBar(context, 'Please enter GeoJSON data');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Validate JSON format
      json.decode(geoJsonText);

      // Import using our utility
      final bool success = await EnhancedGeofenceUtil.importGeoJsonData(context, geoJsonText);

      setState(() {
        _isLoading = false;
        _isImported = success;

        if (success) {
          try {
            final Map<String, dynamic> data = json.decode(geoJsonText);
            final features = data['features'] as List;

            final List<String> locationNames = [];
            for (var feature in features) {
              if (feature['properties'] != null && feature['properties']['name'] != null) {
                locationNames.add(feature['properties']['name']);
              }
            }

            _importedInfo = 'Imported ${features.length} polygons:\n${locationNames.join(", ")}';
            _checkExistingLocations(); // Refresh the locations list
          } catch (e) {
            _importedInfo = 'Import successful, but could not parse location details';
          }
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      CustomSnackBar.errorSnackBar(context, 'Invalid GeoJSON format: $e');
    }
  }

  Future<void> _importFromFile() async {
    setState(() => _isLoading = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'geojson'],
      );

      if (result != null) {
        String fileContent;

        // Handle web platform
        if (result.files.single.bytes != null) {
          fileContent = utf8.decode(result.files.single.bytes!);
        }
        // Handle mobile platform
        else if (result.files.single.path != null) {
          final file = File(result.files.single.path!);
          fileContent = await file.readAsString();
        } else {
          CustomSnackBar.errorSnackBar(context, 'Could not read file');
          setState(() => _isLoading = false);
          return;
        }

        // Set the content to the text field
        _geoJsonController.text = fileContent;

        // Validate JSON format
        json.decode(fileContent);

        // Import using our utility
        final bool success = await EnhancedGeofenceUtil.importGeoJsonData(context, fileContent);

        setState(() {
          _isLoading = false;
          _isImported = success;

          if (success) {
            try {
              final Map<String, dynamic> data = json.decode(fileContent);
              final features = data['features'] as List;

              final List<String> locationNames = [];
              for (var feature in features) {
                if (feature['properties'] != null && feature['properties']['name'] != null) {
                  locationNames.add(feature['properties']['name']);
                }
              }

              _importedInfo = 'Imported ${features.length} polygons:\n${locationNames.join(", ")}';
              _checkExistingLocations(); // Refresh the locations list
            } catch (e) {
              _importedInfo = 'Import successful, but could not parse location details';
            }
          }
        });
      } else {
        // User canceled the file picking
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      CustomSnackBar.errorSnackBar(context, 'Error importing file: $e');
    }
  }

  Widget _buildViewPolygonsButton() {
    return ElevatedButton.icon(
      onPressed: () {
        navigateToPolygonMapView(context);
      },
      icon: const Icon(Icons.map),
      label: const Text('View Project Boundaries'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GeoJSON Importer'),
        backgroundColor: appBarColor,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                color: Colors.white.withOpacity(0.9),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Import GeoJSON Polygon Boundaries',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Paste GeoJSON data or import from a file to set up precise polygon boundaries for your project locations.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _geoJsonController,
                          maxLines: 10,
                          decoration: const InputDecoration(
                            hintText: 'Paste GeoJSON data here...',
                            contentPadding: EdgeInsets.all(12),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _importFromFile,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Import from File'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _importFromText,
                            icon: const Icon(Icons.check),
                            label: const Text('Import GeoJSON'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      if (_isImported && _importedInfo.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text(
                                    'Import Successful',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(_importedInfo),
                            ],
                          ),
                        ),

                      // Add the View Polygons button if we have locations or just imported
                      if (_locations.isNotEmpty || _isImported)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: _buildViewPolygonsButton(),
                        ),
                    ],
                  ),
                ),
              ),

              // Show existing locations summary
              if (_locations.isNotEmpty)
                Card(
                  elevation: 4,
                  color: Colors.white.withOpacity(0.9),
                  margin: const EdgeInsets.only(top: 16.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Existing Project Boundaries',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You have ${_locations.length} project boundaries defined:',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._locations.map((location) => ListTile(
                          leading: const Icon(Icons.map, color: Colors.indigo),
                          title: Text(location.name),
                          subtitle: Text(
                            '${location.coordinates.length} boundary points',
                            style: TextStyle(fontSize: 12),
                          ),
                          dense: true,
                        )).toList(),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),
              Card(
                elevation: 4,
                color: Colors.white.withOpacity(0.9),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'How to Create GeoJSON Polygons',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const ListTile(
                        leading: CircleAvatar(child: Text('1')),
                        title: Text('Use Google My Maps'),
                        subtitle: Text('Create polygon shapes for your project areas'),
                      ),
                      const ListTile(
                        leading: CircleAvatar(child: Text('2')),
                        title: Text('Export as KML file'),
                        subtitle: Text('Download your map data as KML'),
                      ),
                      const ListTile(
                        leading: CircleAvatar(child: Text('3')),
                        title: Text('Convert KML to GeoJSON'),
                        subtitle: Text('Use online converter or desktop GIS tools'),
                      ),
                      const ListTile(
                        leading: CircleAvatar(child: Text('4')),
                        title: Text('Import the GeoJSON'),
                        subtitle: Text('Paste or upload the converted file here'),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          // Copy example GeoJSON to clipboard
                          Clipboard.setData(const ClipboardData(text: '''
{
    "type": "FeatureCollection", 
    "features": [
        {
            "type": "Feature", 
            "geometry": {
                "type": "Polygon", 
                "coordinates": [
                    [
                        [55.1757624, 24.9838472, 0], 
                        [55.1762452, 24.9836138, 0], 
                        [55.1770820, 24.9841049, 0], 
                        [55.1753118, 24.9863854, 0], 
                        [55.1749953, 24.9863416, 0], 
                        [55.1744910, 24.9858991, 0], 
                        [55.1744105, 24.9855734, 0], 
                        [55.1744052, 24.9853448, 0], 
                        [55.1747270, 24.9851066, 0], 
                        [55.1751079, 24.9850434, 0], 
                        [55.1752581, 24.9848975, 0], 
                        [55.1753439, 24.9847176, 0], 
                        [55.1753278, 24.9844939, 0], 
                        [55.1753815, 24.9843383, 0], 
                        [55.1757624, 24.9838472, 0]  
                    ]
                ]
            }, 
            "properties": {
                "name": "HOOFFICE", 
                "description": "PTS CO POINTS", 
                "styleUrl": "#poly-880E4F-1200-77", 
                "fill-opacity": 0.30196078431372547, 
                "fill": "#880e4f", 
                "stroke-opacity": 1, 
                "stroke": "#880e4f", 
                "stroke-width": 1.2
            }
        }
    ]
}


      
'''));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Example GeoJSON copied to clipboard'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Example GeoJSON'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}