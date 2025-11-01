import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../models/wound_entry.dart';
import '../../features/wound/analysis/viewmodel/analysis_result.dart';

class WoundsRepository {
  static final WoundsRepository _instance = WoundsRepository._();
  factory WoundsRepository() => _instance;
  WoundsRepository._();

  Future<Database> get _db => DatabaseHelper().database;

  /// Save a wound analysis result to the database
  Future<int> saveWoundResult({
    required String imagePath,
    required AnalysisResult result,
  }) async {
    try {
      final db = await _db;
      final now = DateTime.now();
      
      final id = await db.insert(
        'wounds',
        {
          'date': now.toIso8601String(),
          'imagePath': imagePath,
          'length': result.length,
          'width': result.width,
          'depth': result.depth,
          'tissueType': result.tissueType,
          'pusLevel': result.pusLevel,
          'inflammation': result.inflammation,
          'healingProgress': result.healingProgress,
          'createdAt': now.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('✅ Wound result saved to database with ID: $id');
      return id;
    } catch (e) {
      debugPrint('❌ Error saving wound result: $e');
      rethrow;
    }
  }

  /// Load all wound entries from database
  Future<List<WoundEntry>> loadAllWounds() async {
    try {
      final db = await _db;
      final List<Map<String, dynamic>> maps = await db.query(
        'wounds',
        orderBy: 'date DESC',
      );

      return maps.map((map) {
        final dateStr = map['date'] as String;
        final date = DateTime.parse(dateStr);
        
        // Calculate progress percentage (compare with previous entry if available)
        final length = (map['length'] as num).toDouble();
        final width = (map['width'] as num).toDouble();
        final depth = map['depth'] != null ? (map['depth'] as num).toDouble() : null;
        
        return WoundEntry(
          id: map['id'] as int?,
          date: date,
          imagePath: map['imagePath'] as String? ?? '',
          lengthCm: length,
          widthCm: width,
          depthCm: depth,
          inflammation: map['inflammation'] as String? ?? 'None',
          progressPct: _calculateProgress(length, width),
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error loading wounds: $e');
      return [];
    }
  }

  /// Load a single wound entry by ID
  Future<WoundEntry?> loadWoundById(int id) async {
    try {
      final db = await _db;
      final List<Map<String, dynamic>> maps = await db.query(
        'wounds',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) return null;

      final map = maps.first;
      final dateStr = map['date'] as String;
      final date = DateTime.parse(dateStr);
      
      final length = (map['length'] as num).toDouble();
      final width = (map['width'] as num).toDouble();
      final depth = map['depth'] != null ? (map['depth'] as num).toDouble() : null;

      return WoundEntry(
        id: map['id'] as int?,
        date: date,
        imagePath: map['imagePath'] as String? ?? '',
        lengthCm: length,
        widthCm: width,
        depthCm: depth,
        inflammation: map['inflammation'] as String? ?? 'None',
        progressPct: _calculateProgress(length, width),
      );
    } catch (e) {
      debugPrint('❌ Error loading wound by ID: $e');
      return null;
    }
  }

  /// Get full analysis result from database
  Future<AnalysisResult?> getAnalysisResultById(int id) async {
    try {
      final db = await _db;
      final List<Map<String, dynamic>> maps = await db.query(
        'wounds',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) return null;

      final map = maps.first;
      return AnalysisResult(
        length: (map['length'] as num).toDouble(),
        width: (map['width'] as num).toDouble(),
        depth: (map['depth'] as num?)?.toDouble() ?? 0.0,
        tissueType: map['tissueType'] as String? ?? 'Unknown',
        pusLevel: map['pusLevel'] as String? ?? 'Unknown',
        inflammation: map['inflammation'] as String? ?? 'None',
        healingProgress: (map['healingProgress'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      debugPrint('❌ Error loading analysis result: $e');
      return null;
    }
  }

  /// Delete a wound entry
  Future<void> deleteWound(int id) async {
    try {
      final db = await _db;
      await db.delete(
        'wounds',
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('✅ Wound entry deleted: $id');
    } catch (e) {
      debugPrint('❌ Error deleting wound: $e');
      rethrow;
    }
  }

  /// Get total count of wounds
  Future<int> getTotalCount() async {
    try {
      final db = await _db;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM wounds');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting wound count: $e');
      return 0;
    }
  }

  /// Calculate progress percentage (simplified - can be enhanced)
  double _calculateProgress(double length, double width) {
    // Simple calculation: progress based on area reduction
    // This can be enhanced to compare with previous entries
    final area = length * width;
    // Assume baseline of 100cm², calculate progress
    return ((100 - area) / 100 * 100).clamp(0.0, 100.0);
  }
}

