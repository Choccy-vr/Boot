import 'package:boot_app/services/Projects/Project.dart';
import 'package:boot_app/services/misc/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import '/services/notifications/notifications.dart';

class HackatimeService {
  static String _getErrorMessage(int statusCode, String defaultMessage) {
    if (statusCode == 403 || statusCode == 404) {
      return 'Hackatime is most likely down or unavailable (Error: $defaultMessage Status: $statusCode)';
    }
    return '$defaultMessage (Status: $statusCode)';
  }

  static Future<List<HackatimeProject>> fetchHackatimeProjects({
    required String slackUserId,
    BuildContext? context,
  }) async {
    if (slackUserId.isEmpty) {
      AppLogger.warning('Cannot fetch Hackatime projects: No Slack user ID');
      return [];
    }
    
    try {
      final url = Uri.parse(
        'https://hackatime.hackclub.com/api/v1/users/$slackUserId/stats?features=projects',
      );
      final response = await http.get(url);
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
          'Hackatime project fetch failed for user $slackUserId with status ${response.statusCode}: ${response.body}',
        );
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => GlobalNotificationService.instance.showError(
            'Hackatime Error: ${_getErrorMessage(response.statusCode, 'Failed to load projects')}',
          ),
        );
        return [];
      }
    } catch (e, stack) {
      AppLogger.error(
        'Network error loading Hackatime projects for user $slackUserId',
        e,
        stack,
      );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => GlobalNotificationService.instance.showError(
          'Hackatime Error: Network error loading projects',
        ),
      );
      return [];
    }
  }

  static Future<bool> isHackatimeBanned({
    required String slackUserId,
    BuildContext? context,
  }) async {
    if (slackUserId.isEmpty) return false;
    
    try {
      final url = Uri.parse(
        'https://hackatime.hackclub.com/api/v1/users/$slackUserId/trust_factor',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final decoded = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {};
        final String? trustLevel = decoded['trust_level'];
        if (trustLevel == 'red') return true;
        return false;
      } else {
        AppLogger.warning(
          'Hackatime ban check failed for user $slackUserId with status ${response.statusCode}: ${response.body}',
        );
        return false;
      }
    } catch (e, stack) {
      AppLogger.error(
        'Network error checking Hackatime ban status for user $slackUserId',
        e,
        stack,
      );
      return false;
    }
  }

  static Future<Project> getProjectTime({
    required Project project,
    required String slackUserId,
    BuildContext? context,
  }) async {
    try {
      final projects = await fetchHackatimeProjects(
        slackUserId: slackUserId,
        context: context,
      );
      if (projects.isEmpty) {
        AppLogger.warning('Hackatime projects list empty for user $slackUserId');
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
          'Hackatime project(s) $missingList not found for user $slackUserId',
        );
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => GlobalNotificationService.instance.showError(
            'Hackatime Error: Project(s) $missingList not found on Hackatime',
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
