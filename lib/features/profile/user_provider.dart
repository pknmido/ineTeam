import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/services/user_service.dart';

/// Manages user profile state.
class UserProvider extends ChangeNotifier {
  final UserService _userService;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<UserModel?>? _profileSub;

  UserProvider({UserService? userService})
      : _userService = userService ?? UserService();

  // ─── Getters ─────────────────────────────────────────────────────────────
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ─── Load Profile ────────────────────────────────────────────────────────
  void loadProfile(String uid) {
    _profileSub?.cancel();
    _profileSub = _userService.userProfileStream(uid).listen((user) {
      _currentUser = user;
      notifyListeners();
    });
  }

  // ─── Update Profile ──────────────────────────────────────────────────────
  Future<bool> updateProfile({
    required String uid,
    String? name,
    List<String>? sports,
    int? skillLevel,
    Map<String, int>? sportRatings,
    String? frequency,
    String? profilePictureUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (sports != null) data['sports'] = sports;
      if (skillLevel != null) data['skillLevel'] = skillLevel;
      if (sportRatings != null) data['sportRatings'] = sportRatings;
      if (frequency != null) data['frequency'] = frequency;
      if (profilePictureUrl != null) data['profilePictureUrl'] = profilePictureUrl;

      await _userService.updateUserProfile(uid, data);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update profile.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Upload Picture ──────────────────────────────────────────────────────
  Future<bool> uploadProfilePicture(String uid, File file) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _userService.uploadProfilePicture(uid, file);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to upload picture.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Get Users by IDs (for match players) ────────────────────────────────
  Future<List<UserModel>> getUsersByIds(List<String> uids) async {
    return await _userService.getUsersByIds(uids);
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }
}
