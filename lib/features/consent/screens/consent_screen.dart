import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/speak_button.dart';
import '../../../data/models/consent_record.dart';
import '../../../data/repositories/consent_repository.dart';

/// Data-sharing declaration.
///
/// Shown as a **blocking** gate at launch whenever the participant has not
/// accepted [kCurrentConsentVersion], and read-only from Profile afterwards.
///
/// The participant must scroll to the end before the accept control becomes
/// available. This is not decoration: a consent flow where "Accept" is reachable
/// without the text having been on screen is difficult to defend as informed.
class ConsentScreen extends StatefulWidget {
  /// When true the screen cannot be dismissed without a decision.
  final bool blocking;

  const ConsentScreen({super.key, this.blocking = true});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  final _repo = ConsentRepository();
  final _scroll = ScrollController();

  bool _agreed = false;
  bool _reachedEnd = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // If the text is short enough not to scroll on a large screen, the listener
    // never fires — resolve that after the first frame instead of trapping the
    // participant behind a condition they cannot satisfy.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    AnalyticsService.I.logTaskStart('consent_v$kCurrentConsentVersion');
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_reachedEnd || !_scroll.hasClients) return;

    final atEnd = !_scroll.position.hasContentDimensions ||
        _scroll.position.maxScrollExtent <= 0 ||
        _scroll.offset >= _scroll.position.maxScrollExtent - 24;

    if (atEnd && mounted) setState(() => _reachedEnd = true);
  }

  Future<void> _accept() async {
    if (!_agreed || _saving) return;
    setState(() => _saving = true);

    try {
      final record = ConsentRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        version: kCurrentConsentVersion,
        acceptedAt: DateTime.now(),
        locale: context.locale.languageCode,
        // The `app_version` column is intentionally left null for now: filling
        // it would mean taking on package_info_plus purely for an audit nicety.
        // The column exists so it can be populated once that dep is warranted.
        // v2's wording explicitly asks the participant to extend consent to
        // responses already stored on this device.
        coversPrior: true,
      );

      await _repo.record(record);
      await _repo.stampPriorSusResponses(kCurrentConsentVersion);

      AnalyticsService.I.logTaskComplete('consent_v$kCurrentConsentVersion');

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await showAppError(context, 'dialog_save_failed'.tr(), technicalDetail: e);
    }
  }

  Future<void> _decline() async {
    await showAppError(context, 'consent_decline_explain'.tr());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = consentBodyKey(kCurrentConsentVersion).tr();

    return PopScope(
      // A blocking consent gate must not be dismissable with the back gesture.
      canPop: !widget.blocking,
      child: Scaffold(
        appBar: AppBar(
          title: Text('consent_title'.tr()),
          automaticallyImplyLeading: !widget.blocking,
          actions: [
            SpeakButton(
              text: '${'consent_title'.tr()}. $body',
              analyticsName: 'consent_declaration',
            ),
          ],
        ),
        body: Column(
          children: [
            if (widget.blocking)
              Container(
                width: double.infinity,
                color: theme.colorScheme.primaryContainer,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Text(
                  'consent_required_notice'.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Expanded(
              child: Scrollbar(
                controller: _scroll,
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: EdgeInsets.all(16.w),
                  child: Text(
                    body,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _reachedEnd
                          ? () => setState(() => _agreed = !_agreed)
                          : null,
                      child: Row(
                        children: [
                          Checkbox(
                            value: _agreed,
                            onChanged: _reachedEnd
                                ? (v) => setState(() => _agreed = v ?? false)
                                : null,
                          ),
                          Expanded(
                            child: Text(
                              'consent_accept_label'.tr(),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8.h),
                    ConstrainedBox(
                      constraints: BoxConstraints(minHeight: 48.h),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: (_agreed && !_saving) ? _accept : null,
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : Text('consent_continue'.tr()),
                        ),
                      ),
                    ),
                    if (widget.blocking)
                      ConstrainedBox(
                        constraints: BoxConstraints(minHeight: 48.h),
                        child: TextButton(
                          onPressed: _decline,
                          child: Text('consent_decline'.tr()),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
