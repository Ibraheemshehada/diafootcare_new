import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xff077FFF),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xff077FFF),
    brightness: Brightness.dark,
  ),

  scaffoldBackgroundColor: const Color(0xFF020818),
  cardColor: Color(0xff1A2030),

  bottomNavigationBarTheme: BottomNavigationBarThemeData(

    unselectedLabelStyle: TextStyle(color: Colors.white),
    selectedLabelStyle: TextStyle(color: Color(0xff077FFF)),
    selectedItemColor: Color(0xff077FFF),
    unselectedItemColor: Colors.white
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: MaterialStateProperty.resolveWith(
      (states) =>
          states.contains(MaterialState.selected)
              ? const Color(0xff077FFF)
              : Colors.white,
    ),
  ),

  iconTheme: const IconThemeData(color: Color(0xff077FFF)),

  textTheme: TextTheme(
    bodyMedium: TextStyle(color: Colors.white, fontSize: 14.sp),
    labelLarge: TextStyle(color: Colors.white, fontSize: 16.sp),
    titleLarge: TextStyle(color: Colors.white, fontSize: 18.sp),
    headlineLarge: TextStyle(color: Colors.lightBlueAccent, fontSize: 22.sp),
  ),

  inputDecorationTheme: InputDecorationTheme(
    labelStyle: TextStyle(color: Colors.white, fontSize: 14.sp),
    hintStyle: TextStyle(color: Colors.white70, fontSize: 13.sp),
    errorStyle: TextStyle(color: Colors.redAccent, fontSize: 12.sp),

    // Borders with ScreenUtil
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: const BorderSide(color: Colors.grey),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: const BorderSide(color: Color(0xff077FFF), width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: const BorderSide(color: Colors.grey),
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: const Color(0xff077FFF),
      textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
      minimumSize: Size(double.infinity, 55.h),
      padding: EdgeInsets.symmetric(vertical: 16.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xff077FFF),
      side: const BorderSide(color: Color(0xff077FFF)),
      textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
      minimumSize: Size(double.infinity, 55.h),
      padding: EdgeInsets.symmetric(vertical: 16.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
    ),
  ),
);
