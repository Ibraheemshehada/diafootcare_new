import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:diafootcare_new/core/network/api_client.dart';
import 'package:diafootcare_new/core/services/model_download_service.dart';

/// Proves the model download path reaches the real server over the device's
/// internet connection, using the app's own code and its built-in
/// [ApiClient.baseUrl] (now the production server). No auth: the manifest and
/// file endpoints are public.
///
///   flutter test integration_test/live_download_test.dart -d <device>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('fetchManifest() reaches the live server and parses it', () async {
    final m = await ModelDownloadService.I.fetchManifest(force: true);

    expect(m.version, '59ddd0882a04');
    expect(m.files.length, 6);
    expect(m.totalBytes, 208760936); // 199.1 MB
    expect(
      m.files.any((f) => f.name == 'clip_backbone_fp16.tflite'),
      isTrue,
      reason: 'the 167 MB backbone should be in the manifest',
    );
  });

  test('a real model file downloads over the internet and matches its sha256',
      () async {
    final m = await ModelDownloadService.I.fetchManifest();

    // Pull the smallest file fully so the test is fast but still proves a real
    // byte transfer + integrity check against the server-declared checksum.
    final small = m.files.reduce((a, b) => a.bytes < b.bytes ? a : b);

    final dio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl));
    final res = await dio.get<List<int>>(
      '/models/file/${small.name}',
      options: Options(responseType: ResponseType.bytes),
    );

    expect(res.statusCode, 200);
    expect(res.data!.length, small.bytes);
    expect(sha256.convert(res.data!).toString(), small.sha256);
  });

  test('the server honours range requests (resume support)', () async {
    final dio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl));
    final res = await dio.get<List<int>>(
      '/models/file/clip_backbone_fp16.tflite',
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Range': 'bytes=0-1023'},
        // 206 is a success; don't let dio treat it as an error.
        validateStatus: (s) => s != null && s < 400,
      ),
    );

    expect(res.statusCode, 206, reason: 'ranged GET must return Partial Content');
    expect(res.data!.length, 1024);
  });
}
