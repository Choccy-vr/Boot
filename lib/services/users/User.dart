import 'package:boot_app/services/misc/logger.dart';
import 'package:boot_app/services/Storage/storage.dart';
import 'package:flutter/material.dart';

import '/services/supabase/DB/supabase_db.dart';
import 'Boot_User.dart';
import '/services/notifications/notifications.dart';

class UserService {
  static BootUser? currentUser;

  static Future<BootUser?> getUserById(String id) async {
    try {
      final response = await SupabaseDB.getRowData(table: 'users', rowID: id);
      return BootUser.fromJson(response);
    } catch (e, stack) {
      AppLogger.error('Error getting user by ID $id', e, stack);
      return null;
    }
  }

  static Future<BootUser?> getUserByEmail(String email) async {
    try {
      final response = await SupabaseDB.supabase
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();
      if (response == null) return null;
      return BootUser.fromJson(response);
    } catch (e, stack) {
      AppLogger.error('Error getting user by email $email', e, stack);
      return null;
    }
  }

  static Future<void> setCurrentUser(String id, {String? email}) async {
    // First try by ID
    var user = await getUserById(id);
    
    // If not found by ID but we have email, try by email
    if (user == null && email != null && email.isNotEmpty) {
      AppLogger.info('User not found by ID, trying by email: $email');
      user = await getUserByEmail(email);
      
      // If found by email, update the ID to match the auth user
      if (user != null && user.id != id) {
        AppLogger.info('Updating user ID from ${user.id} to $id');
        try {
          await SupabaseDB.supabase
              .from('users')
              .update({'id': id})
              .eq('email', email);
          await Future.delayed(Duration(milliseconds: 100));
          user = await getUserById(id);
        } catch (e) {
          AppLogger.error('Failed to update user ID: $e');
        }
      }
    }
    
    if (user == null) {
      throw Exception(
        'User initialization failed: Could not retrieve user',
      );
    }

    currentUser = user;
  }

  static Future<void> updateUser() async {
    SupabaseDB.upsertData(table: 'users', data: currentUser?.toJson());
  }

  static Future<void> updateCurrentUser() async {
    currentUser = await getUserById(currentUser?.id ?? '');
  }

  static Future<void> initializeUser({
    required String id,
    required String email,
    String slackUserId = '',
  }) async {
    // First, check if a user with this email already exists (might have different ID)
    try {
      final existingByEmail = await SupabaseDB.supabase
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();
      
      if (existingByEmail != null) {
        // User exists with this email - update the ID and slack_user_id to match auth user
        await SupabaseDB.supabase
            .from('users')
            .update({'id': id, 'slack_user_id': slackUserId})
            .eq('email', email);
        
        await Future.delayed(Duration(milliseconds: 100));
        final user = await getUserById(id);
        if (user != null) {
          currentUser = user;
          return;
        }
      }
    } catch (e) {
      AppLogger.warning('Error checking existing user by email: $e');
    }

    // No existing user with this email, create new one
    await SupabaseDB.upsertData(
      table: 'users',
      onConflict: 'id',
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
        'slack_user_id': slackUserId,
      },
    );

    // Give the database a moment to process the upsert
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
    String supabasePrivateUrl = await StorageService.uploadFileWithPicker(
      path: 'profiles/${UserService.currentUser?.id}/profile_pic',
    );

    if (supabasePrivateUrl == 'User cancelled') {
      return '';
    }

    String? supabasePublicUrl = await StorageService.getPublicUrl(
      path: supabasePrivateUrl,
    );

    if (supabasePublicUrl == null) {
      AppLogger.warning(
        'Failed to resolve public URL for uploaded profile picture '
        'for user ${UserService.currentUser?.id}',
      );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => GlobalNotificationService.instance.showError(
          'Failed to get public url for profile picture',
        ),
      );
      return '';
    }

    // Bust cache for consumers that use the URL directly
    UserService.currentUser?.profilePicture =
        '$supabasePublicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
    await UserService.updateUser();

    return UserService.currentUser?.profilePicture ?? supabasePublicUrl;
  }
}
