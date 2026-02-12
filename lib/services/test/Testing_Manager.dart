/*
import 'package:boot_app/services/Projects/Project.dart';
import 'package:boot_app/services/misc/logger.dart';
import 'package:boot_app/services/notifications/global_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TestingManager {
  static Future<void> openBootHelper(
    Project project,
    BuildContext context,
  ) async {
    final Uri url = Uri.parse('boothelper://project=${project.id}');

    try {
      if (project.isoUrl.isEmpty || project.qemuCMD.isEmpty) {
        Navigator.pushNamed(context, '/projects/${project.id}/setup');
        return;
      }

      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalNonBrowserApplication,
      );

      if (!launched) {
        GlobalNotificationService.instance.showError(
          'Failed to open Boot Helper. Please try again.',
        );
        return;
      }
    } catch (e) {
      // Handle the error - you can log it, show a snackbar, etc.
      GlobalNotificationService.instance.showError(
        'Error opening Boot Helper: $e',
      );
      AppLogger.error('Error opening Boot Helper', e, null);
      return;
    }
  }
}
*/
