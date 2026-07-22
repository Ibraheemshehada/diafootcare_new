import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import 'app_mode_service.dart';
import 'device_service.dart';
import 'model_repository.dart';

enum DownloadState { idle, checking, downloading, verifying, paused, complete, failed }

/// A snapshot of the download, shaped for direct display.
@immutable
class DownloadProgress {
  final DownloadState state;
  final int received;
  final int total;

  /// The file currently in flight, for "Downloading 2 of 6".
  final String? currentFile;
  final int fileIndex;
  final int fileCount;

  /// Bytes per second over the recent window, or null before there is enough
  /// data to say anything honest about it.
  final double? bytesPerSecond;

  /// Set when [state] is failed. Already localised.
  final String? error;

  const DownloadProgress({
    this.state = DownloadState.idle,
    this.received = 0,
    this.total = 0,
    this.currentFile,
    this.fileIndex = 0,
    this.fileCount = 0,
    this.bytesPerSecond,
    this.error,
  });

  double get fraction => total <= 0 ? 0 : (received / total).clamp(0.0, 1.0);

  bool get isActive =>
      state == DownloadState.downloading ||
      state == DownloadState.verifying ||
      state == DownloadState.checking;

  /// Seconds remaining, or null when the rate is unknown or meaningless.
  /// Deliberately null rather than a fabricated number: a wrong ETA is worse
  /// than none, because people plan around it.
  int? get secondsRemaining {
    final rate = bytesPerSecond;
    if (rate == null || rate < 1024 || total <= 0) return null;
    final left = total - received;
    if (left <= 0) return 0;
    return (left / rate).round();
  }

  DownloadProgress copyWith({
    DownloadState? state,
    int? received,
    int? total,
    String? currentFile,
    int? fileIndex,
    int? fileCount,
    double? bytesPerSecond,
    String? error,
  }) =>
      DownloadProgress(
        state: state ?? this.state,
        received: received ?? this.received,
        total: total ?? this.total,
        currentFile: currentFile ?? this.currentFile,
        fileIndex: fileIndex ?? this.fileIndex,
        fileCount: fileCount ?? this.fileCount,
        bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
        error: error,
      );
}

/// Downloads the offline analysis bundle, resumably.
///
/// The bundle is ~200 MB, which on a clinic's connection is minutes of transfer
/// — long enough that a dropped connection, a backgrounded app, or a participant
/// who taps away is the normal case rather than the exception. So every byte is
/// appended to a `.part` file on disk and resumed with an HTTP Range request:
/// stopping is free, and nothing already transferred is ever re-fetched.
class ModelDownloadService {
  ModelDownloadService._();
  static final ModelDownloadService I = ModelDownloadService._();

  final _controller = StreamController<DownloadProgress>.broadcast();
  Stream<DownloadProgress> get stream => _controller.stream;

  DownloadProgress _progress = const DownloadProgress();
  DownloadProgress get progress => _progress;

  ModelManifest? _manifest;
  ModelManifest? get manifest => _manifest;

  CancelToken? _cancel;
  bool _running = false;

  /// Set when the participant pauses, to distinguish a deliberate stop from a
  /// network failure — they deserve different messages and different retries.
  bool _pausedByUser = false;

  /// Checked inside the byte loop. Cancelling the CancelToken aborts a *pending*
  /// request, but once the response is open and its stream is being consumed the
  /// bytes keep arriving — so pausing has to break the loop itself. Without this
  /// a paused download quietly carried on using the participant's data.
  bool _stopRequested = false;

  /// Overridable so tests can point at a local server that can be interrupted
  /// mid-transfer — the resume path is the whole reason this class exists, and
  /// it cannot be exercised against a server that always succeeds.
  @visibleForTesting
  static String? baseUrlOverride;

  Dio? _dioCache;

  Dio get _dio => _dioCache ??= Dio(BaseOptions(
        baseUrl: baseUrlOverride ?? ApiClient.baseUrl,
        // No receive timeout: a slow 175 MB file is not a stuck one, and the
        // stream's own idle behaviour is what actually detects a dead
        // connection.
        connectTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
      ));

