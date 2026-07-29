import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'analysis_exception.dart';
import '../network/api_client.dart';
import '../../features/wound/analysis/viewmodel/analysis_result.dart';

/// Thrown when the server could not analyse the photo.
///
/// Carries a message already fit to show a patient: the alternative is a
/// fabricated measurement, and a wrong number on a wound is worse than an
/// honest failure.
class RemoteAnalysisException implements AnalysisException {
  @override
  final String message;

  /// True when trying again might work — a dropped connection rather than a
  /// photo the model cannot make sense of.
  @override
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

      // ApiClient treats anything under 500 as a successful response so error
      // bodies stay readable, which means the status has to be checked here.
      // Without this a 401 or 422 fell through to parsing `data['analysis']`,
      // threw a cast error, and surfaced as the generic "Analysis failed" —
      // every specific message below was unreachable.
      final code = res.statusCode ?? 0;
      if (code != 200) {
        throw RemoteAnalysisException(
          _describeStatus(code, res.data),
          retryable: code != 422,
        );
      }

      final analysis = res.data is Map ? res.data['analysis'] : null;
      if (analysis is! Map) {
        throw RemoteAnalysisException('Analysis failed. Please try again.');
      }

      return _fromJson(Map<String, dynamic>.from(analysis));
    } on RemoteAnalysisException {
      rethrow;
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
      // Server sends the true segmented area as `area` (or `area_cm2` on older
      // builds). Fall back to the bounding-rectangle estimate (length × width)
      // only if neither is present.
      area: (a['area'] as num?)?.toDouble() ??
          (a['area_cm2'] as num?)?.toDouble() ??
          (d('length') * d('width')),
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
      analysedOn: 'online',
    );
  }

  /// Turns a status into something the reader can act on.
  ///
  /// The server's own message is preferred when it sent one — it knows more
  /// about why than a status code does.
  String _describeStatus(int code, dynamic body) {
    final fromServer =
        body is Map && body['message'] is String ? body['message'] as String : null;

    switch (code) {
      case 401:
        return 'Please sign in again to analyse this photo.';
      case 422:
        return fromServer ??
            'That photo could not be analysed. Please retake it in better '
                'light, with the wound filling more of the frame.';
      case 429:
        return 'Too many analyses just now. Please wait a moment.';
      case 503:
        return 'Analysis is temporarily unavailable. Please try again shortly.';
      default:
        return fromServer ?? 'Analysis failed. Please try again.';
    }
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
