import 'package:flutter/material.dart';
import '/services/supabase/auth/Auth.dart';
import '/services/supabase/DB/supabase_db.dart';
import '/services/users/User.dart';
import '/services/hackatime/hackatime_service.dart';

class SignupService {
  static SignUpUser signUpUser = SignUpUser(
    email: '',
    password: '',
    username: '',
    bio: '',
    profilePictureUrl: '',
    hackatimeApiKey: '',
    hackatimeUsername: '',
  );

  static Future<void> signUp(SignUpUser user) async {
    try {
      await Authentication.signUp(user.email, user.password);
    } catch (e) {
      throw Exception('Sign up failed: ${e.toString()}');
    }
  }

  static Future<void> createProfile(SignUpUser user) async {
    try {
      await SupabaseDB.updateData(
        table: 'users',
        column: 'id',
        value: UserService.currentUser?.id,
        data: {
          'username': user.username,
          'bio': user.bio,
          'profile_picture_url': user.profilePictureUrl,
        },
      );
      await UserService.setCurrentUser(UserService.currentUser?.id ?? '');
    } catch (e) {
      throw Exception('Profile update failed: ${e.toString()}');
    }
  }

  static Future<void> signUpUserWithHackatime(
    SignUpUser user,
    BuildContext context,
  ) async {
    try {
      SignupService.signUpUser.hackatimeApiKey = user.hackatimeApiKey;
      SignupService.signUpUser.hackatimeUsername = user.hackatimeUsername;
      await HackatimeService.initHackatimeUser(
        apiKey: user.hackatimeApiKey,
        username: user.hackatimeUsername,
        context: context,
      );
    } catch (e) {
      throw Exception('Hackatime setup failed: ${e.toString()}');
    }
  }
}

class SignUpUser {
  String email;
  String password;
  String username;
  String bio;
  String profilePictureUrl;
  String hackatimeApiKey;
  String hackatimeUsername;

  SignUpUser({
    required this.email,
    required this.password,
    required this.username,
    required this.bio,
    required this.profilePictureUrl,
    required this.hackatimeApiKey,
    required this.hackatimeUsername,
  });
}
