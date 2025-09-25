import 'package:boot_app/services/Projects/project.dart';
import 'package:boot_app/services/Projects/Project_Service.dart';
import 'package:boot_app/services/ships/boot_ship.dart';
import 'package:boot_app/services/supabase/DB/supabase_db.dart';

class ShipService {
  static Future<Ship> getShipById(String id) async {
    try {
      final response = await SupabaseDB.getRowData(table: 'ships', rowID: id);
      return Ship.fromJson(response);
    } catch (e) {
      // Error getting ship by ID $id: $e
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
    } catch (e) {
      // Error getting ships by project $projectId: $e
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
    } catch (e) {
      // Error getting ships from projects: $e
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
    } catch (e) {
      // Error adding ship: $e
      throw Exception('Error adding ship: $e');
    }
  }
}
