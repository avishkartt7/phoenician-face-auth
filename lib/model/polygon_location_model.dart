// lib/model/polygon_location_model.dart

import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geodesy/geodesy.dart';
import 'dart:math' show sqrt, cos, pi;
import 'dart:math' show sqrt, cos, pi, min;
import 'package:flutter/foundation.dart' show debugPrint;

class PolygonLocationModel {
  String? id;
  final String name;
  final String description;
  final List<LatLng> coordinates;
  final bool isActive;

  // Cached center point for display purposes
  final double centerLatitude;
  final double centerLongitude;

  PolygonLocationModel({
    this.id,
    required this.name,
    required this.description,
    required this.coordinates,
    required this.isActive,
    required this.centerLatitude,
    required this.centerLongitude,
  });

  factory PolygonLocationModel.fromJson(Map<String, dynamic> json) {
    List<LatLng> coords = [];

    if (json['coordinates'] != null) {
      if (json['coordinates'] is String) {
        // If coordinates are stored as a string, parse it
        List<dynamic> coordsList = jsonDecode(json['coordinates']);
        coords = coordsList.map((coord) {
          return LatLng(coord[1], coord[0]);
        }).toList();
      } else if (json['coordinates'] is List) {
        // If coordinates are already a list
        coords = (json['coordinates'] as List).map((coord) {
          if (coord is List) {
            return LatLng(coord[1], coord[0]); // GeoJSON format is [lng, lat]
          }
          return LatLng(coord['latitude'], coord['longitude']);
        }).toList();
      }
    }

    return PolygonLocationModel(
      id: json['id'],
      name: json['name'] ?? 'Unnamed Location',
      description: json['description'] ?? '',
      coordinates: coords,
      isActive: json['isActive'] ?? true,
      centerLatitude: json['centerLatitude'] ?? 0.0,
      centerLongitude: json['centerLongitude'] ?? 0.0,
    );
  }

