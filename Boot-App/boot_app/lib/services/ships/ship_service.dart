import 'dart:math';

import 'package:boot_app/services/Projects/project.dart';
import 'package:boot_app/services/Projects/Project_Service.dart';
import 'package:boot_app/services/misc/logger.dart';
import 'package:boot_app/services/ships/boot_ship.dart';
import 'package:boot_app/services/supabase/DB/supabase_db.dart';

class ShipService {
  static final _random = Random();

  static Future<Ship> getShipById(String id) async {
    try {
      final response = await SupabaseDB.getRowData(table: 'ships', rowID: id);
      return Ship.fromJson(response);
    } catch (e, stack) {
      AppLogger.error('Error getting ship by ID $id', e, stack);
      throw Exception('Error getting ship by ID $id: $e');
    }
  }

  static Future<List<Ship>> getShipsByProject(String projectId) async {
    try {
      final response = await SupabaseDB.getMultipleRowData(
        table: 'ships',
        column: 'project',
        columnValue: [projectId],
      );
      return response.map<Ship>((row) => Ship.fromJson(row)).toList();
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
      return response.map<Ship>((row) => Ship.fromJson(row)).toList();
    } catch (e, stack) {
      AppLogger.error('Error getting ships from projects', e, stack);
      return [];
    }
  }

  static Future<Ship> addShip({
    required int project,
    required double time,
    bool approved = false,
  }) async {
    try {
      final response = await SupabaseDB.insertAndReturnData(
        table: 'ships',
        data: {'project': project, 'time': time, 'approved': approved},
      );
      final newShip = Ship.fromJson(response.first);
      await ProjectService.updateStatus(
        projectId: project,
        newStatus: 'Shipped / Awaiting Review',
      );
      return newShip;
    } catch (e, stack) {
      AppLogger.error('Error adding ship for project $project', e, stack);
      throw Exception('Error adding ship: $e');
    }
  }

  static Future<List<Map<Ship, Project>>> getShipsForVote({
    required String currentUserId,
    int desiredCount = 2,
  }) async {
    try {
      final response = await SupabaseDB.supabase
          .from('ships')
          .select()
          .eq('approved', true)
          .eq('earned', 0);
      final ships = response.map<Ship>((row) => Ship.fromJson(row)).toList();

      // Remove ships where the current user has already voted
      final eligibleShips = ships
          .where((ship) => !ship.voters.contains(currentUserId))
          .toList();
      if (eligibleShips.isEmpty) {
        return [];
      }

      // Fetch projects for the eligible ships (deduplicate project requests)
      final projectIds = eligibleShips
          .map((ship) => ship.project)
          .toSet()
          .toList();
      final projectResults = await Future.wait(
        projectIds.map((projectId) => ProjectService.getProjectById(projectId)),
      );

      final projectById = <int, Project>{};
      for (var i = 0; i < projectIds.length; i++) {
        final project = projectResults[i];
        if (project != null) {
          projectById[projectIds[i]] = project;
        }
      }

      if (projectById.isEmpty) {
        return [];
      }

      // Group ships by project category (using project level as category proxy)
      final shipsByCategory = <String, List<Ship>>{};
      for (final ship in eligibleShips) {
        final project = projectById[ship.project];
        if (project == null) continue;
        final category =
            (project.level.isNotEmpty ? project.level : 'uncategorized')
                .toLowerCase();
        shipsByCategory.putIfAbsent(category, () => <Ship>[]).add(ship);
      }

      if (shipsByCategory.isEmpty) {
        return [];
      }

      final nonEmptyCategories = shipsByCategory.entries
          .where((entry) => entry.value.isNotEmpty)
          .toList();

      if (nonEmptyCategories.isEmpty) {
        return [];
      }

      final categoryShips = List<Ship>.from(
        nonEmptyCategories[_random.nextInt(nonEmptyCategories.length)].value,
      );

      if (categoryShips.length <= desiredCount) {
        categoryShips.shuffle(_random);
        return categoryShips
            .map((ship) => {ship: projectById[ship.project]!})
            .toList();
      }

      categoryShips.shuffle(_random);
      final anchorShip = categoryShips.first;
      final remaining = categoryShips.skip(1).toList()
        ..sort(
          (a, b) => (a.time - anchorShip.time).abs().compareTo(
            (b.time - anchorShip.time).abs(),
          ),
        );

      final selectedShips = <Ship>[anchorShip];
      for (final ship in remaining) {
        if (selectedShips.length >= desiredCount) break;
        selectedShips.add(ship);
      }
      return selectedShips
          .map((ship) => {ship: projectById[ship.project]!})
          .toList();
    } catch (e, stack) {
      AppLogger.error(
        'Error getting ships for vote for user $currentUserId',
        e,
        stack,
      );
      return [];
    }
  }
}
