import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: const Color(0xff077FFF),
  colorScheme: ColorScheme.fromSeed(
    primary: const Color(0xff077FFF),
    seedColor: const Color(0xff077FFF),
    brightness: Brightness.light,
  ),
  cardColor: Colors.white,
  scaffoldBackgroundColor: Colors.white,
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
      unselectedLabelStyle: TextStyle(color: Colors.black),
      selectedLabelStyle: TextStyle(color: Color(0xff077FFF)),
      selectedItemColor: Color(0xff077FFF),
      unselectedItemColor: Colors.black
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: MaterialStateProperty.resolveWith(
          (states) =>
      states.contains(MaterialState.selected) ? const Color(0xff077FFF) : Colors.white,
    ),
  ),

  iconTheme: const IconThemeData(color: Colors.blue),

  textTheme: TextTheme(
    bodyMedium: TextStyle(color: Colors.black, fontSize: 14.sp),
    labelLarge: TextStyle(color: Colors.black, fontSize: 16.sp),
    titleLarge: TextStyle(color: Colors.black, fontSize: 18.sp),
    headlineLarge: TextStyle(color: const Color(0xff077FFF), fontSize: 22.sp),
  ),

  inputDecorationTheme: InputDecorationTheme(
    labelStyle: TextStyle(color: Colors.black, fontSize: 14.sp),
    hintStyle: TextStyle(color: Colors.black54, fontSize: 13.sp),
    errorStyle: TextStyle(color: Colors.red, fontSize: 12.sp),

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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      padding: EdgeInsets.symmetric(vertical: 16.h),
      minimumSize: Size(double.infinity, 55.h),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xff077FFF),
      side: const BorderSide(color: Color(0xff077FFF)),
      textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      padding: EdgeInsets.symmetric(vertical: 16.h),
      minimumSize: Size(double.infinity, 55.h),
    ),
  ),
);
