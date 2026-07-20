/// A wound analysis that did not happen, and why.
///
/// Exists so the failure carries a message fit to show a patient. The
/// alternative — returning plausible-looking numbers — is indistinguishable
/// from a real measurement once it is on screen or in a record, and this is a
/// wound. A person who is told the analysis did not run can retake the photo or
/// call someone; a person shown an invented "8.1 × 5.0 cm, Normal" cannot.
abstract class AnalysisException implements Exception {
  String get message;

  /// True when trying again might work — a dropped connection rather than a
  /// photo the model cannot use, or files that are simply not installed.
  bool get retryable;
}
