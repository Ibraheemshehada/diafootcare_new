import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ProfileViewModel extends ChangeNotifier {
  String firstName = '';
  String lastName = '';
  String email = '';
  String? avatarAsset; // Legacy asset path (not used anymore)
  File? avatarFile; // Actual photo file path

  ProfileViewModel() {
    _loadUserData();
  }

  String get fullName => '$firstName $lastName'.trim();
  bool get hasData => firstName.isNotEmpty && lastName.isNotEmpty && email.isNotEmpty;

  // Load user data from SharedPreferences
  Future<void> _loadUserData() async {
    await refreshUserData();
  }
  
  // Public method to refresh user data (can be called after signup/login)
  Future<void> refreshUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      firstName = prefs.getString('user_firstName') ?? '';
      lastName = prefs.getString('user_lastName') ?? '';
      email = prefs.getString('user_email') ?? '';

      // Load profile photo path (only on non-web platforms)
      if (!kIsWeb) {
        final photoPath = prefs.getString('user_photoPath');
        if (photoPath != null && photoPath.isNotEmpty) {
          final file = File(photoPath);
          if (await file.exists()) {
            avatarFile = file;
            debugPrint('📸 Profile photo loaded from: $photoPath');
          } else {
            // Photo file doesn't exist, clear the reference
            await prefs.remove('user_photoPath');
          }
        }
      }

      // If no local data, try to get from Firebase
      if (firstName.isEmpty && lastName.isEmpty) {
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          email = firebaseUser.email ?? email;
          final displayName = firebaseUser.displayName;
          if (displayName != null && displayName.isNotEmpty) {
            final parts = displayName.split(' ');
            firstName = parts.first;
            lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
            
            // Save back to SharedPreferences if we got it from Firebase
            if (firstName.isNotEmpty) {
              await prefs.setString('user_firstName', firstName);
              await prefs.setString('user_lastName', lastName);
              await prefs.setString('user_email', email);
              await prefs.setString('user_fullName', displayName);
            }
          }
        }
      }

      notifyListeners();
      debugPrint('📱 User data loaded: $firstName $lastName ($email)');
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
    }
  }

  // Update user info and save locally
  Future<void> updateInfo({
    required String first,
    required String last,
    required String mail,
  }) async {
    firstName = first.trim();
    lastName = last.trim();
    email = mail.trim();

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_firstName', firstName);
    await prefs.setString('user_lastName', lastName);
    await prefs.setString('user_email', email);
    await prefs.setString('user_fullName', fullName);

    // Update Firebase display name
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(fullName);
        await user.reload();
      }
    } catch (e) {
      debugPrint('⚠️ Could not update Firebase display name: $e');
    }

    notifyListeners();
    debugPrint('💾 User info updated: $fullName ($email)');
  }

  // Pick a new photo from camera or gallery (fallback method - tries camera first)
  Future<void> pickNewPhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      
      // Try camera first, fallback to gallery if camera fails
      XFile? pickedFile;
      try {
        pickedFile = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 800,
          maxHeight: 800,
        );
      } catch (e) {
        debugPrint('⚠️ Camera error: $e, trying gallery...');
        pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 800,
          maxHeight: 800,
        );
      }

      if (pickedFile == null) {
        debugPrint('❌ No image selected');
        return;
      }

      await _savePhotoFile(pickedFile);
    } catch (e) {
      debugPrint('❌ Error picking photo: $e');
    }
  }
  
  // Internal method to save photo file
  Future<void> _savePhotoFile(XFile pickedFile) async {
    if (kIsWeb) {
      // Web: just save the path temporarily (web doesn't support File operations the same way)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_photoPath', pickedFile.path);
      notifyListeners();
      debugPrint('✅ Profile photo path saved (web): ${pickedFile.path}');
      return;
    }
    
    try {
      // Save photo to app documents directory
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String fileName = 'profile_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String savedPath = path.join(appDocDir.path, fileName);

      // Copy the picked file to our app directory
      final File savedFile = await File(pickedFile.path).copy(savedPath);
      avatarFile = savedFile;

      // Save path to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_photoPath', savedPath);

      notifyListeners();
      debugPrint('✅ Profile photo saved to: $savedPath');
    } catch (e) {
      debugPrint('❌ Error saving photo file: $e');
    }
  }
  
  // Pick photo with source selection dialog
  Future<void> pickPhotoWithSource(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      
      // Show bottom sheet to choose source
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile == null) {
        debugPrint('❌ No image selected');
        return;
      }

      await _savePhotoFile(pickedFile);
    } catch (e) {
      debugPrint('❌ Error picking photo: $e');
    }
  }
  
  // Get avatar image provider for displaying
  ImageProvider? get avatarImageProvider {
    if (kIsWeb) {
      // Web: return null for now (would need to use NetworkImage or similar)
      return null;
    }
    if (avatarFile != null && avatarFile!.existsSync()) {
      return FileImage(avatarFile!);
    }
    return null;
  }
  
  // Check if user has a photo
  bool get hasPhoto {
    if (kIsWeb) {
      // Web: check SharedPreferences for path
      return false; // Simplified for now
    }
    return avatarFile != null && avatarFile!.existsSync();
  }
}