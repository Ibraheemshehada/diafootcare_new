import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ShutterButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool disabled;
  final double diameter; // optional override

  const ShutterButton({
    super.key,
    required this.onPressed,
    this.disabled = false,
    this.diameter = 66, // design size; will be scaled via .w
  });

  @override
  Widget build(BuildContext context) {
    final size = diameter.w;
    return IgnorePointer(
      ignoring: disabled,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: disabled ? Colors.red.withOpacity(.6) : Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4.w),
            boxShadow: [
              BoxShadow(
                blurRadius: 10.r,
                color: Colors.black26,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
