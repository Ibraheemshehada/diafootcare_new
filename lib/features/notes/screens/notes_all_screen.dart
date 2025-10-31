import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../viewmodel/notes_viewmodel.dart';
import '../widgets/note_card.dart';
class NotesAllScreen extends StatelessWidget {
  const NotesAllScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotesViewModel>();
    final items = vm.all;

    return Scaffold(
      appBar: AppBar(title: Text('recent_notes'.tr())),
      body: vm.loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: ScreenUtil().screenWidth >= 500 ? 3 : 2,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 12.h,
          childAspectRatio: 1.15,
        ),
        itemBuilder: (_, i) => NoteCard(note: items[i], index: i),
      ),
    );
  }
}