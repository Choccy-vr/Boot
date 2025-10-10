import 'package:boot_app/services/Projects/project.dart';
import 'package:boot_app/services/supabase/DB/supabase_db.dart';
import 'package:boot_app/services/users/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CloudVmService {
  /// creates a cloud VM by invoking the 'create_vm' Supabase function
  /// NOTE: returns the response data from the function invocation
  /// that contains the IP address to connect to
  /// waits until after it is created
  static Future<dynamic> createVM(Project project) async {
    SupabaseDB.insertData(
      table: 'vms',
      bulkData: [
        {
          'user_id': UserService.currentUser?.id,
          'qemu-cmd': project.qemuCMD,
          'ISO-url': project.isoUrl,
        },
      ],
    );
    final res = await Supabase.instance.client.functions.invoke('create_vm');
    return res.data;
  }
}
