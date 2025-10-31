import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../viewmodel/notes_viewmodel.dart';
import '../widgets/note_card.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final vm = context.watch<NotesViewModel>();
    final locale = context.locale.toLanguageTag();
    final dateLabel = DateFormat.yMMMMEEEEd(locale).format(vm.selected);
    final recent = vm.recent(count: 8);

    return Scaffold(
      appBar: AppBar(title: Text('daily_notes'.tr()), backgroundColor: t.scaffoldBackgroundColor),
      body: vm.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        children: [
          Text(dateLabel, style: t.textTheme.titleSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          SizedBox(height: 10.h),

          TextField(
            controller: _controller,
            minLines: 6,
            maxLines: 10,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'describe_hint'.tr(),
              filled: true,
              fillColor: t.colorScheme.surfaceVariant.withOpacity(.25),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 48.h,
            child: FilledButton(
              onPressed: () async {
                final txt = _controller.text.trim();
                if (txt.isEmpty) return;
                await vm.addNote(date: vm.selected, text: txt);
                _controller.clear();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('saved'.tr())));
                }
              },
              child: Text('save'.tr(), style: TextStyle(fontSize: 16.sp)),
            ),
          ),

          SizedBox(height: 18.h),
          Row(
            children: [
              Expanded(child: Text('recent_notes'.tr(), style: t.textTheme.titleLarge)),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/notes/all'),
                child: Text('view_all'.tr()),
              ),
            ],
          ),

          GridView.builder(
            padding: EdgeInsets.only(top: 8.h),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recent.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ScreenUtil().screenWidth >= 500 ? 3 : 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (_, i) => NoteCard(note: recent[i], index: i),
          ),
        ],
      ),
    );
  }
}