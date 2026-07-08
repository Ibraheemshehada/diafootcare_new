import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Brand blue #077FFF only reaches 4.24:1 on the dark card (#1A2030), below
/// WCAG AA for normal text. #6FB1FF measures 7.28:1 on the card and 8.96:1
/// on the scaffold, so blue-on-dark text and icons are readable.
const Color kPrimaryDark = Color(0xFF6FB1FF);


final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: kPrimaryDark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kPrimaryDark,
    brightness: Brightness.dark,
  ),

  scaffoldBackgroundColor: const Color(0xFF020818),
  cardColor: Color(0xff1A2030),

  bottomNavigationBarTheme: BottomNavigationBarThemeData(

    unselectedLabelStyle: TextStyle(color: Colors.white),
    selectedLabelStyle: TextStyle(color: kPrimaryDark),
    selectedItemColor: kPrimaryDark,
    unselectedItemColor: Colors.white
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: MaterialStateProperty.resolveWith(
      (states) =>
          states.contains(MaterialState.selected)
              ? kPrimaryDark
              : Colors.white,
    ),
  ),

  iconTheme: const IconThemeData(color: kPrimaryDark),

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
      borderSide: const BorderSide(color: kPrimaryDark, width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: const BorderSide(color: Colors.grey),
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: kPrimaryDark,
      textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
      minimumSize: Size(double.infinity, 55.h),
      padding: EdgeInsets.symmetric(vertical: 16.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: kPrimaryDark,
      side: const BorderSide(color: kPrimaryDark),
      textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
      minimumSize: Size(double.infinity, 55.h),
      padding: EdgeInsets.symmetric(vertical: 16.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
    ),
  ),
);
