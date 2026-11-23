import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Keeps the entire visible viewport inside the downloaded city, including
/// landscape screens and rotated maps. A center-only clamp exposes empty edges.
class DriverCityCameraConstraint extends CameraConstraint {
  const DriverCityCameraConstraint({required this.bounds});

  final LatLngBounds bounds;

  @override
  MapCamera constrain(MapCamera camera) {
    final size = camera.size;
    if (!size.width.isFinite || !size.height.isFinite || size.isEmpty) {
      return CameraConstraint.containCenter(bounds: bounds).constrain(camera)!;
    }
    final northEast = camera.projectAtZoom(bounds.northEast, camera.zoom);
    final southWest = camera.projectAtZoom(bounds.southWest, camera.zoom);
    final scale = math.max(
      (size.width + 4) / (northEast.dx - southWest.dx).abs(),
      (size.height + 4) / (southWest.dy - northEast.dy).abs(),
    );
    final fitted = scale >= 1
        ? camera.withPosition(
            zoom: camera.zoom + math.log(scale) / math.ln2 + 0.01,
          )
        : camera;
    // The renderer floors pixel centers. Keep a two-pixel inset so rounding
    // cannot expose an empty strip along the city boundary.
    final ne = fitted.projectAtZoom(bounds.northEast, fitted.zoom);
    final sw = fitted.projectAtZoom(bounds.southWest, fitted.zoom);
    final inset = LatLngBounds(
      fitted.unprojectAtZoom(Offset(sw.dx + 2, sw.dy - 2), fitted.zoom),
      fitted.unprojectAtZoom(Offset(ne.dx - 2, ne.dy + 2), fitted.zoom),
    );
    final contained = CameraConstraint.contain(
      bounds: inset,
    ).constrain(fitted)!;
    if (contained.zoom == camera.zoom &&
        (camera.projectAtZoom(contained.center, camera.zoom) -
                    camera.projectAtZoom(camera.center, camera.zoom))
                .distance <
            0.000001) {
      return camera;
    }
    return contained;
  }

  @override
  bool operator ==(Object other) =>
      other is DriverCityCameraConstraint && other.bounds == bounds;

  @override
  int get hashCode => bounds.hashCode;
}

/// Conservative native center bounds keep all corners inside the city even
/// during rotation; MapLibre's cameraTargetBounds only constrain the center.
class DriverNativeCityLimits {
  DriverNativeCityLimits(LatLngBounds city, Size viewport) {
    final diagonal = math.sqrt(
      viewport.width * viewport.width + viewport.height * viewport.height,
    );
    final fitted = DriverCityCameraConstraint(bounds: city).constrain(
      MapCamera(
        crs: const Epsg3857(),
        center: city.center,
        zoom: 13,
        rotation: 0,
        nonRotatedSize: Size(diagonal, diagonal),
      ),
    );
    minZoom = fitted.zoom + 0.25;
    final ne = fitted.projectAtZoom(city.northEast, minZoom);
    final sw = fitted.projectAtZoom(city.southWest, minZoom);
    final margin = diagonal / 2 + 3;
    centers = LatLngBounds(
      fitted.unprojectAtZoom(Offset(sw.dx + margin, sw.dy - margin), minZoom),
      fitted.unprojectAtZoom(Offset(ne.dx - margin, ne.dy + margin), minZoom),
    );
  }
  late final double minZoom;
  late final LatLngBounds centers;
  LatLng clamp(LatLng point) => LatLng(
    point.latitude.clamp(centers.south, centers.north),
    point.longitude.clamp(centers.west, centers.east),
  );
}
