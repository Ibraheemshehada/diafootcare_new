import '../local/database_helper.dart';
import '../models/consent_record.dart';

/// Read/write access to the participant consent audit trail.
///
/// Deliberately has **no delete method**. A consent record is evidence of what a
/// participant agreed to; withdrawing consent is recorded by superseding it, not
/// by erasing the fact that it was once given.
class ConsentRepository {
  final _helper = DatabaseHelper();

  Future<List<ConsentRecord>> getAll() async {
    final db = await _helper.database;
    final rows = await db.query('consents', orderBy: 'accepted_at DESC');
    return rows.map(ConsentRecord.fromMap).toList();
  }

  /// The highest consent version this participant has accepted, or `null` if
  /// they have never accepted one.
  Future<int?> acceptedVersion() async {
    final db = await _helper.database;
    final rows = await db.query(
      'consents',
      columns: ['version'],
      orderBy: 'version DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['version'] as int?;
  }

  /// Whether the participant has accepted the declaration currently in force.
  Future<bool> hasCurrentConsent() async {
    final v = await acceptedVersion();
    return v != null && v >= kCurrentConsentVersion;
  }

  Future<void> record(ConsentRecord record) async {
    final db = await _helper.database;
    await db.insert('consents', record.toMap());
  }

  /// Stamps SUS responses that predate consent versioning.
  ///
  /// Only fills rows where `consent_version IS NULL`, and only when the
  /// participant accepted a declaration that explicitly said it covered
  /// responses already on the device. Rows already carrying a version are never
  /// rewritten — a participant cannot be retroactively moved between consent
  /// populations by a later acceptance.
  Future<int> stampPriorSusResponses(int version) async {
    final db = await _helper.database;
    return db.update(
      'sus_responses',
      {'consent_version': version},
      where: 'consent_version IS NULL',
    );
  }
}
