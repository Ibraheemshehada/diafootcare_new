/// A participant's acceptance of a specific version of the data-sharing
/// declaration.
///
/// Records are **append-only**. Each acceptance is a new row, so the study can
/// always show which wording a given participant agreed to and when — including
/// after the text is revised again.
class ConsentRecord {
  final String id;
  final int version;
  final DateTime acceptedAt;

  /// UI language the declaration was displayed in. A participant who read the
  /// Arabic text consented to the Arabic text; if the two ever diverge in
  /// meaning, the study needs to know which one was actually shown.
  final String? locale;

  final String? appVersion;

  /// Whether this acceptance was presented as also covering responses already
  /// stored on the device from before this consent version existed.
  final bool coversPrior;

  const ConsentRecord({
    required this.id,
    required this.version,
    required this.acceptedAt,
    this.locale,
    this.appVersion,
    this.coversPrior = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'version': version,
        'accepted_at': acceptedAt.millisecondsSinceEpoch,
        'locale': locale,
        'app_version': appVersion,
        'covers_prior': coversPrior ? 1 : 0,
      };

  factory ConsentRecord.fromMap(Map<String, dynamic> m) => ConsentRecord(
        id: m['id'] as String,
        version: (m['version'] as int?) ?? 0,
        acceptedAt:
            DateTime.fromMillisecondsSinceEpoch((m['accepted_at'] as int?) ?? 0),
        locale: m['locale'] as String?,
        appVersion: m['app_version'] as String?,
        coversPrior: ((m['covers_prior'] as int?) ?? 0) == 1,
      );
}

/// The consent version currently in force.
///
/// **Bump this whenever the meaning of the declaration changes**, and the app
/// will re-prompt every participant. Never edit an existing version's text in a
/// way that changes what is being agreed to — that would silently attribute new
/// terms to an old signature.
///
/// * **v1** — original text: responses anonymous, not linked to medical data,
///   stored only on the device. No server involved.
/// * **v2** — data-sharing text: records sync to the DiaFootCare server, are
///   linked to the participant's account and clinical records, and are used for
///   the usability study and to improve the app. Explicitly asks the
///   participant to extend this to responses already stored on the device.
const int kCurrentConsentVersion = 2;

/// Localization key for the body of a given consent version.
///
/// Superseded versions keep their key so the exact wording a participant agreed
/// to stays retrievable and auditable.
String consentBodyKey(int version) => 'consent_v${version}_body';
