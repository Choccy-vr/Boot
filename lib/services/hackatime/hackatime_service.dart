import 'package:boot_app/services/Projects/Project.dart';
import 'package:boot_app/services/misc/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '/services/users/User.dart';

class HackatimeService {
  static void _showErrorSnackbar(BuildContext? context, String message) {
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hackatime Error: $message',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  static String _getErrorMessage(int statusCode, String defaultMessage) {
    if (statusCode == 403 || statusCode == 404) {
      return 'Hackatime is most likely down or unavailable (Error: $defaultMessage Status: $statusCode)';
    }
    return '$defaultMessage (Status: $statusCode)';
  }

  static Future<void> initHackatimeUser({
    required String apiKey,
    required String username,
    BuildContext? context,
  }) async {
    try {
      // Check if the user is valid
      final url = Uri.parse(
        'https://hackatime.hackclub.com/api/v1/users/$username/stats',
      );
      final response = await http.get(
        url,
        headers: {HttpHeaders.authorizationHeader: 'Bearer $apiKey'},
      );
      if (response.statusCode == 200) {
        UserService.currentUser?.hackatimeApiKey = apiKey;
        final decoded = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {};
        final userIdValue = decoded['data']?['user_id'];
        UserService.currentUser?.hackatimeID = userIdValue is int
            ? userIdValue
            : int.tryParse(userIdValue.toString()) ?? 0;
        UserService.updateUser();
      } else {
        AppLogger.warning(
          'Hackatime init failed for $username with status ${response.statusCode}: ${response.body}',
        );
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showErrorSnackbar(
            context,
            _getErrorMessage(response.statusCode, 'Failed to initialize user'),
          ),
        );
      }
    } catch (e, stack) {
      AppLogger.error(
        'Network error during Hackatime initialization',
        e,
        stack,
      );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) =>
            _showErrorSnackbar(context, 'Network error during initialization'),
      );
    }
  }

  static Future<List<HackatimeProject>> fetchHackatimeProjects({
    required int userId,
    required String apiKey,
    BuildContext? context,
  }) async {
    try {
      final url = Uri.parse(
        'https://hackatime.hackclub.com/api/v1/users/$userId/stats?features=projects',
      );
      final response = await http.get(
        url,
        headers: {HttpHeaders.authorizationHeader: 'Bearer $apiKey'},
      );
      if (response.statusCode == 200) {
        final decoded = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {};
        final List<dynamic> projects = decoded['data']?['projects'] ?? [];
        return projects.map((project) {
          return HackatimeProject.fromJson(project);
        }).toList();
      } else {
        AppLogger.warning(
          'Hackatime project fetch failed for user $userId with status ${response.statusCode}: ${response.body}',
        );
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showErrorSnackbar(
            context,
            _getErrorMessage(response.statusCode, 'Failed to load projects'),
          ),
        );
        return [];
      }
    } catch (e, stack) {
      AppLogger.error(
        'Network error loading Hackatime projects for user $userId',
        e,
        stack,
      );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showErrorSnackbar(context, 'Network error loading projects'),
      );
      return [];
    }
  }

  static Future<bool> isHackatimeBanned({
    required int userId,
    required String apiKey,
    BuildContext? context,
  }) async {
    try {
      final url = Uri.parse(
        'https://hackatime.hackclub.com/api/v1/users/$userId/trust_factor',
      );
      final response = await http.get(
        url,
        headers: {HttpHeaders.authorizationHeader: 'Bearer $apiKey'},
      );
      if (response.statusCode == 200) {
        final decoded = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {};
        final String? trustLevel = decoded['trust_level'];
        if (trustLevel == 'red') return true;
        return false;
      } else {
        AppLogger.warning(
          'Hackatime ban check failed for user $userId with status ${response.statusCode}: ${response.body}',
        );
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showErrorSnackbar(
            context,
            _getErrorMessage(response.statusCode, 'Failed to check ban status'),
          ),
        );
        return false;
      }
    } catch (e, stack) {
      AppLogger.error(
        'Network error checking Hackatime ban status for user $userId',
        e,
        stack,
      );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showErrorSnackbar(context, 'Network error checking ban status'),
      );
      return false;
    }
  }

  static Future<Project> getProjectTime({
    required Project project,
    required int userId,
    required String apiKey,
    BuildContext? context,
  }) async {
    try {
      final projects = await fetchHackatimeProjects(
        userId: userId,
        apiKey: apiKey,
        context: context,
      );
      if (projects.isEmpty) {
        AppLogger.warning('Hackatime projects list empty for user $userId');
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showErrorSnackbar(context, 'No Hackatime projects found'),
        );
      }
      if (project.hackatimeProjects.isEmpty) {
        project.time = 0;
        project.readableTime = '0m';
        return project;
      }

      int totalSeconds = 0;
      final missingProjects = <String>[];
      for (final projectName in project.hackatimeProjects) {
        final details = _findProjectByName(projects, projectName);
        if (details == null) {
          missingProjects.add(projectName);
          continue;
        }
        totalSeconds += details.totalSeconds;
      }

      if (missingProjects.isNotEmpty) {
        final missingList = missingProjects.join(', ');
        AppLogger.warning(
          'Hackatime project(s) $missingList not found for user $userId',
        );
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showErrorSnackbar(
            context,
            'Project(s) $missingList not found on Hackatime',
          ),
        );
      }

      project.time = totalSeconds / 3600.0;
      project.readableTime = _formatReadableDuration(totalSeconds);
      return project;
    } catch (e, stack) {
      AppLogger.error(
        'Error fetching Hackatime project time for ${project.id} (${project.hackatimeProjects})',
        e,
        stack,
      );
      throw Exception('Error fetching project time: $e');
    }
  }

  static HackatimeProject? _findProjectByName(
    List<HackatimeProject> projects,
    String projectName,
  ) {
    try {
      return projects.firstWhere(
        (p) => p.name.toLowerCase() == projectName.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  static String _formatReadableDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0m';
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    }
    if (hours > 0) {
      return '${hours}h';
    }
    return '${minutes}m';
  }
}

class HackatimeProject {
  final String name;
  final int totalSeconds;
  final String text;
  final int hours;
  final int minutes;
  final String digital;

  HackatimeProject({
    required this.name,
    required this.totalSeconds,
    required this.text,
    required this.hours,
    required this.minutes,
    required this.digital,
  });

  factory HackatimeProject.fromJson(Map<String, dynamic> json) {
    return HackatimeProject(
      name: json['name'].toString(),
      totalSeconds: json['total_seconds'] is int
          ? json['total_seconds']
          : int.tryParse(json['total_seconds'].toString()) ?? 0,
      text: json['text'].toString(),
      hours: json['hours'] is int
          ? json['hours']
          : int.tryParse(json['hours'].toString()) ?? 0,
      minutes: json['minutes'] is int
          ? json['minutes']
          : int.tryParse(json['minutes'].toString()) ?? 0,
      digital: json['digital'].toString(),
    );
  }
}