  void _emit(DownloadProgress p) {
    _progress = p;
    if (!_controller.isClosed) _controller.add(p);
  }

  /// Fetches the manifest. Cheap and cached server-side, so it is safe to call
  /// on the settings screen to show the bundle size before committing.
  Future<ModelManifest> fetchManifest({bool force = false}) async {
    if (_manifest != null && !force) return _manifest!;
    final res = await _dio.get('/models/manifest');
    return _manifest = ModelManifest.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  /// True when the installed bundle matches the server's current version.
  Future<bool> isInstalled() async {
    try {
      final m = await fetchManifest();
      final installed = await ModelRepository.I.installedVersion();
      if (installed != m.version) return false;
      return await ModelRepository.I.isComplete(m);
    } catch (_) {
      // Offline: trust the local record rather than declaring the models
      // missing, which would push a working offline install back into setup.
      final installed = await ModelRepository.I.installedVersion();
      return installed != null;
    }
  }

  /// Starts or resumes the download. Safe to call while one is already running.
  Future<void> start() async {
    if (_running) return;
    _running = true;
    _pausedByUser = false;
    _stopRequested = false;
    _cancel = CancelToken();

    try {
      _emit(_progress.copyWith(state: DownloadState.checking, error: null));

      final manifest = await fetchManifest(force: true);

      // A bundle that changed on the server mid-download leaves partials that
      // belong to a different version. They would fail the checksum eventually,
      // but discarding them now avoids downloading megabytes destined to be
      // thrown away.
      final installed = await ModelRepository.I.installedVersion();
      if (installed != null && installed != manifest.version) {
        await ModelRepository.I.deleteAll();
      }

      var received = await ModelRepository.I.bytesOnDisk(manifest);
      _emit(_progress.copyWith(
        state: DownloadState.downloading,
        received: received,
        total: manifest.totalBytes,
        fileCount: manifest.files.length,
      ));

      for (var i = 0; i < manifest.files.length; i++) {
        final f = manifest.files[i];
        final target = await ModelRepository.I.fileFor(f.name);

        if (await target.exists() && await target.length() == f.bytes) {
          continue; // already installed
        }

        _emit(_progress.copyWith(
          currentFile: f.name,
          fileIndex: i + 1,
          state: DownloadState.downloading,
        ));

        received = await _withRetries(
          () async => _downloadOne(
            f,
            // Re-read from disk each attempt: the previous attempt's bytes are
            // already there, and reusing the pre-attempt figure would make the
            // bar jump backwards on every retry.
            startedAt: await ModelRepository.I.bytesOnDisk(manifest),
          ),
          progressSoFar: () => _progress.received,
        );
      }

      await ModelRepository.I.setInstalledVersion(manifest.version);

      // The files are here, so start using them. Someone who sat through a
      // 200 MB download did it to stop depending on a connection; leaving the
      // app in online mode afterwards would mean their next scan still failed
      // in a clinic with no signal, which is the exact thing they just spent
      // twenty minutes preventing.
      await AppModeService.I.set(AppMode.offline);

      unawaited(DeviceService.I.updateMode(modelsDownloaded: true));

      _emit(DownloadProgress(
        state: DownloadState.complete,
        received: manifest.totalBytes,
        total: manifest.totalBytes,
        fileCount: manifest.files.length,
        fileIndex: manifest.files.length,
      ));
    } on _PausedByUser {
      _emit(_progress.copyWith(state: DownloadState.paused, error: null));
    } on DioException catch (e) {
      if (_pausedByUser || CancelToken.isCancel(e)) {
        _emit(_progress.copyWith(state: DownloadState.paused, error: null));
      } else {
        _emit(_progress.copyWith(
          state: DownloadState.failed,
          error: _describe(e),
        ));
      }
    } catch (e) {
      _emit(_progress.copyWith(
        state: DownloadState.failed,
        error: _describe(e),
      ));
    } finally {
      _running = false;
      _cancel = null;
    }
  }

  /// How many consecutive failures to absorb before giving up and asking the
  /// participant. The counter resets whenever bytes actually move, so a long
  /// download over a flaky connection is not capped at a fixed number of drops
  /// — only a connection that is making no progress at all stops us.
  static const _maxAttempts = 5;

  /// Backoff unit, shortened by tests so a retry path can be exercised without
  /// waiting out a real ladder.
  @visibleForTesting
  static Duration retryBackoffUnit = const Duration(seconds: 1);

  /// Retries a transfer that stopped without losing what it already had.
  ///
  /// A 175 MB file on a clinic connection can drop repeatedly. Making someone
  /// tap "try again" after each drop is not a recovery strategy, so drops are
  /// absorbed silently and only a genuinely stuck download surfaces an error.
  Future<int> _withRetries(
    Future<int> Function() attempt, {
    required int Function() progressSoFar,
  }) async {
    var failures = 0;
    var lastProgress = progressSoFar();

    while (true) {
      try {
        return await attempt();
      } on _PausedByUser {
        rethrow;
      } catch (e) {
        if (_stopRequested) rethrow;

        final now = progressSoFar();
        if (now > lastProgress) {
          // Something was transferred, so the connection is usable and this is
          // a drop rather than a dead end. Start the budget over.
          failures = 0;
          lastProgress = now;
        } else {
          failures++;
        }

        if (failures >= _maxAttempts) rethrow;

        _emit(_progress.copyWith(
          state: DownloadState.downloading,
          bytesPerSecond: 0,
        ));
        await Future<void>.delayed(retryBackoffUnit * (1 << failures));
        if (_stopRequested) rethrow;
      }
    }
  }

  /// Throws unless [res] is genuinely the requested slice of [f].
  ///
  /// Checks the shape of the response rather than trusting the status code:
  /// an error page, a login redirect, or a proxy's own JSON all arrive as a
  /// 200 with a body that is not the file.
  void _rejectIfNotFileBody(Response<ResponseBody> res, ModelFile f, int offset) {
    if (res.statusCode == 416) return;

    // Markup always disqualifies (a login page, a 404). JSON disqualifies too —
    // an error envelope or a proxy page — EXCEPT for the manifest's own `.json`
    // metadata files, which are legitimately served as application/json. Without
    // that exception the two *_meta.json files were rejected forever and the
    // offline download could never complete. Plenty of correct servers label a
    // binary as text/plain, and the content-length / range / sha256 checks below
    // cover a genuinely wrong body regardless of its content-type.
    final type = res.headers.value('content-type')?.toLowerCase() ?? '';
    final expectsJson = f.name.toLowerCase().endsWith('.json');
    if (type.contains('html') || (type.contains('json') && !expectsJson)) {
      throw ModelDownloadException(
        'The server sent a page instead of the file. Retrying.',
        resumable: true,
      );
    }

    final length = int.tryParse(res.headers.value('content-length') ?? '');

    if (res.statusCode == 206) {
      // "bytes <start>-<end>/<total>" must line up with what we asked for.
      final cr = res.headers.value('content-range') ?? '';
      final m = RegExp(r'bytes\s+(\d+)-(\d+)/(\d+)').firstMatch(cr);
      if (m == null ||
          int.parse(m.group(1)!) != offset ||
          int.parse(m.group(3)!) != f.bytes) {
        throw ModelDownloadException(
          'The server sent a different part of the file than requested.',
          resumable: true,
        );
      }
      final expected = f.bytes - offset;
      if (length != null && length != expected) {
        throw ModelDownloadException(
          'The server sent an unexpected amount of data. Retrying.',
          resumable: true,
        );
      }
      return;
    }

    // A plain 200 must be the whole file.
    if (length != null && length != f.bytes) {
      throw ModelDownloadException(
        'The server sent an unexpected amount of data. Retrying.',
        resumable: true,
      );
    }
  }

  /// Downloads one file, resuming from whatever is already in its `.part`.
  /// Returns the new cumulative received-byte count across the whole bundle.
  Future<int> _downloadOne(ModelFile f, {required int startedAt}) async {
    final part = await ModelRepository.I.partFor(f.name);

    // A zero-byte entry (an empty metadata file, a placeholder) never enters the
    // transfer loop, so nothing would create the partial that the verify and
    // rename steps below expect.
    if (!await part.exists()) await part.create(recursive: true);

    var offset = await part.length();

    // More bytes than the file should have means the partial is from another
    // version, or a previous write was interrupted mid-buffer. Start it over
    // rather than producing a file that can never match its checksum.
    if (offset > f.bytes) {
      await part.delete();
      offset = 0;
    }

    var cumulative = startedAt;

    if (offset < f.bytes) {
      final res = await _dio.get<ResponseBody>(
        '/models/file/${f.name}',
        cancelToken: _cancel,
        options: Options(
          responseType: ResponseType.stream,
          headers: offset > 0 ? {'Range': 'bytes=$offset-'} : null,
          // 416 means the server thinks we already have the whole file; handle
          // it below rather than as an exception.
          validateStatus: (s) => s != null && (s == 200 || s == 206 || s == 416),
        ),
      );

      // Before a single byte is appended, check that this response really is
      // the slice of the file we asked for.
      //
      // A server under load can answer a range request with a perfectly valid
      // 200 whose body is an HTML error page. Appending that produces a file of
      // exactly the right length whose contents are wrong — which then costs a
      // full 200 MB re-download to discover. This happened: an error page landed
      // 124 MB into a model file and every size check still passed.
      _rejectIfNotFileBody(res, f, offset);

      if (res.statusCode == 416) {
        // Our partial is at or past the file's length. The checksum below is
        // the arbiter of whether it is actually good.
        offset = f.bytes;
      } else if (res.statusCode == 200 && offset > 0) {
        // The server ignored our Range and is sending the whole file. Anything
        // already on disk would be duplicated if we appended, so discard it.
        if (await part.exists()) await part.delete();
        cumulative -= offset;
        offset = 0;
      }

      if (res.statusCode != 416) {
        // A RandomAccessFile rather than an IOSink, deliberately. IOSink.add()
        // buffers and reports write errors asynchronously: when the socket dies
        // mid-transfer, flush() throws, close() is skipped, and the abandoned
        // sink later writes its buffer into a file a retry has already reopened
        // in append mode. That produced a file of exactly the right length whose
        // contents were interleaved garbage — the hardest kind of corruption to
        // spot, because every size check passes. Awaiting each write keeps the
        // file's length and its contents in step at all times.
        final raf = await part.open(mode: FileMode.append);
        var lastEmit = DateTime.now();
        var windowStart = DateTime.now();
        var windowBytes = 0;

        try {
          await for (final chunk in res.data!.stream) {
            if (_stopRequested) {
              // Throwing exits the loop and cancels the subscription, which
              // closes the socket. Everything written so far stays on disk.
              throw const _PausedByUser();
            }
            await raf.writeFrom(chunk);
            cumulative += chunk.length;
            windowBytes += chunk.length;

            // Throttled: a 200 MB download delivers tens of thousands of chunks,
            // and rebuilding the UI for each one costs more than the transfer.
            final now = DateTime.now();
            if (now.difference(lastEmit).inMilliseconds >= 250) {
              final elapsed =
                  now.difference(windowStart).inMilliseconds / 1000.0;
              final rate = elapsed > 0.5 ? windowBytes / elapsed : null;
              if (elapsed > 2) {
                windowStart = now;
                windowBytes = 0;
              }
              _emit(_progress.copyWith(
                state: DownloadState.downloading,
                received: cumulative,
                bytesPerSecond: rate,
              ));
              lastEmit = now;
            }
          }
        } finally {
          // Both wrapped: a failing flush must never prevent the close, or the
          // handle leaks and the next attempt writes alongside it.
          try {
            await raf.flush();
          } catch (_) {
            // Nothing to salvage; the length on disk is still authoritative.
          }
          try {
            await raf.close();
          } catch (_) {
            // Already closed by the failure that brought us here.
          }
        }
      }
    }

    // A stream can end early without an error — a proxy timing out, a dev
    // server giving up, a connection dropped cleanly. That leaves a short file
    // whose hash cannot match, and hashing it first would condemn perfectly
    // good bytes as corrupt. Length is checked first precisely so an
    // interrupted transfer stays resumable instead of starting over.
    final onDisk = await part.exists() ? await part.length() : 0;
    if (onDisk < f.bytes) {
      throw ModelDownloadException(
        'The connection ended before ${f.name} finished. '
        'Everything downloaded so far has been kept.',
        resumable: true,
      );
    }

    _emit(_progress.copyWith(
      state: DownloadState.verifying,
      received: cumulative,
    ));

    final digest = await _sha256OfFile(part);
    if (digest != f.sha256) {
      // A complete file with the wrong hash is genuinely corrupt or from
      // another version — the one case where discarding is the right call,
      // because resuming would build on bad data forever.
      if (await part.exists()) await part.delete();
      throw ModelDownloadException(
        'The downloaded files did not verify. Starting that file again.',
      );
    }

    // Rename only after the checksum passes, so a file under its final name is
    // always one that has been verified — including after a crash mid-download.
    await part.rename((await ModelRepository.I.fileFor(f.name)).path);

    return cumulative;
  }

  /// Hashes the file in chunks. The largest model is 175 MB; reading it into
  /// memory to hash it would risk an OOM on the low-end phones this app targets.
  Future<String> _sha256OfFile(File file) async {
    final output = _DigestSink();
    final input = sha256.startChunkedConversion(output);
    await for (final chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    return output.value.toString();
  }

  /// Stops the transfer, keeping everything downloaded so far.
  void pause() {
    if (!_running) return;
    _pausedByUser = true;
    _stopRequested = true;
    _cancel?.cancel('paused');
  }

  /// Throws away the bundle, including partials.
  Future<void> deleteDownloaded() async {
    // Back to online: without the files, offline mode is a promise the app
    // cannot keep, and the next scan would fail rather than simply going over
    // the network.
    await AppModeService.I.set(AppMode.online);
    pause();
    // Let the byte loop notice the stop and release its handle on the file
    // before deleting underneath it.
    while (_running) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await ModelRepository.I.deleteAll();
    unawaited(DeviceService.I.updateMode(modelsDownloaded: false));
    _emit(const DownloadProgress());
  }

  String _describe(Object e) {
    if (e is ModelDownloadException) return e.message;
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.connectionError:
          return 'No connection. The download will continue where it stopped.';
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'The connection stalled. Tap retry to continue.';
        default:
          final code = e.response?.statusCode;
          if (code == 404) return 'These files are no longer on the server.';
          return 'Download failed${code != null ? ' ($code)' : ''}.';
      }
    }
    if (e is FileSystemException) {
      return 'Not enough space on this phone to finish the download.';
    }
    return 'Download failed.';
  }

  @visibleForTesting
  void resetForTest() {
    _manifest = null;
    _running = false;
    _stopRequested = false;
    _dioCache = null;
    _progress = const DownloadProgress();
  }
}

/// Captures the single digest emitted at the end of a chunked hash.
class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// Raised inside the byte loop to unwind a paused download.
class _PausedByUser implements Exception {
  const _PausedByUser();
}

class ModelDownloadException implements Exception {
  final String message;

  /// True when the bytes on disk are still good and a retry should continue
  /// from where it stopped, rather than starting the file over.
  final bool resumable;

  ModelDownloadException(this.message, {this.resumable = false});
  @override
  String toString() => message;
}
