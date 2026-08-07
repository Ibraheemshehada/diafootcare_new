/// Infection triage: fuses the image model's score with patient-reported signs.
///
/// ## Why this exists
/// The image head alone cannot solve this. Moving its threshold only slides
/// along one ROC curve — every point bought in sensitivity is paid for in
/// specificity. At the deployed 0.41 threshold, measured on the reproduced
/// cross-validation, specificity is 0.741; at a realistic 20% clinic prevalence
/// that puts **PPV at 0.45 — a positive alarm is more often wrong than right**.
/// See docs/IMPLEMENTATION_TRACKER.md §C3.
///
/// The way out is not a better threshold but **more information**.
///
/// ## The clinical ceiling
/// IWGDF/IDSA defines a local diabetic-foot infection as **purulent discharge**,
/// or **at least two** of: erythema, warmth, swelling/induration, tenderness,
/// purulent discharge. A photograph can show erythema and (sometimes) discharge
/// and swelling. It cannot feel **warmth**, cannot feel **tenderness**, cannot
/// smell, and cannot take a temperature — roughly two of the six signs are
/// visible at all. An image model is therefore working near an information
/// ceiling no amount of retraining lifts. Asking the patient supplies the
/// missing signs from an *independent* source, which is what actually moves the
/// operating curve rather than sliding along it.
///
/// ## How the model is used here
/// The image score is treated as **one sign among several** — the "appearance"
/// sign — not as the verdict. That mirrors how the criteria are applied
/// clinically and keeps a single noisy channel from deciding alone.
///
/// ## Deliberate safety properties
/// * **Absence of pain is never reassuring.** Diabetic neuropathy commonly
///   removes protective sensation, so a patient may feel nothing over a serious
///   infection. Signs are only ever *counted up*; a "no" never subtracts.
/// * **Symptoms can overrule a quiet image.** Two or more reported signs route
///   to a clinician even when the image looks unremarkable — the image model is
///   the least reliable channel here, not the most.
/// * **A loud image with no symptoms asks for a retake** rather than raising an
///   alarm, because lighting, angle and focus can inflate the score.
/// * **Systemic symptoms short-circuit everything** to urgent (possible
///   IWGDF grade 4).
/// * **Nothing here rules out deep infection.** Osteomyelitis is invisible to
///   both a photograph and this checklist; it needs probe-to-bone or imaging.
///   [deepInfectionCaveatKey] must be shown with every non-urgent outcome.
///
/// This is a **triage aid, not a diagnosis**. Inter-rater agreement on these
/// signs is only moderate between trained clinicians, so expect more noise from
/// patients; that is precisely why no single channel is allowed to decide.
library;

/// Confidence band for the image model's infection probability.
///
/// Two cut-offs instead of one. Forcing a binary claim onto an uncertain score
/// is what produced false alarms: the middle band now says "uncertain" out loud
/// instead of guessing. Measured at 20% prevalence, the bands below place 14.1%
/// of patients in [high] with **PPV 0.75** (against 0.45 for the single 0.41
/// threshold) while *also* lowering the missed-infection share from 2.9% to
/// 1.8% — better on both axes, because ambiguous cases stop being forced.
enum ImageZone {
  /// Below [kZoneLowMax] — appearance unremarkable.
  low,

  /// Between the cut-offs — genuinely uncertain; carries no weight alone.
  uncertain,

  /// At or above [kZoneHighMin] — appearance suggestive.
  high,
}

/// Upper bound of [ImageZone.low]. Chosen for a high negative predictive value
/// (0.966 at 20% prevalence) so reassurance is rarely wrong.
const double kZoneLowMax = 0.30;

/// Lower bound of [ImageZone.high]. Chosen for positive predictive value
/// (0.754 at 20% prevalence) so an alarm is usually real.
const double kZoneHighMin = 0.80;

/// Translation key for the caveat that must accompany every non-urgent result.
const String deepInfectionCaveatKey = 'infection_deep_caveat';

/// Band [p] — the image model's P(infection) — into an [ImageZone].
ImageZone zoneFor(double p) => p >= kZoneHighMin
    ? ImageZone.high
    : (p < kZoneLowMax ? ImageZone.low : ImageZone.uncertain);

/// The patient's answers. Every field is a plain yes/no the patient can judge
/// without training; the wording lives in the translation files under
/// `infection_q_*`.
///
/// Only signs the **camera cannot capture** are asked about. Erythema is left
/// to the image model, which sees it directly and judges it more consistently
/// than an untrained observer estimating "redness wider than half a centimetre".
class InfectionSigns {
  /// Yellow/green fluid or a bad smell. In IWGDF/IDSA purulent discharge is a
  /// **standalone criterion** — on its own it defines a local infection.
  final bool purulentDischarge;

  /// Warmer than the same spot on the other foot. Invisible to a camera.
  final bool warmth;

  /// Swelling or hardness (induration) around the wound.
  final bool swelling;

