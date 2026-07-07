import 'package:flutter/material.dart';

/// A curated diabetic-foot-care education article. Content is static and
/// localized: the [key] maps to a set of localization keys
/// (`edu_<key>_title`, `_summary`, `_intro`, and `_b1`..`_bN`).
class EducationArticle {
  final String key;
  final IconData icon;
  final int bulletCount;
  const EducationArticle({
    required this.key,
    required this.icon,
    required this.bulletCount,
  });

  String get titleKey => 'edu_${key}_title';
  String get summaryKey => 'edu_${key}_summary';
  String get introKey => 'edu_${key}_intro';
  List<String> get bulletKeys =>
      List.generate(bulletCount, (i) => 'edu_${key}_b${i + 1}');
}

/// The curated foot-care guides shown in the Education hub.
const List<EducationArticle> educationArticles = <EducationArticle>[
  EducationArticle(
      key: 'foot_care', icon: Icons.wash_outlined, bulletCount: 5),
  EducationArticle(
      key: 'footwear', icon: Icons.directions_walk, bulletCount: 5),
  EducationArticle(
      key: 'blood_sugar', icon: Icons.bloodtype_outlined, bulletCount: 4),
  EducationArticle(
      key: 'warning_signs',
      icon: Icons.warning_amber_rounded,
      bulletCount: 5),
  EducationArticle(
      key: 'wound_care', icon: Icons.healing_outlined, bulletCount: 5),
];

/// Number of pharmacist-verified tips (`edu_pharm_1`..) and suggested
/// ask-your-pharmacist questions (`edu_ask_q1`..).
const int educationPharmacistTipCount = 4;
const int educationAskQuestionCount = 3;
