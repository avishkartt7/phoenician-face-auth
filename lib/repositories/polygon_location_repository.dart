// lib/repositories/polygon_location_repository.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phoenician_face_auth/model/polygon_location_model.dart';
import 'package:phoenician_face_auth/services/database_helper.dart';
import 'package:phoenician_face_auth/services/connectivity_service.dart';
import 'package:geodesy/geodesy.dart';
import 'package:flutter/foundation.dart';

class PolygonLocationRepository {
  final DatabaseHelper _dbHelper;
  final FirebaseFirestore _firestore;
  final ConnectivityService _connectivityService;

  PolygonLocationRepository({
    required DatabaseHelper dbHelper,
    FirebaseFirestore? firestore,
    required ConnectivityService connectivityService,
  }) : _dbHelper = dbHelper,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _connectivityService = connectivityService;

  // Load a GeoJSON file and parse it to get polygon boundaries
  Future<List<PolygonLocationModel>> loadFromGeoJson(String geoJsonString) async {
    try {
      final List<PolygonLocationModel> locations = [];
      final Map<String, dynamic> geoJson = jsonDecode(geoJsonString);

      if (geoJson.containsKey('features')) {
        final List<dynamic> features = geoJson['features'];

        for (var feature in features) {
          if (feature['geometry']['type'] == 'Polygon') {
            locations.add(PolygonLocationModel.fromGeoJsonFeature(feature));
          }
        }
      }

      return locations;
    } catch (e) {
      debugPrint('Error parsing GeoJSON: $e');
      return [];
    }
  }

  // Save polygon locations to Firestore and local database
  Future<bool> savePolygonLocations(List<PolygonLocationModel> locations) async {
    try {
      // If online, save to Firestore first
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        for (var location in locations) {
          // Convert coordinates to format that Firestore can store
          final List<Map<String, double>> coordinates = location.coordinates.map((coord) {
            return {'latitude': coord.latitude, 'longitude': coord.longitude};
          }).toList();

          // Create document data
          final Map<String, dynamic> data = {
            'name': location.name,
            'description': location.description,
            'coordinates': coordinates,
            'isActive': location.isActive,
            'centerLatitude': location.centerLatitude,
            'centerLongitude': location.centerLongitude,
            'updatedAt': FieldValue.serverTimestamp(),
          };

          // Save to Firestore
          DocumentReference docRef;
          if (location.id != null && location.id!.isNotEmpty) {
            await _firestore.collection('polygon_locations').doc(location.id).set(data);
            docRef = _firestore.collection('polygon_locations').doc(location.id);
          } else {
            docRef = await _firestore.collection('polygon_locations').add(data);
            location.id = docRef.id;
          }
        }
      }

      // Always save to local database
      for (var location in locations) {
        if (location.id == null) {
          location.id = DateTime.now().millisecondsSinceEpoch.toString();
        }

        await _dbHelper.insert('polygon_locations', {
          'id': location.id,
          'name': location.name,
          'description': location.description,
          'coordinates': jsonEncode(location.coordinates.map((coord) =>
          [coord.longitude, coord.latitude] // GeoJSON format [longitude, latitude]
          ).toList()),
          'is_active': location.isActive ? 1 : 0,
          'center_latitude': location.centerLatitude,
          'center_longitude': location.centerLongitude,
          'last_updated': DateTime.now().millisecondsSinceEpoch,
        });
      }

      return true;
    } catch (e) {
      debugPrint('Error saving polygon locations: $e');
      return false;
    }
  }

  // Fetch all active polygon locations
  Future<List<PolygonLocationModel>> getActivePolygonLocations() async {
    try {
      // If online, try to fetch from Firestore and update local cache
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        try {
          final QuerySnapshot snapshot = await _firestore
              .collection('polygon_locations')
              .where('isActive', isEqualTo: true)
              .get();

          final List<PolygonLocationModel> locations = [];

          for (var doc in snapshot.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

            // Process coordinates from Firestore
            List<LatLng> coordinates = [];
            if (data['coordinates'] != null) {
              for (var coord in data['coordinates']) {
                if (coord is Map<String, dynamic>) {
                  coordinates.add(LatLng(coord['latitude'], coord['longitude']));
                }
              }
            }

            PolygonLocationModel location = PolygonLocationModel(
              id: doc.id,
              name: data['name'] ?? 'Unnamed Location',
              description: data['description'] ?? '',
              coordinates: coordinates,
              isActive: data['isActive'] ?? true,
              centerLatitude: data['centerLatitude'] ?? 0.0,
              centerLongitude: data['centerLongitude'] ?? 0.0,
            );

            locations.add(location);

            // Also save to local database
            await _saveLocationLocally(location);
          }

          return locations;
        } catch (e) {
          debugPrint('Error fetching polygon locations from Firestore: $e');
          // Fall back to local database
        }
      }

      // Read from local database
      final List<Map<String, dynamic>> maps = await _dbHelper.query(
        'polygon_locations',
        where: 'is_active = ?',
        whereArgs: [1],
      );

      return maps.map((map) {
        List<LatLng> coordinates = [];
        try {
          List<dynamic> coordsJson = jsonDecode(map['coordinates']);
          coordinates = coordsJson.map((coord) {
            // GeoJSON format is [longitude, latitude]
            return LatLng(coord[1], coord[0]);
          }).toList();
        } catch (e) {
          debugPrint('Error parsing coordinates: $e');
        }

        return PolygonLocationModel(
          id: map['id'],
          name: map['name'],
          description: map['description'] ?? '',
          coordinates: coordinates,
          isActive: map['is_active'] == 1,
          centerLatitude: map['center_latitude'],
          centerLongitude: map['center_longitude'],
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting active polygon locations: $e');
      return [];
    }
  }

  // Helper method to save location to local database
  Future<void> _saveLocationLocally(PolygonLocationModel location) async {
    try {
      await _dbHelper.insert('polygon_locations', {
        'id': location.id,
        'name': location.name,
        'description': location.description,
        'coordinates': jsonEncode(location.coordinates.map((coord) =>
        [coord.longitude, coord.latitude] // GeoJSON format [longitude, latitude]
        ).toList()),
        'is_active': location.isActive ? 1 : 0,
        'center_latitude': location.centerLatitude,
        'center_longitude': location.centerLongitude,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Error saving location locally: $e');
    }
  }
}