import 'package:diafootcare_new/core/services/auth_services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The three-state session result.
///
/// This exists because collapsing "no session" and "offline with a session"
/// into a single null locked a signed-in patient out of an offline-first app
/// the moment they lost connectivity — with every one of their records sitting
/// on the device. The distinction is the fix, so it is pinned here.
void main() {
  group('SessionResult', () {
    test('a signed-out result sends the user to login', () {
      const r = SessionResult(SessionStatus.signedOut);
      expect(r.canProceed, isFalse);
      expect(r.user, isNull);
    });

    test('a verified result carries the user and proceeds', () {
      const user = AppUser(
        id: 1, name: 'Amal', role: 'patient', locale: 'ar', patientId: 4,
      );
      const r = SessionResult(SessionStatus.verified, user);
      expect(r.canProceed, isTrue);
      expect(r.user?.name, 'Amal');
    });

    test('an unverified (offline) result proceeds despite having no user', () {
      const r = SessionResult(SessionStatus.unverified);
      // The critical assertion: no user object, but still a session. Treating
      // this as signed-out is the bug.
      expect(r.user, isNull);
      expect(r.canProceed, isTrue,
          reason: 'offline must not send a signed-in patient to a login screen '
              'they cannot complete without a network');
    });

    test('only signedOut blocks entry', () {
      for (final s in SessionStatus.values) {
        expect(SessionResult(s).canProceed, s != SessionStatus.signedOut,
            reason: '$s should ${s == SessionStatus.signedOut ? "block" : "allow"} entry');
      }
    });
  });

  group('AppUser', () {
    test('falls back to email, then a generic label, for a display name', () {
      const noName = AppUser(id: 1, name: '  ', email: 'a@b.c', role: 'patient', locale: 'en');
      expect(noName.displayName, 'a@b.c');

      const anonymous = AppUser(id: 2, name: '', role: 'patient', locale: 'en');
      expect(anonymous.displayName, 'Participant');
    });

    test('parses a guest payload without an email', () {
      final u = AppUser.fromMap(
        {'id': 5, 'name': 'Guest participant', 'role': 'patient', 'locale': 'ar', 'patient_id': 4},
        guest: true,
      );
      expect(u.isGuest, isTrue);
      expect(u.email, isNull);
      expect(u.patientId, 4);
    });
  });
}
