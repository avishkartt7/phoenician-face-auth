import 'package:flutter/material.dart';

// This function will navigate to the PolygonMapView without importing it directly
void navigateToPolygonMapView(BuildContext context) {
  Navigator.of(context).pushNamed('/polygon_map_view');
}

// This function will navigate to the GeoJsonImporterView without importing it directly
void navigateToGeoJsonImporterView(BuildContext context) {
  Navigator.of(context).pushNamed('/geojson_importer_view');
}