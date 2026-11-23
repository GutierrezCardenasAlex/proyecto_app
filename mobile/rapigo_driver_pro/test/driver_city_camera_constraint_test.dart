import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rapigo_driver_pro/core/config/app_config.dart';
import 'package:rapigo_driver_pro/driver/features/map/presentation/driver_city_camera_constraint.dart';

void main() {
  test('native center limits contain viewport corners at any rotation', () {
    final city = AppConfig.potosiOfflineBounds;
    for (final size in [const Size(320, 640), const Size(1024, 768)]) {
      final limits = DriverNativeCityLimits(city, size);
      for (final center in [
        limits.centers.northEast,
        limits.centers.southWest,
      ]) {
        for (final rotation in [0.0, 45.0, 90.0, 145.0]) {
          final camera = MapCamera(
            crs: const Epsg3857(),
            center: center,
            zoom: limits.minZoom,
            rotation: rotation,
            nonRotatedSize: size,
          );
          expect(city.contains(camera.visibleBounds.northEast), isTrue);
          expect(city.contains(camera.visibleBounds.southWest), isTrue);
        }
      }
    }
  });

  test('all viewport edges stay in Potosi after pan, zoom and rotation', () {
    final bounds = AppConfig.potosiOfflineBounds;
    final constraint = DriverCityCameraConstraint(bounds: bounds);
    for (final size in [
      const Size(320, 640),
      const Size(430, 932),
      const Size(1024, 768),
      const Size(1366, 1024),
    ]) {
      for (final rotation in [0.0, 45.0, 90.0, 180.0]) {
        for (final center in [
          bounds.center,
          bounds.northEast,
          bounds.southWest,
          const LatLng(-16.5, -68.15),
        ]) {
          for (final zoom in [8.0, 12.0, 15.0, 18.0]) {
            final camera = constraint.constrain(
              MapCamera(
                crs: const Epsg3857(),
                center: center,
                zoom: zoom,
                rotation: rotation,
                nonRotatedSize: size,
              ),
            );
            expect(constraint.constrain(camera), same(camera));
            final visible = camera.visibleBounds;
            expect(visible.north, lessThanOrEqualTo(bounds.north + 0.0000001));
            expect(
              visible.south,
              greaterThanOrEqualTo(bounds.south - 0.0000001),
            );
            expect(visible.east, lessThanOrEqualTo(bounds.east + 0.0000001));
            expect(visible.west, greaterThanOrEqualTo(bounds.west - 0.0000001));
            expect(camera.zoom, lessThanOrEqualTo(AppConfig.mapMaxZoom));
          }
        }
      }
    }
  });

  test('startup without a measured viewport clamps the center safely', () {
    final bounds = AppConfig.potosiOfflineBounds;
    final constrained = DriverCityCameraConstraint(bounds: bounds).constrain(
      MapCamera(
        crs: const Epsg3857(),
        center: const LatLng(0, 0),
        zoom: 15,
        rotation: 0,
        nonRotatedSize: MapCamera.kImpossibleSize,
      ),
    );
    expect(bounds.contains(constrained.center), isTrue);
  });
}
