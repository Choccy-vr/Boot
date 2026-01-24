import 'package:boot_app/services/Projects/Project.dart';
import 'package:boot_app/services/Projects/project_service.dart';
import 'package:boot_app/services/misc/logger.dart';
import 'package:boot_app/services/ships/Boot_Ship.dart';
import 'package:boot_app/services/slack/slack_manager.dart';
import 'package:boot_app/services/supabase/DB/supabase_db.dart';
import 'package:boot_app/services/users/Boot_User.dart';
import 'package:boot_app/services/users/User.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/services/notifications/notifications.dart';

class ShipService {
  static Future<Ship> getShipById(String id) async {
    try {
      final response = await SupabaseDB.getRowData(table: 'ships', rowID: id);
      return await Ship.fromJson(Map<String, dynamic>.from(response as Map));
    } catch (e, stack) {
      AppLogger.error('Error getting ship by ID $id', e, stack);
      throw Exception('Error getting ship by ID $id: $e');
    }
  }

  static Future<List<Ship>> getAllUnreviewedShips() async {
    try {
      final response = await SupabaseDB.getMultipleRowData(
        table: 'ships',
        column: 'reviewed',
        columnValue: [false],
      );
      final rows = List<Map<String, dynamic>>.from(
        (response as List).map((row) => Map<String, dynamic>.from(row)),
      );
      final ships = await Future.wait(
        rows.map<Future<Ship>>((row) => Ship.fromJson(row)),
      );
      return ships;
    } catch (e, stack) {
      AppLogger.error('Error getting all unreviewed ships', e, stack);
      return [];
    }
  }

  static Future<List<Ship>> getShipsByProject(String projectId) async {
    try {
      final response = await SupabaseDB.getMultipleRowData(
        table: 'ships',
        column: 'project',
        columnValue: [projectId],
      );
      final rows = List<Map<String, dynamic>>.from(
        (response as List).map((row) => Map<String, dynamic>.from(row)),
      );
      final ships = await Future.wait(
        rows.map<Future<Ship>>((row) => Ship.fromJson(row)),
      );
      return ships;
    } catch (e, stack) {
      AppLogger.error('Error getting ships by project $projectId', e, stack);
      return [];
    }
  }

  static Future<List<Ship>> getAllShipsFromProjects(
    List<Project> projects,
  ) async {
    if (projects.isEmpty) return [];

    try {
      final projectIds = projects.map((p) => p.id).toList();
      final response = await SupabaseDB.getMultipleRowData(
        table: 'ships',
        column: 'project',
        columnValue: projectIds,
      );
      final rows = List<Map<String, dynamic>>.from(
        (response as List).map((row) => Map<String, dynamic>.from(row)),
      );
      final ships = await Future.wait(
        rows.map<Future<Ship>>((row) => Ship.fromJson(row)),
      );
      return ships;
    } catch (e, stack) {
      AppLogger.error('Error getting ships from projects', e, stack);
      return [];
    }
  }

  static Future<Ship> addShip({
    required Project project,
    required double time,
    required List<int> challengesRequested,
  }) async {
    try {
      final response = await SupabaseDB.insertAndReturnData(
        table: 'ships',
        data: {
          'project': project.id,
          'time': time,
          'challenges_requested': challengesRequested,
          'approved': false,
          'reviewed': false,
        },
      );
      project.timeTrackedShip = 0;
      project.shipped = true;
      await ProjectService.updateProject(project);
      final rows = List<Map<String, dynamic>>.from(
        (response as List).map((row) => Map<String, dynamic>.from(row)),
      );
      final newShip = await Ship.fromJson(rows.first);
      await SlackManager.sendMessage(
        destination: UserService.currentUser?.slackUserId ?? '',
        message:
            "And you are off to the races!\n\nYour Boot project ${project.title} has been shipped. :ultrafastparrot:\n\nAll you have to do now is wait until it gets reviewed.\n\ngl :parrot_love:\n\nMay you not commit fraud.",
      );
      return newShip;
    } catch (e, stack) {
      AppLogger.error('Error adding ship for project $project', e, stack);
      throw Exception('Error adding ship: $e');
    }
  }

