import 'package:flutter_test/flutter_test.dart';
import 'package:diafootcare_new/core/services/sync_service.dart';

/// The filename extension used when a wound photograph is uploaded.
///
/// This is here because of a bug that shipped and hid: the helper used
/// `RegExp(r'[/\]')`, and in a raw string that is a literal backslash before the
/// closing bracket, so the character class was never closed. It threw
/// `FormatException: Unterminated character class` on **every** call, which the
/// sync loop caught and logged as an upload failure — so no wound photograph
/// ever reached the server, and every pass retried for ever.
///
/// It compiled. Analysis was clean. Unit tests passed. It was invisible until
/// the app ran on a device and the log showed the same throw once a minute.
///
/// So the point of these tests is not the extensions. It is that this function
/// is **called at all**, on the path shapes it actually sees.
void main() {
  group('_extensionOf', () {
    test('takes the extension from a POSIX path', () {
      expect(SyncService.extensionOfForTest('/data/user/0/app/files/x.jpg'), '.jpg');
      expect(SyncService.extensionOfForTest('/sdcard/DCIM/photo.jpeg'), '.jpeg');
      expect(SyncService.extensionOfForTest('/a/b/overlay.png'), '.png');
    });

    test('takes it from a Windows path too', () {
      // Overlays are written beside the photograph, and a desktop test run
      // hands this Windows separators.
      expect(SyncService.extensionOfForTest(r'C:\Users\x\wound.jpg'), '.jpg');
      expect(SyncService.extensionOfForTest(r'D:\scans\a_overlay.png'), '.png');
    });

    test('falls back to .jpg rather than inventing one', () {
      expect(SyncService.extensionOfForTest('/data/files/photo'), '.jpg');
      expect(SyncService.extensionOfForTest('photo'), '.jpg');
      expect(SyncService.extensionOfForTest(''), '.jpg');
    });

    test('a dot in a directory name is not an extension', () {
      // The failure this guards against is subtle: '.app/photo' would otherwise
      // yield '.app/photo' as the extension.
      expect(SyncService.extensionOfForTest('/data/tech.diafootcare.app/photo'),
          '.jpg');
      expect(SyncService.extensionOfForTest(r'C:\my.folder\photo'), '.jpg');
    });

    test('never throws, whatever the path looks like', () {
      for (final p in <String>[
        '',
        '/',
        r'\',
        '...',
        '/a/b/c.',
        'no-slash-no-dot',
        '/unicode/جرح.jpg',
      ]) {
        expect(() => SyncService.extensionOfForTest(p), returnsNormally,
            reason: 'threw on: $p');
      }
    });
  });
}
