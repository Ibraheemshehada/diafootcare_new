import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import '../../features/wound/analysis/viewmodel/analysis_result.dart';

/// Thrown when the server could not analyse the photo.
///
/// Carries a message already fit to show a patient: the alternative is a
/// fabricated measurement, and a wrong number on a wound is worse than an
/// honest failure.
class RemoteAnalysisException implements Exception {
  final String message;

  /// True when trying again might work — a dropped connection rather than a
  /// photo the model cannot make sense of.
  final bool retryable;

  RemoteAnalysisException(this.message, {this.retryable = true});

  @override
  String toString() => message;
}

/// Runs the analysis on the server, for participants who chose online mode.
class RemoteAnalysisService {
  RemoteAnalysisService._();
  static final RemoteAnalysisService I = RemoteAnalysisService._();

  Future<AnalysisResult> analyse(
    String imagePath, {
    double? pixelsPerCm,
    double? manualDepthCm,
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw RemoteAnalysisException('That photo could not be found.',
          retryable: false);
    }

    try {
      final form = FormData.fromMap({
        'image': await MultipartFile.fromFile(imagePath),
        if (pixelsPerCm != null) 'pixels_per_cm': pixelsPerCm,
        if (manualDepthCm != null) 'manual_depth_cm': manualDepthCm,
      });

      final res = await ApiClient.I.dio.post(
        '/analyse',
        data: form,
        options: Options(
          // Longer than a normal API call: this is a second of model inference
          // plus however long a phone photo takes to upload on a weak
          // connection.
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      final a = Map<String, dynamic>.from(res.data['analysis'] as Map);
      return _fromJson(a);
    } on DioException catch (e) {
      throw RemoteAnalysisException(_describe(e), retryable: _retryable(e));
    } catch (e) {
      debugPrint('remote analysis failed: $e');
      throw RemoteAnalysisException('Analysis failed. Please try again.');
    }
  }

  AnalysisResult _fromJson(Map<String, dynamic> a) {
    double d(String k) => (a[k] as num?)?.toDouble() ?? 0.0;

    return AnalysisResult(
      length: d('length'),
      width: d('width'),
      depth: d('depth'),
      tissueFindings: (a['tissue_findings'] as List?)
              ?.map((f) => TissueFinding.fromJson(Map<String, dynamic>.from(f as Map)))
              .toList() ??
          const [],
      // Only used if the server is older than this client and sends just the
      // headline; the getter falls back to it when there are no findings.
      tissueType: a['tissue_type'] as String?,
      // Legacy fields, superseded by infection/ischaemia. Kept so the record
      // shape is identical whichever mode produced it.
      pusLevel: 'N/A',
      inflammation: 'N/A',
      infection: a['infection'] as String? ?? 'N/A',
      ischaemia: a['ischaemia'] as String? ?? 'N/A',
      riskBadge: a['risk_badge'] as String? ?? 'Normal',
      healingProgress: d('healing_progress'),
      isFromModel: a['is_from_model'] as bool? ?? true,
      isCalibrated: a['is_calibrated'] as bool? ?? false,
    );
  }

  bool _retryable(DioException e) {
    final code = e.response?.statusCode;
    // 422 means the server looked at the photo and could not use it. Retrying
    // the same image will fail the same way; a new photo is what is needed.
    return code != 422;
  }

  String _describe(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return 'No connection. Online analysis needs the internet — you can '
            'switch to offline analysis in your profile.';
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'The server took too long to respond. Please try again.';
      default:
        final code = e.response?.statusCode;
        if (code == 401) return 'Please sign in again to analyse this photo.';
        if (code == 422) {
          return 'That photo could not be analysed. Please retake it in '
              'better light, with the wound filling more of the frame.';
        }
        if (code == 429) return 'Too many analyses just now. Please wait a moment.';
        if (code == 503) return 'Analysis is temporarily unavailable. Please try again shortly.';
        return 'Analysis failed. Please try again.';
    }
  }
}
