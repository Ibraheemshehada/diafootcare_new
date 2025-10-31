import 'package:flutter/material.dart';

class ServiceItem {
  final String title;
  final String subtitle;
  final String iconAsset;
  final String route;

  // Background art (optional)
  final String? bgSvgAsset;
  final double bgScale;     // 1.0 = same as tile size; 1.2 = 120% of tile
  final double bgOffsetX;   // in tile width units (+ right, - left). e.g., 0.1 = 10% right
  final double bgOffsetY;   // in tile height units (+ down, - up)
  final double bgOpacity;   // 0..1
  final Alignment bgAlignment; // where to anchor the art before offset

  final bool isPrimary;

  ServiceItem({
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.route,
    this.bgSvgAsset,
    this.bgScale = 1.0,
    this.bgOffsetX = 0.0,
    this.bgOffsetY = 0.0,
    this.bgOpacity = 0.08,
    this.bgAlignment = Alignment.centerRight,
    this.isPrimary = false,
  });
}
