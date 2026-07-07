/// A fixed daily self-care task in the diabetic-foot check-in checklist.
///
/// Tasks are a static, curated list (not user-editable). Each task's [key] is a
/// stable id used both as the localization suffix (`selfcare_task_<key>` /
/// `selfcare_task_<key>_desc`) and as part of the per-day completion log key.
const List<String> selfCareTaskKeys = <String>[
  'foot_inspection',
  'wash_dry',
  'moisturize',
  'footwear',
  'wound_check',
];

/// Curated diabetic foot-care advice shown on the self-care screen.
/// Values are localization keys (`selfcare_do_*` / `selfcare_dont_*`).
const List<String> selfCareDoKeys = <String>[
  'selfcare_do_1',
  'selfcare_do_2',
  'selfcare_do_3',
  'selfcare_do_4',
  'selfcare_do_5',
  'selfcare_do_6',
  'selfcare_do_7',
  'selfcare_do_8',
];

const List<String> selfCareDontKeys = <String>[
  'selfcare_dont_1',
  'selfcare_dont_2',
  'selfcare_dont_3',
  'selfcare_dont_4',
  'selfcare_dont_5',
  'selfcare_dont_6',
];

/// One piece of foot-care advice, used for the rotating tip card.
/// [isDo] marks it as a "Do" (vs a "Don't"); [messageKey] is the l10n key.
class SelfCareTip {
  final bool isDo;
  final String messageKey;
  const SelfCareTip(this.isDo, this.messageKey);
}

/// Combined Do + Don't pool the rotating tip is drawn from.
final List<SelfCareTip> selfCareTips = <SelfCareTip>[
  for (final k in selfCareDoKeys) SelfCareTip(true, k),
  for (final k in selfCareDontKeys) SelfCareTip(false, k),
];

/// Stable key for one task on one day: "itemKey|yyyymmdd".
String selfCareLogKey(String itemKey, String dateKey) => '$itemKey|$dateKey';

/// yyyymmdd key for a date (local).
String selfCareDateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
