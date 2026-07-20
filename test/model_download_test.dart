import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:diafootcare_new/core/services/app_mode_service.dart';
import 'package:diafootcare_new/core/services/model_download_service.dart';
import 'package:diafootcare_new/core/services/model_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Points path_provider at a real temp directory so the service writes actual
/// files — the partial-file mechanics are what is under test.
class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
}

/// A server that serves one file with Range support, and can be told to drop
/// the connection after N bytes to simulate a real-world interruption.
class _FlakyServer {
  _FlakyServer(this.payload);
  final List<int> payload;

  HttpServer? _server;
  int? cutAfter;
  int rangeRequests = 0;
  bool supportRange = true;

  /// Delay between chunks, so a test has time to pause mid-transfer.
  Duration? throttle;

  /// End a truncated body by closing the response normally rather than killing
  /// the socket — the silent truncation a proxy produces.
  bool endCleanly = false;

  /// Total payload bytes written, so a test can prove bytes were not re-fetched.
  int bytesServed = 0;

  /// Answer the next range request with an HTML error page carrying a 200,
  /// the way a loaded server or an interfering proxy does.
  bool serveErrorPageOnce = false;

  String get base => 'http://127.0.0.1:${_server!.port}';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((req) async {
      if (req.uri.path.endsWith('/manifest')) {
        req.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'version': 'v1',
            'total_bytes': payload.length,
            'files': [
              {
                'name': 'model.bin',
                'bytes': payload.length,
                'sha256': sha256.convert(payload).toString(),
              }
            ],
          }));
        await req.response.close();
        return;
      }

      if (serveErrorPageOnce) {
        serveErrorPageOnce = false;
        req.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write('<!DOCTYPE html><html lang="en">'
              '<body>Service Unavailable</body></html>');
        await req.response.close();
        return;
      }

      var start = 0;
      final range = req.headers.value('range');
      if (range != null && supportRange) {
        rangeRequests++;
        start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
        req.response.statusCode = HttpStatus.partialContent;
        req.response.headers.set(
          'content-range',
          'bytes $start-${payload.length - 1}/${payload.length}',
        );
      } else {
        req.response.statusCode = HttpStatus.ok;
      }

      final body = payload.sublist(start);
      final limit = cutAfter == null ? body.length : min(cutAfter!, body.length);

      bytesServed += limit;

      if (throttle == null) {
        req.response.add(body.sublist(0, limit));
        await req.response.flush();
      } else {
        const chunk = 8 * 1024;
        for (var o = 0; o < limit; o += chunk) {
          req.response.add(body.sublist(o, min(o + chunk, limit)));
          await req.response.flush();
          await Future<void>.delayed(throttle!);
        }
      }

      if (limit < body.length && !endCleanly) {
        // Kill the socket mid-body, exactly as a dropped connection would.
        await _server!.close(force: true);
        _server = null;
      } else {
        await req.response.close();
      }
    });
  }

  Future<void> stop() async => _server?.close(force: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late List<int> payload;
  late _FlakyServer server;

  Future<void> restartServer({bool supportRange = true}) async {
    server = _FlakyServer(payload)..supportRange = supportRange;
    await server.start();
    ModelDownloadService.baseUrlOverride = server.base;
    ModelDownloadService.I.resetForTest();
    ModelDownloadService.retryBackoffUnit = const Duration(milliseconds: 5);
  }

  setUp(() async {
    // TestWidgetsFlutterBinding installs an HttpOverrides that answers every
    // request with 400. This suite deliberately talks to a loopback server, so
    // the real client has to be restored.
    HttpOverrides.global = null;

    tmp = await Directory.systemTemp.createTemp('dfc_models_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    SharedPreferences.setMockInitialValues({});
    ModelRepository.I.resetForTest();

    final rnd = Random(7);
    payload = List<int>.generate(300 * 1024, (_) => rnd.nextInt(256));

    await restartServer();
  });

  tearDown(() async {
    await server.stop();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('completes and verifies a clean download', () async {
    await ModelDownloadService.I.start();

    expect(ModelDownloadService.I.progress.state, DownloadState.complete);
    expect(await (await ModelRepository.I.fileFor('model.bin')).readAsBytes(), payload);
    expect(await ModelRepository.I.installedVersion(), 'v1');
  });

  test('resumes from the partial file instead of re-fetching', () async {
    // The first attempt dies partway through and the server stays down, so the
    // retry budget is spent and the failure surfaces.
    server.cutAfter = 100 * 1024;
    await ModelDownloadService.I.start();
    expect(ModelDownloadService.I.progress.state, DownloadState.failed);

    final part = await ModelRepository.I.partFor('model.bin');
    expect(await part.length(), greaterThan(0),
        reason: 'transferred bytes must survive the interruption');
    expect(await (await ModelRepository.I.fileFor('model.bin')).exists(), isFalse,
        reason: 'an unverified file must never appear under its final name');

    await restartServer();
    await ModelDownloadService.I.start();

    expect(ModelDownloadService.I.progress.state, DownloadState.complete);
    expect(server.rangeRequests, 1, reason: 'the resume must use a Range request');
    expect(await (await ModelRepository.I.fileFor('model.bin')).readAsBytes(), payload);
  });

  test('restarts cleanly when the server ignores Range', () async {
    server.cutAfter = 80 * 1024;
    await ModelDownloadService.I.start();
    expect(await (await ModelRepository.I.partFor('model.bin')).length(), greaterThan(0));

    await restartServer(supportRange: false);
    await ModelDownloadService.I.start();

    // The partial must have been discarded, not appended to — appending would
    // produce a longer, corrupt file.
    expect(ModelDownloadService.I.progress.state, DownloadState.complete);
    expect(await (await ModelRepository.I.fileFor('model.bin')).readAsBytes(), payload);
  });

  test('a stream that ends early is resumed, not thrown away', () async {
    // A clean early end — no socket error, just a short body. This is what a
    // tired proxy does, and treating it as corruption once cost 168 MB of
    // perfectly good bytes on a real device.
    server.cutAfter = 120 * 1024;
    server.endCleanly = true;

    await ModelDownloadService.I.start();

    expect(ModelDownloadService.I.progress.state, DownloadState.complete,
        reason: 'repeated truncation should still converge, one range at a time');
    expect(await (await ModelRepository.I.fileFor('model.bin')).readAsBytes(), payload);

    // The real assertion: every byte was sent exactly once. Re-fetching from
    // zero after each truncation would show up here as a multiple.
    expect(server.bytesServed, payload.length,
        reason: 'truncated bytes must be kept and resumed past, never re-fetched');
    expect(server.rangeRequests, greaterThan(0));
  });

  test('never writes an error page into the model file', () async {
    // The exact failure seen on a device: a 200 carrying an HTML error page
    // arrived mid-download and was appended as if it were model bytes, giving a
    // file of precisely the right length that could never verify.
    server.cutAfter = 100 * 1024;
    await ModelDownloadService.I.start();

    final part = await ModelRepository.I.partFor('model.bin');
    final beforeGarbage = await part.length();

    await restartServer();
    server.serveErrorPageOnce = true;
    await ModelDownloadService.I.start();

    final file = await ModelRepository.I.fileFor('model.bin');
    expect(ModelDownloadService.I.progress.state, DownloadState.complete,
        reason: 'the retry after the error page should still succeed');
    expect(await file.readAsBytes(), payload);

    // The decisive check: not one byte of markup reached the file.
    expect(String.fromCharCodes(await file.readAsBytes()).contains('DOCTYPE'),
        isFalse);
    expect(beforeGarbage, greaterThan(0),
        reason: 'the good prefix must have survived the whole episode');
  });

  test('discards a complete-but-corrupt file and fetches it again', () async {
    final part = await ModelRepository.I.partFor('model.bin');
    await part.writeAsBytes(List.filled(50 * 1024, 0xAB)); // bytes from nowhere

    await ModelDownloadService.I.start();

    // Corruption is the one case where discarding is right, and the retry then
    // has to actually produce a correct file rather than stalling.
    expect(ModelDownloadService.I.progress.state, DownloadState.complete);
    expect(await (await ModelRepository.I.fileFor('model.bin')).readAsBytes(), payload);
    expect(server.bytesServed, greaterThan(payload.length),
        reason: 'the poisoned range had to be re-fetched');
  });

  test('pause actually stops the bytes, and resume continues from there', () async {
    // Trickle the body so there is a window to pause in.
    server.throttle = const Duration(milliseconds: 30);

    final run = ModelDownloadService.I.start();

    // Wait until some bytes have landed, then pause.
    while (ModelDownloadService.I.progress.received < 20 * 1024) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    ModelDownloadService.I.pause();
    await run;

    expect(ModelDownloadService.I.progress.state, DownloadState.paused);

    final part = await ModelRepository.I.partFor('model.bin');
    final atPause = await part.length();
    expect(atPause, lessThan(payload.length),
        reason: 'pausing must stop before the file is complete');

    // Nothing more may be written once paused — a paused download that keeps
    // consuming the participant's data is the bug this guards.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(await part.length(), atPause);

    await restartServer();
    await ModelDownloadService.I.start();

    expect(ModelDownloadService.I.progress.state, DownloadState.complete);
    expect(server.rangeRequests, 1, reason: 'the resume must ask for a range');
    expect(await (await ModelRepository.I.fileFor('model.bin')).readAsBytes(), payload);
  });

  group('the mode follows the files', () {
    test('a finished download switches the app to offline', () async {
      // Someone can reach the downloader while still in online mode — from
      // Profile, or by choosing offline and having the choice recorded before
      // the transfer starts. Either way, once the files are here they should be
      // used: sitting through 200 MB and then still failing in a clinic with no
      // signal is the exact thing the download was meant to prevent.
      await AppModeService.I.set(AppMode.online);
      expect(await AppModeService.I.current(), AppMode.online);

      await ModelDownloadService.I.start();
      expect(ModelDownloadService.I.progress.state, DownloadState.complete);

      expect(await AppModeService.I.current(), AppMode.offline,
          reason: 'the files are installed, so offline analysis should be on');
    });

    test('a failed download leaves the mode alone', () async {
      // The opposite mistake: claiming an offline capability the phone does not
      // have. A half-finished bundle cannot analyse anything, so the app must
      // stay on the route that still works.
      await AppModeService.I.set(AppMode.online);

      server.cutAfter = 100 * 1024;
      await ModelDownloadService.I.start();
      expect(ModelDownloadService.I.progress.state, DownloadState.failed);

      expect(await AppModeService.I.current(), AppMode.online,
          reason: 'an unfinished download must not switch the app to a mode '
              'it cannot serve');
    });

    test('deleting the bundle switches back to online', () async {
      await ModelDownloadService.I.start();
      expect(await AppModeService.I.current(), AppMode.offline);

      await ModelDownloadService.I.deleteDownloaded();

      expect(await AppModeService.I.current(), AppMode.online,
          reason: 'without the files, offline is a promise the app cannot keep');
      expect(await (await ModelRepository.I.fileFor('model.bin')).exists(), isFalse);
    });
  });

  test('reports progress that never exceeds the total', () async {
    final seen = <double>[];
    final sub = ModelDownloadService.I.stream.listen((p) => seen.add(p.fraction));

    await ModelDownloadService.I.start();
    await sub.cancel();

    expect(seen, isNotEmpty);
    expect(seen.every((f) => f >= 0 && f <= 1), isTrue);
    expect(seen.last, 1.0);
  });
}
