// lib/utils/enhanced_geofence_util.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phoenician_face_auth/model/location_model.dart';
import 'package:phoenician_face_auth/model/polygon_location_model.dart';
import 'package:geodesy/geodesy.dart';
import 'package:phoenician_face_auth/repositories/polygon_location_repository.dart';
import 'package:phoenician_face_auth/repositories/location_repository.dart';
import 'package:phoenician_face_auth/services/service_locator.dart';
import 'dart:math' show sqrt, cos, pi;

class EnhancedGeofenceUtil {
  // Check location permissions
  static Future<bool> checkLocationPermission(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location services are disabled. Please enable the services'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    // Check location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are denied'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permissions are permanently denied, please enable them in app settings',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    // Permissions are granted
    return true;
  }

  // Get current position
  static Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }

  /// Check geofence status using both circular and polygon locations
  static Future<Map<String, dynamic>> checkGeofenceStatus(BuildContext context) async {
    bool hasPermission = await checkLocationPermission(context);
    if (!hasPermission) {
      return {
        'withinGeofence': false,
        'location': null,
        'distance': null,
        'locationType': null,
      };
    }

    Position? currentPosition = await getCurrentPosition();
    if (currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get current location'),
          backgroundColor: Colors.red,
        ),
      );
      return {
        'withinGeofence': false,
        'location': null,
        'distance': null,
        'locationType': null,
      };
    }

    debugPrint('LOCATION CHECK:');
    debugPrint('Current position: ${currentPosition.latitude}, ${currentPosition.longitude}');

    // IMPORTANT: Always check polygon locations first and give them priority
    debugPrint('Checking polygon locations first...');
    final polygonResult = await _checkPolygonLocations(context, currentPosition);

    // Always log the polygon result for debugging
    if (polygonResult['location'] != null) {
      final polygonLocation = polygonResult['location'] as PolygonLocationModel;
      debugPrint('Nearest polygon: ${polygonLocation.name}, distance: ${polygonResult['distance']}m, within: ${polygonResult['withinGeofence']}');
    } else {
      debugPrint('No polygon locations found or error occurred');
    }

    // If we're inside a polygon, return that result IMMEDIATELY
    if (polygonResult['withinGeofence'] == true) {
      debugPrint('User is INSIDE polygon: ${(polygonResult['location'] as PolygonLocationModel).name} - STOPPING HERE');
      return polygonResult;
    }

    // Only check circular locations if we're not inside any polygon
    debugPrint('Not inside any polygon, checking circular locations...');
    final circularResult = await _checkCircularLocations(context, currentPosition);

    // Log the circular result too
    if (circularResult['location'] != null) {
      final circularLocation = circularResult['location'] as LocationModel;
      debugPrint('Nearest circular location: ${circularLocation.name}, distance: ${circularResult['distance']}m, within: ${circularResult['withinGeofence']}');
    } else {
      debugPrint('No circular locations found or error occurred');
    }

    // If we're within a circular geofence, return that result
    if (circularResult['withinGeofence'] == true) {
      debugPrint('User is INSIDE circular geofence - using this result');
      return circularResult;
    }

    // If we're not in any geofence, return the closest one
    // IMPORTANT: Always prefer polygon if distances are similar
    final polygonDistance = polygonResult['distance'] as double?;
    final circularDistance = circularResult['distance'] as double?;

    debugPrint('Not inside any boundary, comparing distances:');
    debugPrint('Polygon distance: $polygonDistance, Circular distance: $circularDistance');

    // Give polygon a slight advantage (multiply circular distance by 1.1)
    if (polygonDistance != null && circularDistance != null) {
      if (polygonDistance < circularDistance * 1.1) {
        debugPrint('Polygon is closer or similar distance - using polygon result');
        return polygonResult;
      } else {
        debugPrint('Circular is significantly closer - using circular result');
        return circularResult;
      }
    } else if (polygonDistance != null) {
      debugPrint('Only polygon distance available - using polygon result');
      return polygonResult;
    } else if (circularDistance != null) {
      debugPrint('Only circular distance available - using circular result');
      return circularResult;
    }

    // If no locations found at all, return a default result
    debugPrint('No locations found at all');
    return {
      'withinGeofence': false,
      'location': null,
      'distance': null,
      'locationType': null,
    };
  }

  // Check polygon locations
  static Future<Map<String, dynamic>> _checkPolygonLocations(BuildContext context, Position currentPosition) async {
    try {
      // Get polygon repository
      final repository = getIt<PolygonLocationRepository>();
      final List<PolygonLocationModel> locations = await repository.getActivePolygonLocations();

      if (locations.isEmpty) {
        print('No polygon locations found');
        return {
          'withinGeofence': false,
          'location': null,
          'distance': null,
          'locationType': 'polygon',
        };
      }

      print('Found ${locations.length} polygon locations');

      // Check if the current position is inside any polygon
      PolygonLocationModel? containingLocation;
      double? shortestDistance;
      PolygonLocationModel? closestLocation;

      for (var location in locations) {
        print('Checking polygon: ${location.name}, coordinates: ${location.coordinates.length} points');

        // Check if inside this polygon
        if (location.containsPoint(currentPosition.latitude, currentPosition.longitude)) {
          print('User is INSIDE polygon: ${location.name}');
          // We're inside this polygon
          return {
            'withinGeofence': true,
            'location': location,
            'distance': 0.0,
            'locationType': 'polygon',
          };
        }

        // For now, just use a simple approximation for distance
        // Calculate distance to center point
        double distanceToCenter = Geolocator.distanceBetween(
            currentPosition.latitude,
            currentPosition.longitude,
            location.centerLatitude,
            location.centerLongitude
        );

        print('Distance to center of ${location.name}: ${distanceToCenter.toStringAsFixed(2)}m');

        // Update closest location
        if (shortestDistance == null || distanceToCenter < shortestDistance) {
          shortestDistance = distanceToCenter;
          closestLocation = location;
        }
      }

      // Not inside any polygon, return closest one
      return {
        'withinGeofence': false,
        'location': closestLocation,
        'distance': shortestDistance,
        'locationType': 'polygon',
      };
    } catch (e) {
      print('Error checking polygon locations: $e');
      return {
        'withinGeofence': false,
        'location': null,
        'distance': null,
        'locationType': 'polygon',
      };
    }
  }

  // Check circular locations
  static Future<Map<String, dynamic>> _checkCircularLocations(BuildContext context, Position currentPosition) async {
    try {
      // Get traditional circular locations
      final locationRepository = getIt<LocationRepository>();
      final List<LocationModel> locations = await locationRepository.getActiveLocations();

      if (locations.isEmpty) {
        debugPrint('No circular locations found');
        return {
          'withinGeofence': false,
          'location': null,
          'distance': null,
          'locationType': 'circular',
        };
      }

      debugPrint('Found ${locations.length} circular locations');

      // Find closest location and check if within radius
      LocationModel? closestLocation;
      double? shortestDistance;
      bool withinAnyGeofence = false;

      for (var location in locations) {
        double distanceInMeters = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          location.latitude,
          location.longitude,
        );

        debugPrint('Distance to ${location.name}: ${distanceInMeters.toStringAsFixed(2)}m (radius: ${location.radius}m)');

        // Update closest location if this is closer than previous
        if (shortestDistance == null || distanceInMeters < shortestDistance) {
          shortestDistance = distanceInMeters;
          closestLocation = location;
        }

        // Check if within this location's radius
        if (distanceInMeters <= location.radius) {
          debugPrint('User is WITHIN radius of ${location.name}');
          withinAnyGeofence = true;
          closestLocation = location;
          shortestDistance = distanceInMeters;
          break;
        }
      }

      // Return result
      return {
        'withinGeofence': withinAnyGeofence,
        'location': closestLocation,
        'distance': shortestDistance,
        'locationType': 'circular',
      };
    } catch (e) {
      debugPrint('Error checking circular locations: $e');
      return {
        'withinGeofence': false,
        'location': null,
        'distance': null,
        'locationType': 'circular',
      };
    }
  }

  // Import GeoJSON data into the system
  static Future<bool> importGeoJsonData(BuildContext context, String geoJsonString) async {
    try {
      final PolygonLocationRepository repository = getIt<PolygonLocationRepository>();

      // Parse GeoJSON file
      final List<PolygonLocationModel> locations = await repository.loadFromGeoJson(geoJsonString);

      if (locations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid polygon locations found in the GeoJSON file'),
            backgroundColor: Colors.orange,
          ),
        );
        return false;
      }

      // Save locations
      final bool success = await repository.savePolygonLocations(locations);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported ${locations.length} polygon locations'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving polygon locations'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return success;
    } catch (e) {
      debugPrint('Error importing GeoJSON: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing GeoJSON: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  // Legacy methods for backward compatibility

  // Legacy: Check if user is within geofence
  static Future<bool> isWithinGeofence(BuildContext context) async {
    Map<String, dynamic> status = await checkGeofenceStatus(context);
    return status['withinGeofence'] as bool;
  }

  // Legacy: Get distance to office
  static Future<double?> getDistanceToOffice(BuildContext context) async {
    Map<String, dynamic> status = await checkGeofenceStatus(context);
    return status['distance'] as double?;
  }
}