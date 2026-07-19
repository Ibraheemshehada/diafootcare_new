/// One tissue class the model considered, and what it concluded.
///
/// The tissue head is multi-label: a wound bed genuinely contains several
/// tissue types at once, and each class carries its own tuned threshold. The
/// analysis used to report a single winning label, which threw away the rest of
/// that answer and made the reported type turn on hundredths — on one real
/// photograph necrosis scored 0.9887 on the phone and 0.9749 on the server
/// while callus scored 0.9787 and 0.9911, so the same wound was described as
/// necrotic in one mode and callused in the other.
///
/// Keeping every class, its probability and the threshold it was judged
/// against means the record says what the model actually found, and a clinician
/// can see that a wound was 0.53 callus rather than being told "callus".
class TissueFinding {
  /// Lowercase class name: epithelial, granulation, necrosis, callus, slough.
  final String type;

  /// The model's probability for this class, 0..1.
  final double probability;

  /// Whether [probability] cleared [thresholdUsed].
  final bool isPresent;

  /// The threshold this class was judged against. Recorded per finding rather
  /// than looked up later: thresholds are tuned per class and will be retuned,
  /// and a stored result must stay interpretable against the threshold that
  /// actually produced it.
  final double thresholdUsed;

  const TissueFinding({
    required this.type,
    required this.probability,
    required this.isPresent,
    required this.thresholdUsed,
  });

  /// Tissue classes in descending clinical seriousness.
  ///
  /// Used to choose the headline among findings that are all present. Necrotic
  /// and sloughy tissue are devitalised and drive debridement decisions, so they
  /// outrank the rest; granulation and epithelium are signs of healing. Callus
  /// sits between them: it is a pressure finding worth naming, but a bed that is
  /// mostly granulating should not be headlined as callus, so it ranks below.
  static const List<String> severityOrder = [
    'necrosis', 'slough', 'granulation', 'callus', 'epithelial',
  ];

  String get displayName =>
      type.isEmpty ? 'Unknown' : type[0].toUpperCase() + type.substring(1);

  Map<String, dynamic> toJson() => {
        'type': type,
        'probability': probability,
        'is_present': isPresent,
        'threshold_used': thresholdUsed,
      };

  factory TissueFinding.fromJson(Map<String, dynamic> j) => TissueFinding(
        type: j['type'] as String? ?? 'unknown',
        probability: (j['probability'] as num?)?.toDouble() ?? 0.0,
        isPresent: j['is_present'] as bool? ?? false,
        thresholdUsed: (j['threshold_used'] as num?)?.toDouble() ?? 0.5,
      );

  @override
  String toString() =>
      '$type ${probability.toStringAsFixed(3)}'
      '${isPresent ? " (present, >= $thresholdUsed)" : ""}';
}

/// Helpers over a set of findings.
extension TissueFindings on List<TissueFinding> {
  List<TissueFinding> get present => where((f) => f.isPresent).toList();

  /// The single label to show where only one fits.
  ///
  /// The most clinically serious class that is present, not the highest
  /// scoring one. Ranking by probability let a hundredth of a point decide
  /// between necrosis and callus; severity cannot move that way, and when it is
  /// wrong it is wrong towards attention rather than away from it.
  ///
  /// With nothing present it falls back to the most probable class, so the
  /// field is never blank.
  String get primaryType {
    if (isEmpty) return 'Unknown';

    final candidates = present.isNotEmpty ? present : toList();

    final best = candidates.reduce((a, b) {
      final ia = TissueFinding.severityOrder.indexOf(a.type);
      final ib = TissueFinding.severityOrder.indexOf(b.type);
      if (ia != ib) {
        // An unknown class sorts last rather than first.
        if (ia < 0) return b;
        if (ib < 0) return a;
        return ia < ib ? a : b;
      }
      return a.probability >= b.probability ? a : b;
    });

    return best.displayName;
  }

  /// Every present class, most serious first — "Necrosis, Slough, Callus".
  String get summary {
    final p = present.toList()
      ..sort((a, b) {
        final ia = TissueFinding.severityOrder.indexOf(a.type);
        final ib = TissueFinding.severityOrder.indexOf(b.type);
        if (ia != ib) return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
        return b.probability.compareTo(a.probability);
      });

    if (p.isEmpty) return primaryType;
    return p.map((f) => f.displayName).join(', ');
  }
}
