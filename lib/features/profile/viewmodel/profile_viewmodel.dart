import 'package:flutter/material.dart';

class ProfileViewModel extends ChangeNotifier {
  String firstName = 'Ahmed';
  String lastName = 'Moh';
  String email = 'ahmed@gmail.com';
  String? avatarAsset = 'assets/images/user_avatar.png'; // placeholder

  String get fullName => '$firstName $lastName';

  void updateInfo({required String first, required String last, required String mail}) {
    firstName = first.trim();
    lastName = last.trim();
    email = mail.trim();
    notifyListeners();
  }

  // Stub for picking a photo; plug-in your image picker later.
  Future<void> pickNewPhoto() async {
    // TODO: implement actual picker
    notifyListeners();
  }
}