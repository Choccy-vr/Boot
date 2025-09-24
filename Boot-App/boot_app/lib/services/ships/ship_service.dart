import 'package:boot_app/services/Projects/Project.dart';
import 'package:boot_app/services/Projects/Project_Service.dart';
import 'package:boot_app/services/ships/Boot_Ship.dart';
import 'package:boot_app/services/supabase/DB/supabase_db.dart';

class ShipService {
  static Future<Ship> getShipById(String id) async {
    try {
      final response = await SupabaseDB.GetRowData(table: 'ships', rowID: id);
      return Ship.fromJson(response);
    } catch (e) {
      print('Error getting ship by ID $id: $e');
      throw Exception('Error getting ship by ID $id: $e');
    }
  }

  static Future<List<Ship>> getShipsByProject(String projectId) async {
    try {
      final response = await SupabaseDB.GetMultipleRowData(
        table: 'ships',
        column: 'project',
        columnValue: [projectId],
      );
      return response.map<Ship>((row) => Ship.fromJson(row)).toList();
    } catch (e) {
      print('Error getting ships by project $projectId: $e');
      return [];
    }
  }

  static Future<List<Ship>> getAllShipsFromProjects(
    List<Project> projects,
  ) async {
    if (projects.isEmpty) return [];

    try {
      final projectIds = projects.map((p) => p.id).toList();
      final response = await SupabaseDB.GetMultipleRowData(
        table: 'ships',
        column: 'project',
        columnValue: projectIds,
      );
      return response.map<Ship>((row) => Ship.fromJson(row)).toList();
    } catch (e) {
      print('Error getting ships from projects: $e');
      return [];
    }
  }

  static Future<Ship> addShip({
    required int project,
    required double time,
    bool approved = false,
  }) async {
    try {
      final response = await SupabaseDB.InsertAndReturnData(
        table: 'ships',
        data: {'project': project, 'time': time, 'approved': approved},
      );
      final newShip = Ship.fromJson(response.first);
      if (newShip == null) {
        throw Exception('Error adding ship: Response parsing failed');
      }
      await ProjectService.updateStatus(
        projectId: project,
        newStatus: 'Shipped / Awaiting Review',
      );
      return newShip;
    } catch (e) {
      print('Error adding ship: $e');
      throw Exception('Error adding ship: $e');
    }
  }
}
