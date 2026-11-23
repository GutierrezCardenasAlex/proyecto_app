import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rapigo_driver_pro/core/config/app_config.dart';
import 'package:rapigo_driver_pro/core/map/offline_map.dart';
import 'package:rapigo_driver_pro/core/map/rapigo_map_runtime.dart';

class TestOfflineController extends OfflineMapController {
  int downloads = 0;
  @override
  Future<void> refreshStatus() async {}
  @override
  Future<void> downloadPotosiMap() async {
    downloads++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const receiptKey = 'rapigo_pro_offline_pack_installed_v1_source_v2';
  final identity =
      '${AppConfig.effectiveOfflineTilesUrlTemplate}|12|18|'
      '${AppConfig.mapTileDimension}|${AppConfig.mapTileZoomOffset}|'
      '${AppConfig.potosiOfflineBounds.southWest}|${AppConfig.potosiOfflineBounds.northEast}';

  ProviderContainer container() {
    final result = ProviderContainer(
      overrides: [offlineMapProvider.overrideWith(TestOfflineController.new)],
    );
    addTearDown(result.dispose);
    return result;
  }

  test('OpenStreetMap raster uses the persistent browsing cache', () {
    SharedPreferences.setMockInitialValues({});
    final scope = container();
    if (AppConfig.hasDedicatedOfflineTileSource) {
      expect(
        AppConfig.effectiveMapTilesUrlTemplate,
        AppConfig.effectiveOfflineTilesUrlTemplate,
      );
    } else {
      expect(
        AppConfig.effectiveMapTilesUrlTemplate,
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );
      expect(AppConfig.mapTileDimension, 256);
      expect(AppConfig.mapTileZoomOffset, 0);
    }
    expect(scope.read(rapigoMapRuntimeProvider).shouldUseMapLibre, isFalse);
  });

  test(
    'completed pack survives controller recreation without downloading',
    () async {
      SharedPreferences.setMockInitialValues({receiptKey: identity});
      for (var i = 0; i < 2; i++) {
        final controller =
            container().read(offlineMapProvider.notifier)
                as TestOfflineController;
        await controller.ensureOfflineAvailability();
        expect(controller.downloads, 0);
      }
    },
  );

  test(
    'legacy or different source receipt cannot mark current pack installed',
    () async {
      SharedPreferences.setMockInitialValues({
        'rapigo_pro_offline_pack_installed_v1': true,
        receiptKey: 'old-carto-source',
      });
      final controller =
          container().read(offlineMapProvider.notifier)
              as TestOfflineController;
      await controller.ensureOfflineAvailability();
      await controller.ensureOfflineAvailability();
      expect(
        controller.downloads,
        AppConfig.hasDedicatedOfflineTileSource ? 1 : 0,
      );
      await controller.ensureOfflineAvailability(forceDownload: true);
      expect(
        controller.downloads,
        AppConfig.hasDedicatedOfflineTileSource ? 2 : 0,
      );
    },
  );
}
