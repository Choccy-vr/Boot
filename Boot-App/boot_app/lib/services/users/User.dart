import 'package:boot_app/services/supabase/Storage/supabase_storage.dart';
import 'package:flutter/material.dart';

import '/services/supabase/DB/supabase_db.dart';
import 'Boot_User.dart';

class UserService {
  static Boot_User? currentUser;

  static Future<Boot_User?> getUserById(String id) async {
    try {
      final response = await SupabaseDB.GetRowData(table: 'users', rowID: id);
      return Boot_User.fromJson(response);
    } catch (e) {
      // User not found or other database error
      print('Error getting user by ID $id: $e');
      return null;
    }
  }

  static Future<void> setCurrentUser(String id) async {
    final user = await getUserById(id);
    if (user == null) {
      throw Exception(
        'User initialization failed: Could not retrieve user after creation',
      );
    }

    currentUser = user;
  }

  static Future<void> updateUser() async {
    SupabaseDB.UpsertData(table: 'users', data: currentUser?.toJson());
  }

  static Future<void> updateCurrentUser() async {
    currentUser = await getUserById(currentUser?.id ?? '');
  }

  static Future<void> initializeUser({
    required String id,
    required String email,
  }) async {
    await SupabaseDB.InsertData(
      table: 'users',
      data: {
        'id': id,
        'username': 'User $id',
        'email': email,
        'bio': "Nothing Yet",
        'boot_coins': 0,
        'profile_picture_url': '',
        'total_projects': 0,
        'total_devlogs': 0,
        'total_votes': 0,
      },
    );

    // Give the database a moment to process the insert
    await Future.delayed(Duration(milliseconds: 100));

    final user = await getUserById(id);
    if (user == null) {
      throw Exception(
        'User initialization failed: Could not retrieve user after creation',
      );
    }

    currentUser = user;
  }

  static Future<String> uploadProfilePic(BuildContext context) async {
    String supabasePrivateUrl =
        await SupabaseStorageService.uploadFileWithPicker(
          bucket: 'Profiles',
          supabasePath: '${UserService.currentUser?.id}/profile_pic',
        );

    String? supabasePublicUrl = await SupabaseStorageService.getPublicUrl(
      bucket: 'Profiles',
      supabasePath: supabasePrivateUrl,
    );

    if (supabasePublicUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get public url for profile picture')),
      );
      return '';
    }

    UserService.currentUser?.profilePicture = supabasePublicUrl;
    await UserService.updateUser();

    return supabasePublicUrl;
  }
}
