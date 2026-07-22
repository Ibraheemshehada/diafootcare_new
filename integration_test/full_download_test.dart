import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:diafootcare_new/core/services/model_download_service.dart';
import 'package:diafootcare_new/core/services/model_repository.dart';

/// End-to-end proof that the FULL offline bundle downloads to completion against
/// the live server — including the two `*_meta.json` files that the content-type
/// guard used to reject as "a page instead of the file", which left the download
/// permanently stuck at ~99%.
///
/// Heavy (downloads ~199 MB), so it is not part of the routine suite; run it
/// deliberately:
///   flutter test integration_test/full_download_test.dart -d <device>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the whole model bundle installs, meta files included',
      (tester) async {
    // Start from clean so every file, including the metas, is actually fetched.
    await ModelRepository.I.deleteAll();
    await ModelRepository.I.setInstalledVersion(null);

    final done = ModelDownloadService.I.stream.firstWhere(
      (p) =>
          p.state == DownloadState.complete ||
          p.state == DownloadState.failed,
    );

    await ModelDownloadService.I.start();
    final result = await done.timeout(const Duration(minutes: 8));

    expect(result.state, DownloadState.complete,
        reason: 'download did not complete: ${result.error}');
    expect(await ModelDownloadService.I.isInstalled(), isTrue);
  });
}
