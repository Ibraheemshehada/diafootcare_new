import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/widgets/app_dialogs.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _oldObscure = true, _newObscure = true, _confirmObscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('change_password'.tr())),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('old_password'.tr(), style: t.textTheme.labelLarge),
                SizedBox(height: 6.h),
                TextFormField(
                  controller: _old,
                  obscureText: _oldObscure,
                  validator: _required,
                  decoration: InputDecoration(
                    hintText: 'enter_old_password'.tr(),
                    suffixIcon: IconButton(
                      tooltip:
                          _oldObscure
                              ? 'a11y_show_password'.tr()
                              : 'a11y_hide_password'.tr(),
                      icon: Icon(
                        _oldObscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed:
                          () => setState(() => _oldObscure = !_oldObscure),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Text('new_password'.tr(), style: t.textTheme.labelLarge),
                SizedBox(height: 6.h),
                TextFormField(
                  controller: _new,
                  obscureText: _newObscure,
                  validator: _min6,
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      tooltip:
                          _newObscure
                              ? 'a11y_show_password'.tr()
                              : 'a11y_hide_password'.tr(),
                      icon: Icon(
                        _newObscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed:
                          () => setState(() => _newObscure = !_newObscure),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Text('confirm_password'.tr(), style: t.textTheme.labelLarge),
                SizedBox(height: 6.h),
                TextFormField(
                  controller: _confirm,
                  obscureText: _confirmObscure,
                  validator: (v) => v != _new.text ? 'doesnt_match'.tr() : null,
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      tooltip:
                          _confirmObscure
                              ? 'a11y_show_password'.tr()
                              : 'a11y_hide_password'.tr(),
                      icon: Icon(
                        _confirmObscure
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed:
                          () => setState(
                            () => _confirmObscure = !_confirmObscure,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          ConstrainedBox(
            // minHeight (not an exact height): keeps the >=48dp touch
            // target while letting the button grow when the user
            // enlarges the system font. An exact height clipped labels.
            constraints: BoxConstraints(
              minWidth: double.infinity,
              minHeight: 48.h,
            ),
            child: FilledButton(
              onPressed: _isLoading ? null : _updatePassword,
              child:
                  _isLoading
                      ? SizedBox(
                        height: 20.sp,
                        width: 20.sp,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(
                        'update_password'.tr(),
                        style: TextStyle(fontSize: 16.sp),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.isEmpty) ? 'required'.tr() : null;
  String? _min6(String? v) =>
      (v == null || v.length < 6)
          ? 'min_chars'.tr(namedArgs: {'n': '6'})
          : null;

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      if (!mounted) return;
      await showAppError(context, 'user_not_logged_in'.tr());
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Re-authenticate with old password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _old.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(_new.text.trim());
      await user.reload();

      if (!mounted) return;
      await showAppSuccess(context, 'password_updated_successfully'.tr());
      if (!mounted) return;
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMessage = 'password_update_failed'.tr();

      if (e.code == 'wrong-password') {
        errorMessage = 'incorrect_old_password'.tr();
      } else if (e.code == 'weak-password') {
        errorMessage = 'password_too_weak'.tr();
      } else if (e.code == 'requires-recent-login') {
        errorMessage = 'requires_recent_login'.tr();
      }

      await showAppError(context, errorMessage);
    } catch (e) {
      if (!mounted) return;
      await showAppError(
        context,
        'password_update_failed'.tr(),
        technicalDetail: e,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