  // Convert from GeoJSON Feature
  factory PolygonLocationModel.fromGeoJsonFeature(Map<String, dynamic> feature) {
    final properties = feature['properties'] as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>;

    // GeoJSON polygons can have multiple linear rings, we take the first one (outer ring)
    final coordinates = (geometry['coordinates'][0] as List).map((coord) {
      // GeoJSON coordinates are [longitude, latitude, (optional) elevation]
      return LatLng(coord[1], coord[0]); // Convert to Geodesy LatLng
    }).toList();

    // Calculate the center point (simple average for now)
    double sumLat = 0.0, sumLng = 0.0;
    for (var coord in coordinates) {
      sumLat += coord.latitude;
      sumLng += coord.longitude;
    }
    double centerLat = sumLat / coordinates.length;
    double centerLng = sumLng / coordinates.length;

    return PolygonLocationModel(
      id: properties['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: properties['name'] ?? 'Unnamed Location',
      description: properties['description'] ?? '',
      coordinates: coordinates,
      isActive: true, // Default to active
      centerLatitude: centerLat,
      centerLongitude: centerLng,
    );
  }

  Map<String, dynamic> toJson() {
    List<List<double>> coordsJson = coordinates.map((coord) =>
    [coord.longitude, coord.latitude] // Convert to GeoJSON format [lng, lat]
    ).toList();

    return {
      'name': name,
      'description': description,
      'coordinates': jsonEncode(coordsJson),
      'isActive': isActive,
      'centerLatitude': centerLatitude,
      'centerLongitude': centerLongitude,
    };
  }

  // Method to check if a point is inside the polygon
  // Update the containsPoint method in PolygonLocationModel class

  // Replace the existing containsPoint method with this:

  // Replace the containsPoint method in PolygonLocationModel
  bool containsPoint(double latitude, double longitude) {
    if (coordinates.isEmpty) {
      return false;
    }

    debugPrint("Checking if point (${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}) is inside polygon: $name");
    debugPrint("Polygon has ${coordinates.length} points");

    // Add additional logging for the first few points of the polygon
    int limit = min(3, coordinates.length);
    for (int i = 0; i < limit; i++) {
      debugPrint("Polygon point $i: (${coordinates[i].latitude.toStringAsFixed(6)}, ${coordinates[i].longitude.toStringAsFixed(6)})");
    }

    // Implement robust point-in-polygon algorithm (Ray casting algorithm)
    bool isInside = false;
    int j = coordinates.length - 1; // Start with the last vertex

    for (int i = 0; i < coordinates.length; i++) {
      final vertI = coordinates[i];
      final vertJ = coordinates[j];

      // Check if the point is on a boundary
      // Using a small epsilon for floating point comparison
      const double epsilon = 0.0000001;
      if (((vertI.latitude - latitude).abs() < epsilon &&
          (vertI.longitude - longitude).abs() < epsilon) ||
          ((vertJ.latitude - latitude).abs() < epsilon &&
              (vertJ.longitude - longitude).abs() < epsilon)) {
        debugPrint("Point is on polygon boundary - considering as inside");
        return true;
      }

      // Check if ray from point crosses this edge
      if (((vertI.latitude > latitude) != (vertJ.latitude > latitude)) &&
          (longitude < (vertJ.longitude - vertI.longitude) * (latitude - vertI.latitude) /
              (vertJ.latitude - vertI.latitude) + vertI.longitude)) {
        isInside = !isInside;
      }

      j = i; // j becomes i for the next iteration
    }

    debugPrint("Containment check result: $isInside");
    return isInside;
  }

  // Add this to your PolygonLocationModel class in lib/model/polygon_location_model.dart

// Calculate distance to polygon (0 if inside, distance to nearest edge if outside)
  double distanceToPolygon(double latitude, double longitude) {
    // If point is inside the polygon, return 0
    if (containsPoint(latitude, longitude)) {
      return 0.0;
    }

    // Otherwise, find minimum distance to any edge of the polygon
    double minDistance = double.infinity;
    final int len = coordinates.length;

    for (int i = 0; i < len; i++) {
      final startPoint = coordinates[i];
      final endPoint = coordinates[(i + 1) % len]; // Loop back to first point

      // Calculate distance to this edge
      final distance = _calculateDistanceToLine(
          latitude, longitude,
          startPoint.latitude, startPoint.longitude,
          endPoint.latitude, endPoint.longitude
      );

      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance;
  }

// Renamed to avoid duplicate method declaration
  double _calculateDistanceToLine(
      double lat, double lng,
      double startLat, double startLng,
      double endLat, double endLng
      ) {
    // Convert to cartesian coordinates for simplicity
    // This is an approximation that works for small distances
    final double earthRadius = 6371000; // Earth radius in meters

    // Convert to radians
    final double latRad = lat * (pi / 180);
    final double lngRad = lng * (pi / 180);
    final double startLatRad = startLat * (pi / 180);
    final double startLngRad = startLng * (pi / 180);
    final double endLatRad = endLat * (pi / 180);
    final double endLngRad = endLng * (pi / 180);

    // Calculate x, y coordinates (simplified projection)
    final double x = earthRadius * lngRad * cos(latRad);
    final double y = earthRadius * latRad;

    final double x1 = earthRadius * startLngRad * cos(startLatRad);
    final double y1 = earthRadius * startLatRad;

    final double x2 = earthRadius * endLngRad * cos(endLatRad);
    final double y2 = earthRadius * endLatRad;

    // Calculate distance from point to line segment
    final double A = x - x1;
    final double B = y - y1;
    final double C = x2 - x1;
    final double D = y2 - y1;

    final double dot = A * C + B * D;
    final double lenSq = C * C + D * D;
    double param = -1;

    if (lenSq != 0) {
      param = dot / lenSq;
    }

    double xx, yy;

    if (param < 0) {
      xx = x1;
      yy = y1;
    } else if (param > 1) {
      xx = x2;
      yy = y2;
    } else {
      xx = x1 + param * C;
      yy = y1 + param * D;
    }

    final double dx = x - xx;
    final double dy = y - yy;

    return sqrt(dx * dx + dy * dy);
  }

  // Helper method to calculate distance from a point to a line segment
  double _distanceToLine(
      double lat, double lng,
      double startLat, double startLng,
      double endLat, double endLng
      ) {
    // Convert to cartesian coordinates for simplicity
    // This is an approximation that works for small distances
    final double earthRadius = 6371000; // Earth radius in meters

    // Convert to radians
    final double latRad = lat * (pi / 180);
    final double lngRad = lng * (pi / 180);
    final double startLatRad = startLat * (pi / 180);
    final double startLngRad = startLng * (pi / 180);
    final double endLatRad = endLat * (pi / 180);
    final double endLngRad = endLng * (pi / 180);

    // Calculate x, y coordinates
    final double x = earthRadius * lngRad * cos(latRad);
    final double y = earthRadius * latRad;

    final double x1 = earthRadius * startLngRad * cos(startLatRad);
    final double y1 = earthRadius * startLatRad;

    final double x2 = earthRadius * endLngRad * cos(endLatRad);
    final double y2 = earthRadius * endLatRad;

    // Calculate distance from point to line segment
    final double A = x - x1;
    final double B = y - y1;
    final double C = x2 - x1;
    final double D = y2 - y1;

    final double dot = A * C + B * D;
    final double lenSq = C * C + D * D;
    double param = -1;

    if (lenSq != 0) {
      param = dot / lenSq;
    }

    double xx, yy;

    if (param < 0) {
      xx = x1;
      yy = y1;
    } else if (param > 1) {
      xx = x2;
      yy = y2;
    } else {
      xx = x1 + param * C;
      yy = y1 + param * D;
    }

    final double dx = x - xx;
    final double dy = y - yy;

    return sqrt(dx * dx + dy * dy);
  }


}