  static Future<void> approveShip({
    required String shipId,
    required String reviewerId,
    required String comment,
    required List<int> challengesCompleted,
    required String screenshotUrl,
    double? overrideHours,
    int technicality = 0,
    int functionality = 0,
    int ux = 0,
  }) async {
    try {
      final updateData = {
        'reviewed': true,
        'approved': true,
        'reviewer': reviewerId,
        'comment': comment,
        'challenges_completed': challengesCompleted,
        'screenshot_url': screenshotUrl,
        'technicality': technicality,
        'functionality': functionality,
        'ux': ux,
      };

      // Add override hours if provided
      if (overrideHours != null) {
        updateData['override_hours'] = overrideHours;
      }

      final response = await SupabaseDB.updateAndReturnData(
        table: 'ships',
        column: 'id',
        value: shipId,
        data: updateData,
      );
      final ship = await Ship.fromJson(
        Map<String, dynamic>.from((response as List).first),
      );
      final project = await ProjectService.getProjectById(ship.project);
      if (project != null) {
        project.shipped = false;
        await ProjectService.updateProject(project);
      }
      final BootUser? user = await UserService.getUserById(
        project?.owner ?? '',
      );
      if (overrideHours == 0.0 || overrideHours == null) {
        await SlackManager.sendMessage(
          destination: user?.slackUserId ?? '',
          message:
              "Congratulations! :tada:\n\nYour Boot project ${project?.title} has been approved.\n\nIn case you didn't know, Boot Coins can be used in the shop to get prizes!\n\nKeep working on your OS, you can always ship again once you have changed it a good amount.",
        );
      } else {
        await SlackManager.sendMessage(
          destination: user?.slackUserId ?? '',
          message:
              "Congratulations! :tada:\n\nYour Boot project ${project?.title} has been approved.\n\nHowever, your time has been overridden. The time you earn coins for is now $overrideHours hrs.\n\nIn case you didn't know, Boot Coins can be used in the shop to get prizes!\n\nKeep working on your OS, you can always ship again once you have changed it a good amount.",
        );
      }
    } catch (e, stack) {
      AppLogger.error('Error approving ship $shipId', e, stack);
      throw Exception('Error approving ship: $e');
    }
  }

  static Future<void> denyShip({
    required String shipId,
    required String reviewerId,
    required String comment,
  }) async {
    try {
      final response = await SupabaseDB.updateAndReturnData(
        table: 'ships',
        column: 'id',
        value: shipId,
        data: {
          'reviewed': true,
          'approved': false,
          'reviewer': reviewerId,
          'comment': comment,
        },
      );
      final ship = await Ship.fromJson(
        Map<String, dynamic>.from((response as List).first),
      );
      final project = await ProjectService.getProjectById(ship.project);
      if (project != null) {
        project.shipped = false;
        project.timeTrackedShip = ship.time;
        await ProjectService.updateProject(project);
      }
      final BootUser? user = await UserService.getUserById(
        project?.owner ?? '',
      );
      final BootUser? reviewer = await UserService.getUserById(reviewerId);
      await SlackManager.sendMessage(
        destination: user?.slackUserId ?? '',
        message:
            "Uh oh! :uhoh:\n\nYour Boot project ${project?.title} has been rejected. :surprised:\n\nDon't worry, you just have to change a few things.\n\nLuckily, @<${reviewer?.slackUserId}> left you some notes\n\n*${comment}*\n\nKeep at it. When you are ready, just ship it again.",
      );
    } catch (e, stack) {
      AppLogger.error('Error denying ship $shipId', e, stack);
      throw Exception('Error denying ship: $e');
    }
  }
}
