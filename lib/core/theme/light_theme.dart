import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Brand blue #077FFF only reaches **3.83:1** against white, so neither
/// "blue text on white" nor "white label on a blue button" met WCAG AA for
/// normal text. #0A61C9 is the same blue family at **5.89:1** — it passes in
/// both directions (contrast is symmetric). The original brand blue is kept
/// for the dark theme, where it sits on a dark surface.
const Color kPrimaryLight = Color(0xFF0A61C9);

/// Flutter's default light `hintColor` is `Colors.black38` → only **2.68:1**
/// on white, which fails even the large-text threshold. #5F6368 is **6.05:1**.
const Color kHintLight = Color(0xFF5F6368);

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: kPrimaryLight,
  hintColor: kHintLight,
  colorScheme: ColorScheme.fromSeed(
    primary: kPrimaryLight,
    seedColor: kPrimaryLight,
    brightness: Brightness.light,
  ),
  cardColor: Colors.white,
  scaffoldBackgroundColor: Colors.white,
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
      unselectedLabelStyle: TextStyle(color: Colors.black),
      selectedLabelStyle: TextStyle(color: kPrimaryLight),
      selectedItemColor: kPrimaryLight,
      unselectedItemColor: Colors.black
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: MaterialStateProperty.resolveWith(
          (states) =>
      states.contains(MaterialState.selected) ? kPrimaryLight : Colors.white,
    ),
  ),

  iconTheme: const IconThemeData(color: kPrimaryLight),

  textTheme: TextTheme(
    bodyMedium: TextStyle(color: Colors.black, fontSize: 14.sp),
    labelLarge: TextStyle(color: Colors.black, fontSize: 16.sp),
    titleLarge: TextStyle(color: Colors.black, fontSize: 18.sp),
    headlineLarge: TextStyle(color: kPrimaryLight, fontSize: 22.sp),
  ),

  inputDecorationTheme: InputDecorationTheme(
    labelStyle: TextStyle(color: Colors.black, fontSize: 14.sp),
    hintStyle: TextStyle(color: Colors.black54, fontSize: 13.sp),
    errorStyle: TextStyle(color: const Color(0xFFC62828), fontSize: 12.sp), // 5.62:1 on white

    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: const BorderSide(color: Colors.grey),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: const BorderSide(color: kPrimaryLight, width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: const BorderSide(color: Colors.grey),
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: kPrimaryLight,
      textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      padding: EdgeInsets.symmetric(vertical: 16.h),
      minimumSize: Size(double.infinity, 55.h),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: kPrimaryLight,
      side: const BorderSide(color: kPrimaryLight),
      textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      padding: EdgeInsets.symmetric(vertical: 16.h),
      minimumSize: Size(double.infinity, 55.h),
    ),
  ),
);
