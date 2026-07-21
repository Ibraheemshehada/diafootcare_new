import 'package:diafootcare_new/core/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The mapping from what the app stores to what the server is told.
///
/// Infection and ischaemia use different vocabularies — 'Present'/'Not Present'
/// against 'Impaired'/'Adequate'. Only the first was handled, so every
/// ischaemia reading resolved to false and a wound with impaired blood flow
/// synced as infection-only. Found on a real device against the live server.
void main() {
  group('yes/no mapping', () {
    test('understands the infection vocabulary', () {
      expect(SyncService.yesNoForTest('Present'), isTrue);
      expect(SyncService.yesNoForTest('Not Present'), isFalse);
    });

    test('understands the ischaemia vocabulary', () {
      // The bug: neither of these matched, so both became null -> false.
      expect(SyncService.yesNoForTest('Impaired'), isTrue);
      expect(SyncService.yesNoForTest('Adequate'), isFalse);
    });

    test('"Not Present" is not read as present', () {
      // It contains the substring "present", so order of checks matters.
      expect(SyncService.yesNoForTest('Not Present'), isFalse);
      expect(SyncService.yesNoForTest('not present'), isFalse);
    });

    test('leaves genuinely unknown values null rather than guessing', () {
      expect(SyncService.yesNoForTest(null), isNull);
      expect(SyncService.yesNoForTest('N/A'), isNull);
      expect(SyncService.yesNoForTest(''), isNull);
    });
  });

  group('risk badge', () {
    test('both findings is the highest badge', () {
      // The case that regressed: the app showed "High Risk Detected" while the
      // server recorded "infection", because ischaemia never survived mapping.
      expect(SyncService.riskForTest('Present', 'Impaired'), 'high');
    });

    test('each finding alone', () {
      expect(SyncService.riskForTest('Present', 'Adequate'), 'infection');
      expect(SyncService.riskForTest('Not Present', 'Impaired'), 'ischaemia');
    });

    test('neither finding', () {
      expect(SyncService.riskForTest('Not Present', 'Adequate'), 'normal');
    });

    test('unknown inputs do not invent a finding', () {
      // An unreadable value must not become a positive: over-reporting risk on
      // a wound is its own harm, and the record should say nothing rather than
      // something wrong.
      expect(SyncService.riskForTest(null, null), 'normal');
      expect(SyncService.riskForTest('N/A', 'N/A'), 'normal');
    });
  });
}
