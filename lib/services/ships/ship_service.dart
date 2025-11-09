import 'package:boot_app/services/Projects/Project.dart';
import 'package:boot_app/services/Projects/project_service.dart';
import 'package:boot_app/services/misc/logger.dart';
import 'package:boot_app/services/ships/Boot_Ship.dart';
import 'package:boot_app/services/supabase/DB/supabase_db.dart';
import 'package:flutter/material.dart';

class ShipService {
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
    required String
    currentUserId, // Keep for potential future use, though not needed for matchmaking now
  }) async {
    try {
      // 1. Call the Supabase Edge Function to get a match.
      // This replaces all the previous client-side logic.
      final response = await SupabaseDB.supabase.functions.invoke(
        'matchmake-pub',
        body: {'name': 'Functions'},
      );

      // 2. Handle errors or cases where no match was found.
      if (response.data == null || response.data is! List) {
        AppLogger.warning(
          'Matchmaking function returned no data or invalid format.',
        );
        return [];
      }

      final List<dynamic> shipData = response.data;
      if (shipData.length < 2) {
        AppLogger.warning('Matchmaking function returned fewer than 2 ships.');
        return [];
      }

      // 3. Parse the ship data returned from the function.
      final selectedShips = shipData
          .map((data) => Ship.fromJson(data as Map<String, dynamic>))
          .toList();

      // 4. Fetch the corresponding project for each ship.
      final results = <Map<Ship, Project>>[];
      for (final ship in selectedShips) {
        final project = await ProjectService.getProjectById(ship.project);
        if (project != null) {
          results.add({ship: project});
        } else {
          // If a project isn't found, log it but don't stop the process.
          AppLogger.error(
            'Could not find project with ID ${ship.project} for a matched ship.',
          );
        }
      }

      // 5. Return the final list, ensuring we have a valid pair.
      return results.length == 2 ? results : [];
    } catch (e, stack) {
      AppLogger.error(
        'Error calling matchmaking function for user $currentUserId',
        e,
        stack,
      );
      return [];
    }
  }

  static Future<void> recordVote({
    required Ship winner,
    required Ship loser,
    required BuildContext context,
  }) async {
    try {
      await SupabaseDB.supabase.functions.invoke(
        'update_multipliers',
        body: {'winner_id': winner.id, 'loser_id': loser.id},
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error recording vote for winner ${winner.id} and loser ${loser.id}',
        e,
        stack,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording vote: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
