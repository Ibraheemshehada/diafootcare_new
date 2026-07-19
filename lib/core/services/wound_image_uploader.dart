import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../network/api_client.dart';
import '../../data/local/database_helper.dart';

/// Sends wound photographs to the server, after their scan has synced.
///
/// Separate from [SyncService] on purpose. A scan record is a few hundred bytes
/// and a photograph is a few megabytes, so batching them together would mean a
/// failed image blocking a batch of measurements, and a patient on a weak
/// connection losing the cheap, clinically useful part because the expensive
/// part timed out. They travel independently and fail independently.
class WoundImageUploader {
  WoundImageUploader._();
  static final WoundImageUploader I = WoundImageUploader._();

  /// Longest edge sent to the server.
  ///
  /// A modern phone camera produces 3000-4000 px; the analysis itself works at
  /// 384 px. Sending the original would spend a patient's data allowance on
  /// detail no one reads. 1600 px keeps a wound bed legible to a clinician
  /// zooming in while cutting a typical photo from megabytes to a few hundred
  /// kilobytes.
  static const int _maxEdge = 1600;
  static const int _jpegQuality = 85;

  bool _running = false;

  /// Uploads photographs for scans that have synced but whose image has not.
  ///
  /// Safe to call repeatedly; does nothing when there is nothing to send.
  Future<void> uploadPending({int limit = 5}) async {
    if (_running) return;
    _running = true;

    try {
      final db = await DatabaseHelper().database;

      // Only scans the server already knows about: the image is attached by
      // local_uuid, and an image that arrives first has nothing to attach to.
      final rows = await db.rawQuery('''
        SELECT id, local_uuid, imagePath
        FROM wounds
        WHERE synced_at IS NOT NULL
          AND image_uploaded_at IS NULL
          AND imagePath IS NOT NULL
          AND local_uuid IS NOT NULL
        ORDER BY id ASC
        LIMIT ?
      ''', [limit]);

      for (final row in rows) {
        final ok = await _uploadOne(
          localUuid: row['local_uuid'] as String,
          imagePath: row['imagePath'] as String,
        );

        if (ok) {
          await db.update(
            'wounds',
            {'image_uploaded_at': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
    } catch (e) {
      debugPrint('wound image upload sweep failed: $e');
    } finally {
      _running = false;
    }
  }

  Future<bool> _uploadOne({
    required String localUuid,
    required String imagePath,
  }) async {
    final source = File(imagePath);

    // The photo is gone — the OS cleared the cache, or the user deleted it.
    // Nothing to send and nothing to retry, so treat it as settled rather than
    // retrying this row on every sweep forever.
    if (!await source.exists()) {
      debugPrint('wound image missing on disk, marking done: $imagePath');
      return true;
    }

    try {
      final toSend = await _downscale(source);

      final res = await ApiClient.I.dio.post(
        '/wound-scans/$localUuid/image',
        data: FormData.fromMap({
          'image': await MultipartFile.fromFile(toSend.path,
              filename: '$localUuid.jpg'),
        }),
        options: Options(
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 60),
          // 409 means the scan has not synced yet — expected, not exceptional.
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (toSend.path != source.path) {
        await toSend.delete().catchError((_) => toSend);
      }

      if (res.statusCode == 200) return true;

      if (res.statusCode == 409) {
        // The scan will sync on a later pass and the image with it.
        debugPrint('scan $localUuid not on server yet; image will follow');
        return false;
      }

      debugPrint('wound image upload rejected (${res.statusCode}) for $localUuid');
      // A 4xx that is not 409 will not become a 200 by repeating it — the file
      // is not an image the server accepts. Stop asking.
      return res.statusCode != null && res.statusCode! >= 400 && res.statusCode! < 500;
    } on DioException catch (e) {
      debugPrint('wound image upload failed for $localUuid: ${e.type}');
      return false;
    }
  }

  /// Returns a smaller JPEG, or the original when it is already small enough.
  ///
  /// Runs off the UI isolate: decoding and re-encoding a 12-megapixel photo
  /// takes long enough to drop frames, and this happens in the background while
  /// someone is using the app.
  Future<File> _downscale(File source) async {
    try {
      final bytes = await source.readAsBytes();
      if (bytes.lengthInBytes < 400 * 1024) return source;

      final resized = await compute(_resizeInIsolate, bytes);
      if (resized == null) return source;

      final dir = await getTemporaryDirectory();
      final out = File(
          '${dir.path}/upload_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await out.writeAsBytes(resized);
      return out;
    } catch (e) {
      // Better to send the original than to fail the upload over a resize.
      debugPrint('downscale failed, sending original: $e');
      return source;
    }
  }
}

/// Top-level so it can run in an isolate.
Uint8List? _resizeInIsolate(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final baked = img.bakeOrientation(decoded);
  final longest =
      baked.width > baked.height ? baked.width : baked.height;

  final out = longest <= WoundImageUploader._maxEdge
      ? baked
      : img.copyResize(
          baked,
          width: baked.width >= baked.height
              ? WoundImageUploader._maxEdge
              : null,
          height: baked.height > baked.width
              ? WoundImageUploader._maxEdge
              : null,
          interpolation: img.Interpolation.average,
        );

  return img.encodeJpg(out, quality: WoundImageUploader._jpegQuality);
}
