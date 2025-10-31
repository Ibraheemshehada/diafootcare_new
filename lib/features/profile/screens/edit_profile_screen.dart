import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../viewmodel/profile_viewmodel.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _first;
  late TextEditingController _last;
  late TextEditingController _email;

  @override
  void initState() {
    super.initState();
    final vm = context.read<ProfileViewModel>();
    _first = TextEditingController(text: vm.firstName);
    _last = TextEditingController(text: vm.lastName);
    _email = TextEditingController(text: vm.email);
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final vm = context.watch<ProfileViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text('edit_info'.tr())),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        children: [
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 48.r,
                  backgroundImage: vm.avatarAsset != null ? AssetImage(vm.avatarAsset!) : null,
                  child: vm.avatarAsset == null ? const Icon(Icons.person, size: 32) : null,
                ),
                InkWell(
                  onTap: () => vm.pickNewPhoto(),
                  child: Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(color: t.colorScheme.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 6.h),
          Center(
            child: TextButton(onPressed: () => vm.pickNewPhoto(), child: Text('update_photo'.tr())),
          ),

          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('first_name'.tr(), style: t.textTheme.labelLarge),
                SizedBox(height: 6.h),
                TextFormField(controller: _first, validator: _notEmpty, decoration: InputDecoration(hintText: 'first_name'.tr())),
                SizedBox(height: 12.h),
                Text('last_name'.tr(), style: t.textTheme.labelLarge),
                SizedBox(height: 6.h),
                TextFormField(controller: _last, validator: _notEmpty, decoration: InputDecoration(hintText: 'last_name'.tr())),
                SizedBox(height: 12.h),
                Text('email_or_phone'.tr(), style: t.textTheme.labelLarge),
                SizedBox(height: 6.h),
                TextFormField(controller: _email, validator: _notEmpty, decoration: InputDecoration(hintText: 'email_or_phone'.tr())),
              ],
            ),
          ),

          SizedBox(height: 20.h),
          SizedBox(
            height: 48.h,
            child: FilledButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                vm.updateInfo(first: _first.text, last: _last.text, mail: _email.text);
                Navigator.pop(context);
              },
              child: Text('edit'.tr(), style: TextStyle(fontSize: 16.sp)),
            ),
          ),
        ],
      ),
    );
  }

  String? _notEmpty(String? v) => (v == null || v.trim().isEmpty) ? 'required'.tr() : null;
}