  /// Tender or painful to touch. A "no" is deliberately given **no** weight —
  /// see the neuropathy note above.
  final bool tenderness;

  /// Fever or feeling generally unwell — possible systemic involvement
  /// (IWGDF grade 4), which is an emergency rather than a routine review.
  final bool systemicUnwell;

  const InfectionSigns({
    this.purulentDischarge = false,
    this.warmth = false,
    this.swelling = false,
    this.tenderness = false,
    this.systemicUnwell = false,
  });

  /// Local signs the patient can report, excluding discharge (handled as a
  /// standalone criterion) and systemic symptoms (handled as an emergency).
  int get localSignCount =>
      (warmth ? 1 : 0) + (swelling ? 1 : 0) + (tenderness ? 1 : 0);

  /// True when the patient reported nothing at all.
  bool get isEmpty =>
      !purulentDischarge &&
      !warmth &&
      !swelling &&
      !tenderness &&
      !systemicUnwell;
}

/// What the app should tell the patient to do.
enum TriageOutcome {
  /// Nothing suggestive from either channel.
  noSigns,

  /// Some indication, not enough to act on: keep watching, photograph again.
  monitor,

  /// The image looks suggestive but the patient reports nothing. More likely a
  /// photography artefact than a silent infection, so ask for another photo
  /// before raising an alarm.
  recheckPhoto,

  /// The IWGDF/IDSA bar for a local infection is met: see a clinician.
  seeClinician,

  /// Possible systemic involvement — seek care now.
  urgent,
}

/// Result of fusing the image score with the checklist.
class TriageResult {
  final TriageOutcome outcome;
  final ImageZone zone;

  /// Total signs counted, image appearance included. The IWGDF/IDSA threshold
  /// for a local infection is two (or purulent discharge alone).
  final int signCount;

  /// Short machine-readable reason, for the record and for debugging.
  final String basis;

  const TriageResult({
    required this.outcome,
    required this.zone,
    required this.signCount,
    required this.basis,
  });

  /// Whether the deep-infection caveat should be shown alongside this result.
  /// True for everything except [TriageOutcome.urgent], where the patient is
  /// already being sent for care.
  bool get needsDeepInfectionCaveat => outcome != TriageOutcome.urgent;
}

/// Fuse the image model's probability with the patient's answers.
///
/// [infectionProbability] is P(infection) from the Model 3 head — that is
/// `p[infection] + p[both]`, the same quantity the deployed threshold is
/// applied to.
///
/// Order matters: systemic symptoms are checked first because they change the
/// urgency rather than the likelihood, and purulent discharge second because
/// IWGDF/IDSA treats it as sufficient on its own.
TriageResult triage({
  required double infectionProbability,
  required InfectionSigns signs,
}) {
  final zone = zoneFor(infectionProbability);

  // 1. Systemic involvement — possible IWGDF grade 4. Outranks everything.
  if (signs.systemicUnwell) {
    return TriageResult(
      outcome: TriageOutcome.urgent,
      zone: zone,
      signCount: signs.localSignCount + (signs.purulentDischarge ? 1 : 0),
      basis: 'systemic',
    );
  }

  // 2. Purulent discharge alone defines a local infection under IWGDF/IDSA.
  if (signs.purulentDischarge) {
    return TriageResult(
      outcome: TriageOutcome.seeClinician,
      zone: zone,
      signCount: signs.localSignCount + 1,
      basis: 'purulent_discharge',
    );
  }

  // 3. Count signs. The image contributes the "appearance" sign only when it is
  //    clearly suggestive; an uncertain score deliberately counts for nothing,
  //    because letting a coin-flip cast half a vote is how false alarms return.
  final imageSign = zone == ImageZone.high ? 1 : 0;
  final total = imageSign + signs.localSignCount;

  // 4. Two or more signs meets the IWGDF/IDSA bar for a local infection.
  if (total >= 2) {
    return TriageResult(
      outcome: TriageOutcome.seeClinician,
      zone: zone,
      signCount: total,
      // Recorded separately: two reported signs with a quiet image is the case
      // where the checklist caught what the model missed, and it is worth being
      // able to count those later.
      basis: imageSign == 0 ? 'symptoms_only' : 'image_and_symptoms',
    );
  }

  // 5. A loud image with nothing reported: verify the photograph first.
  if (zone == ImageZone.high) {
    return TriageResult(
      outcome: TriageOutcome.recheckPhoto,
      zone: zone,
      signCount: total,
      basis: 'image_only',
    );
  }

  // 6. One sign, or an uncertain image: watch it.
  if (total == 1 || zone == ImageZone.uncertain) {
    return TriageResult(
      outcome: TriageOutcome.monitor,
      zone: zone,
      signCount: total,
      basis: total == 1 ? 'single_sign' : 'image_uncertain',
    );
  }

  // 7. Nothing from either channel.
  return TriageResult(
    outcome: TriageOutcome.noSigns,
    zone: zone,
    signCount: 0,
    basis: 'none',
  );
}
