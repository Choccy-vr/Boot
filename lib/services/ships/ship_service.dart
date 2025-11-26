import 'package:boot_app/services/Projects/Project.dart';
import 'package:boot_app/services/Projects/project_service.dart';
import 'package:boot_app/services/misc/logger.dart';
import 'package:boot_app/services/ships/Boot_Ship.dart';
import 'package:boot_app/services/supabase/DB/supabase_db.dart';
import 'package:flutter/material.dart';
import '/services/notifications/notifications.dart';

class ShipService {
  static Future<Ship> getShipById(String id) async {
    try {
      final response = await SupabaseDB.getRowData(table: 'ships', rowID: id);
      return await Ship.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
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
    required int project,
    required double time,
    required List<int> challengesRequested,

  }) async {
    try {
      final response = await SupabaseDB.insertAndReturnData(
        table: 'ships',
        data: {'project': project, 'time': time, 'challenges_requested': challengesRequested},
      );
      final rows = List<Map<String, dynamic>>.from(
        (response as List).map((row) => Map<String, dynamic>.from(row)),
      );
      final newShip = await Ship.fromJson(rows.first);
      return newShip;
    } catch (e, stack) {
      AppLogger.error('Error adding ship for project $project', e, stack);
      throw Exception('Error adding ship: $e');
    }
  }
}
