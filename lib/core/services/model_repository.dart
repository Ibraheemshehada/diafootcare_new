import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One file in the offline analysis bundle, as described by the server.
class ModelFile {
  final String name;
  final int bytes;
  final String sha256;

  const ModelFile({required this.name, required this.bytes, required this.sha256});

  factory ModelFile.fromJson(Map<String, dynamic> j) => ModelFile(
        name: j['name'] as String,
        bytes: (j['bytes'] as num).toInt(),
        sha256: (j['sha256'] as String).toLowerCase(),
      );
}

/// The server's description of the current bundle.
class ModelManifest {
  final String version;
  final int totalBytes;
  final List<ModelFile> files;

  const ModelManifest({
    required this.version,
    required this.totalBytes,
    required this.files,
  });

  factory ModelManifest.fromJson(Map<String, dynamic> j) => ModelManifest(
        version: j['version'] as String,
        totalBytes: (j['total_bytes'] as num).toInt(),
        files: (j['files'] as List)
            .map((f) => ModelFile.fromJson(f as Map<String, dynamic>))
            .toList(),
      );
}

/// Where downloaded models live, and whether they are usable.
///
/// Files land in the app-support directory rather than external storage: they
/// are ~200 MB of app data the participant never needs to see, and on iOS
/// anything user-visible would also be backed up to iCloud, which is a waste of
/// their quota for bytes we can always re-fetch.
class ModelRepository {
  ModelRepository._();
  static final ModelRepository I = ModelRepository._();

  static const _versionKey = 'models_installed_version';

  Directory? _dir;

  Future<Directory> dir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}${Platform.pathSeparator}models');
    if (!await d.exists()) await d.create(recursive: true);
    _dir = d;
    return d;
  }

  Future<File> fileFor(String name) async =>
      File('${(await dir()).path}${Platform.pathSeparator}$name');

  /// The partial download for [name]. Kept beside the final file so a resume
  /// after an app restart finds it without any bookkeeping.
  Future<File> partFor(String name) async =>
      File('${(await dir()).path}${Platform.pathSeparator}$name.part');

  /// The manifest version whose files are fully installed, or null.
  Future<String?> installedVersion() async =>
      (await SharedPreferences.getInstance()).getString(_versionKey);

  Future<void> setInstalledVersion(String? v) async {
    final prefs = await SharedPreferences.getInstance();
    if (v == null) {
      await prefs.remove(_versionKey);
    } else {
      await prefs.setString(_versionKey, v);
    }
  }

  /// Whether every file in [manifest] is present at the expected size.
  ///
  /// Size only — the checksum was verified when the file was accepted, and
  /// re-hashing 200 MB on every launch would cost seconds of startup for a
  /// case that does not happen in practice. A truncated file (the realistic
  /// failure, from a device running out of space) is caught by the size check.
  Future<bool> isComplete(ModelManifest manifest) async {
    for (final f in manifest.files) {
      final file = await fileFor(f.name);
      if (!await file.exists()) return false;
      if (await file.length() != f.bytes) return false;
    }
    return true;
  }

  /// Bytes already on disk for [manifest], counting both finished files and
  /// partially downloaded ones, so a resumed download reports honest progress
  /// instead of restarting the bar at zero.
  Future<int> bytesOnDisk(ModelManifest manifest) async {
    var total = 0;
    for (final f in manifest.files) {
      final done = await fileFor(f.name);
      if (await done.exists()) {
        total += await done.length();
        continue;
      }
      final part = await partFor(f.name);
      if (await part.exists()) total += await part.length();
    }
    return total;
  }

  /// Removes the bundle. Used when switching to online mode to reclaim space,
  /// and when a manifest version change makes the local copy stale.
  Future<void> deleteAll() async {
    final d = await dir();
    if (await d.exists()) {
      await for (final e in d.list()) {
        if (e is File) await e.delete();
      }
    }
    await setInstalledVersion(null);
  }

  @visibleForTesting
  void resetForTest() => _dir = null;

  /// Discards partial downloads only, leaving verified files intact.
  Future<void> deletePartials() async {
    final d = await dir();
    if (!await d.exists()) return;
    await for (final e in d.list()) {
      if (e is File && e.path.endsWith('.part')) await e.delete();
    }
  }
}
