import 'package:flutter/foundation.dart';

import 'package:boot_app/pages/Projects/My_Projects_Page.dart' deferred as projects_page;
import 'package:boot_app/pages/Projects/Project_Page.dart' deferred as project_page;
import 'package:boot_app/pages/Explore/Explore_Page.dart' deferred as explore_page;
import 'package:boot_app/pages/Challenges/Challenge_page.dart' deferred as challenge_page;
import 'package:boot_app/pages/Leaderboard/Leaderboard_Page.dart' deferred as leaderboard_page;
import 'package:boot_app/pages/Shop/Shop_Page.dart' deferred as shop_page;
import 'package:boot_app/pages/Shop/Prize_Details_Page.dart' deferred as prize_details_page;
import 'package:boot_app/pages/Profile/Profile_Page.dart' deferred as profile_page;

class DeferredPageLoader {
  static Future<void> prefetchDashboardAdjacents() async {
    if (!kIsWeb) {
      return;
    }

    await Future.wait([
      projects_page.loadLibrary(),
      project_page.loadLibrary(),
      explore_page.loadLibrary(),
      challenge_page.loadLibrary(),
      leaderboard_page.loadLibrary(),
      shop_page.loadLibrary(),
      prize_details_page.loadLibrary(),
      profile_page.loadLibrary(),
    ]);
  }
}
