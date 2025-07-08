// lib/admin/polygon_map_view.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:phoenician_face_auth/model/polygon_location_model.dart';
import 'package:phoenician_face_auth/repositories/polygon_location_repository.dart';
import 'package:phoenician_face_auth/services/service_locator.dart';
import 'package:phoenician_face_auth/constants/theme.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geodesy/geodesy.dart' as geodesy;
import 'dart:math' show Random;
import 'package:phoenician_face_auth/admin/geojson_importer_view.dart';
import 'package:phoenician_face_auth/admin/map_navigation.dart'; // Add this import


class PolygonMapView extends StatefulWidget {
  const PolygonMapView({Key? key}) : super(key: key);

  @override
  State<PolygonMapView> createState() => _PolygonMapViewState();
}

class _PolygonMapViewState extends State<PolygonMapView> {
  GoogleMapController? _mapController;
  List<PolygonLocationModel> _locations = [];
  bool _isLoading = true;
  Position? _currentPosition;

  // Map elements
  final Set<Polygon> _polygons = {};
  final Set<Marker> _markers = {};

  // Random color generator for polygons
  final Random _random = Random();

  // Get a random color for polygons
  Color _getRandomColor() {
    return Color.fromRGBO(
      _random.nextInt(200) + 50, // Avoid too dark colors
      _random.nextInt(200) + 50,
      _random.nextInt(200) + 50,
      0.5, // Semi-transparent
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Get current location
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get polygon locations
      final repository = getIt<PolygonLocationRepository>();
      final locations = await repository.getActivePolygonLocations();

      // Create polygon objects
      final polygons = <Polygon>{};
      final markers = <Marker>{};

      for (var i = 0; i < locations.length; i++) {
        final location = locations[i];
        final polygonId = 'polygon_${location.id}';

        // Convert geodesy LatLng to Google Maps LatLng
        final List<LatLng> points = location.coordinates.map((point) =>
            LatLng(point.latitude, point.longitude)
        ).toList();

        // Skip if less than 3 points (not a valid polygon)
        if (points.length < 3) continue;

        // Create polygon
        final polygon = Polygon(
          polygonId: PolygonId(polygonId),
          points: points,
          strokeWidth: 2,
          strokeColor: Colors.blue,
          fillColor: _getRandomColor(),
          consumeTapEvents: true,
          onTap: () {
            _showPolygonInfo(location);
          },
        );

        polygons.add(polygon);

        // Add marker at the center of the polygon
        final marker = Marker(
          markerId: MarkerId('marker_${location.id}'),
          position: LatLng(location.centerLatitude, location.centerLongitude),
          infoWindow: InfoWindow(
            title: location.name,
            snippet: location.description,
          ),
        );

        markers.add(marker);
      }

      // Add current location marker
      if (_currentPosition != null) {
        markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: const InfoWindow(
              title: 'Your Location',
              snippet: 'This is your current position',
            ),
          ),
        );
      }

      setState(() {
        _locations = locations;
        _polygons.clear();
        _polygons.addAll(polygons);
        _markers.clear();
        _markers.addAll(markers);
        _isLoading = false;
      });

      // Move camera to current location or first polygon
      if (_mapController != null) {
        if (_currentPosition != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              14.0,
            ),
          );
        } else if (locations.isNotEmpty) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(locations[0].centerLatitude, locations[0].centerLongitude),
              14.0,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading polygon data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showPolygonInfo(PolygonLocationModel location) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              location.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              location.description,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              'Polygon has ${location.coordinates.length} points',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (_currentPosition != null) ...[
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'You are ${_isWithinPolygon(location) ? "INSIDE" : "OUTSIDE"} this boundary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isWithinPolygon(location) ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Distance: ${_getDistanceToPolygon(location).toStringAsFixed(0)} meters',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isWithinPolygon(PolygonLocationModel location) {
    if (_currentPosition == null) return false;

    return location.containsPoint(
        _currentPosition!.latitude,
        _currentPosition!.longitude
    );
  }

  double _getDistanceToPolygon(PolygonLocationModel location) {
    if (_currentPosition == null) return double.infinity;

    return location.distanceToPolygon(
        _currentPosition!.latitude,
        _currentPosition!.longitude
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Boundaries'),
        backgroundColor: appBarColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Reload Data',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(25.0, 55.0), // Default to Dubai
              zoom: 10,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapType: MapType.normal,
            polygons: _polygons,
            markers: _markers,
            onMapCreated: (controller) {
              _mapController = controller;

              // Move camera to current location or first polygon
              if (_currentPosition != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    14.0,
                  ),
                );
              } else if (_locations.isNotEmpty) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(_locations[0].centerLatitude, _locations[0].centerLongitude),
                    14.0,
                  ),
                );
              }
            },
          ),

          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: accentColor),
              ),
            ),

          // Instructions
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tap on a polygon to view details',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_locations.length} project boundaries loaded',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                    if (_currentPosition != null)
                      _getLocationStatusWidget(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          navigateToGeoJsonImporterView(context);
        },
        label: const Text('Import GeoJSON'),
        icon: const Icon(Icons.add_location_alt),
        backgroundColor: accentColor,
      ),
    );
  }

  Widget _getLocationStatusWidget() {
    // Find if we're inside any polygons
    PolygonLocationModel? containingPolygon;
    for (var location in _locations) {
      if (_isWithinPolygon(location)) {
        containingPolygon = location;
        break;
      }
    }

    if (containingPolygon != null) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 16),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'You are within: ${containingPolygon.name}',
                style: const TextStyle(color: Colors.green),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.red, size: 16),
            SizedBox(width: 4),
            Text(
              'You are not within any project boundary',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
      );
    }
  }
}