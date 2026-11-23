import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rapigo_passenger/core/config/app_config.dart';
import 'package:rapigo_passenger/core/map/offline_map.dart';
import 'package:rapigo_passenger/core/map/rapigo_map_runtime.dart';

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
  const receiptKey = 'rapigo_passenger_offline_pack_installed_v1_source_v2';
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

  test(
    'both rendering and download use the owned tile source and raster cache',
    () {
      SharedPreferences.setMockInitialValues({});
      final scope = container();
      expect(
        AppConfig.effectiveMapTilesUrlTemplate,
        AppConfig.effectiveOfflineTilesUrlTemplate,
      );
      expect(
        AppConfig.effectiveMapTilesUrlTemplate,
        contains('/tiles/styles/rapigo-navigation/512/'),
      );
      expect(scope.read(rapigoMapRuntimeProvider).shouldUseMapLibre, isFalse);
    },
  );

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
        'rapigo_passenger_offline_pack_installed_v1': true,
        receiptKey: 'old-carto-source',
      });
      final controller =
          container().read(offlineMapProvider.notifier)
              as TestOfflineController;
      await controller.ensureOfflineAvailability();
      await controller.ensureOfflineAvailability();
      expect(controller.downloads, 1);
      await controller.ensureOfflineAvailability(forceDownload: true);
      expect(controller.downloads, 2);
    },
  );
}
