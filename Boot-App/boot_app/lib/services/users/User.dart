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
        'total_time_tracked': 0,
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
}
