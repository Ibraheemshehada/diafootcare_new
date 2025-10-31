import 'package:flutter/foundation.dart';
import '../viewmodel/analysis_result.dart';

/// AI Service for wound analysis
/// Note: TFLite only works on Android/iOS when model is available
/// Web platform uses fallback simulation data
class AiService {
  static final AiService instance = AiService._();
  AiService._();

  bool _initialized = false;

  /// Initialize the AI service
  Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      debugPrint('ℹ️  Running on web platform');
      debugPrint('   Using simulation data (TFLite not available on web)');
    } else {
      debugPrint('ℹ️  Running on mobile platform');
      debugPrint('   Ready to load TFLite model when available');
      debugPrint('   Currently using simulation data');
    }

    _initialized = true;
  }

  /// Analyze wound image and return results
  Future<AnalysisResult> analyzeWound(String imagePath) async {
    if (!_initialized) {
      await init();
    }

    debugPrint('🔍 Analyzing wound image: $imagePath');
    
    // Simulate AI processing time
    await Future.delayed(const Duration(seconds: 2));

    final result = _getSimulatedResult();
    
    debugPrint('✅ Analysis complete!');
    debugPrint('   Length: ${result.length}mm, Width: ${result.width}mm');
    
    return result;
  }

  /// Get simulated analysis result
  AnalysisResult _getSimulatedResult() {
    debugPrint('⚠️  Using simulated AI data');
    debugPrint('   To use real AI:');
    debugPrint('   1. Train a TensorFlow Lite model');
    debugPrint('   2. Place it in assets/models/wound_segmentation.tflite');
    debugPrint('   3. Add tflite_flutter package for Android/iOS builds');
    
    return AnalysisResult(
      length: 8.1,
      width: 5.0,
      depth: 3.2,
      tissueType: 'Granulation',
      pusLevel: 'Moderate',
      inflammation: 'None',
      healingProgress: 45.0,
    );
  }

  /// Check if model is loaded
  bool get isModelLoaded => false;  // Always false in simulation mode

  /// Dispose resources
  void dispose() {
    _initialized = false;
    debugPrint('🗑️  AI service disposed');
  }
}
