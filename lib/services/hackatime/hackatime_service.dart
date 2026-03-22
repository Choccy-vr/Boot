import 'package:boot_app/services/Projects/Project.dart';
import 'package:boot_app/services/misc/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import '/services/notifications/notifications.dart';
import '/services/users/User.dart';

class HackatimeService {
  static String _resolveSlackUserId(String slackUserId) {
    if (slackUserId.isNotEmpty) return slackUserId;
    return UserService.currentUser?.slackUserId ?? '';
  }

  static String _resolveHcaUserId(String hcaUserId) {
    if (hcaUserId.isNotEmpty) return hcaUserId;
    return UserService.currentUser?.hcUserId ?? '';
  }

  static String _getErrorMessage(int statusCode, String defaultMessage) {
    if (statusCode == 403 || statusCode == 404) {
      return 'Hackatime is most likely down or unavailable (Error: $defaultMessage Status: $statusCode)';
    }
    return '$defaultMessage (Status: $statusCode)';
  }

  static Future<List<HackatimeProject>> fetchHackatimeProjects({
    required String slackUserId,
    required String hcaUserId,
    BuildContext? context,
  }) async {
    final resolvedSlackUserId = _resolveSlackUserId(slackUserId);
    final resolvedHcaUserId = _resolveHcaUserId(hcaUserId);

    if (resolvedSlackUserId.isEmpty && resolvedHcaUserId.isEmpty) {
      AppLogger.warning(
        'Cannot fetch Hackatime projects: No Slack or HCA user ID available',
      );
      return [];
    }

    try {
      if (resolvedSlackUserId.isNotEmpty) {
        final url = Uri.parse(
          'https://hackatime.hackclub.com/api/v1/users/$resolvedSlackUserId/stats?features=projects',
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
        }

        AppLogger.warning(
          'Hackatime project fetch failed for Slack user $resolvedSlackUserId with status ${response.statusCode}: ${response.body}. Trying with HCA id instead.',
        );
      }

      if (resolvedHcaUserId.isNotEmpty) {
        final hcaURL = Uri.parse(
          'https://hackatime.hackclub.com/api/v1/users/$resolvedHcaUserId/stats?features=projects',
        );
        final hcaResponse = await http.get(hcaURL);
        if (hcaResponse.statusCode == 200) {
          final decoded = hcaResponse.body.isNotEmpty
              ? jsonDecode(hcaResponse.body)
              : {};
          final List<dynamic> projects = decoded['data']?['projects'] ?? [];
          return projects.map((project) {
            return HackatimeProject.fromJson(project);
          }).toList();
        }

        AppLogger.warning(
          'Hackatime project fetch failed with HCA id for user $resolvedHcaUserId with status ${hcaResponse.statusCode}: ${hcaResponse.body}',
        );
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => GlobalNotificationService.instance.showError(
            'Hackatime Error: ${_getErrorMessage(hcaResponse.statusCode, 'Failed to load projects')}',
          ),
        );
      }

      return [];
    } catch (e, stack) {
      AppLogger.error(
        'Network error loading Hackatime projects for user $resolvedSlackUserId',
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
    required String hcaUserId,
    BuildContext? context,
  }) async {
    final resolvedSlackUserId = _resolveSlackUserId(slackUserId);
    final resolvedHcaUserId = _resolveHcaUserId(hcaUserId);

    if (resolvedSlackUserId.isEmpty && resolvedHcaUserId.isEmpty) {
      AppLogger.warning(
        'Hackatime ban check skipped: No Slack or HCA user ID available',
      );
      return true;
    }

    try {
      if (resolvedSlackUserId.isNotEmpty) {
        final url = Uri.parse(
          'https://hackatime.hackclub.com/api/v1/users/$resolvedSlackUserId/trust_factor',
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final decoded = response.body.isNotEmpty
              ? jsonDecode(response.body)
              : {};
          final String? trustLevel = decoded['trust_level'];
          if (trustLevel == 'red') return true;
          return false;
        }

        AppLogger.warning(
          'Hackatime ban check failed for Slack user $resolvedSlackUserId with status ${response.statusCode}: ${response.body}. Trying with HCA id instead.',
        );
      }

      if (resolvedHcaUserId.isNotEmpty) {
        final hcaUrl = Uri.parse(
          'https://hackatime.hackclub.com/api/v1/users/$resolvedHcaUserId/trust_factor',
        );
        final hcaResponse = await http.get(hcaUrl);
        if (hcaResponse.statusCode == 200) {
          final decoded = hcaResponse.body.isNotEmpty
              ? jsonDecode(hcaResponse.body)
              : {};
          final String? trustLevel = decoded['trust_level'];
          if (trustLevel == 'red') return true;
          return false;
        }

        AppLogger.warning(
          'Hackatime ban check also failed with HCA id for user $resolvedHcaUserId with status ${hcaResponse.statusCode}: ${hcaResponse.body}',
        );
      }

      return true;
    } catch (e, stack) {
      AppLogger.error(
        'Network error checking Hackatime ban status for user $resolvedSlackUserId',
        e,
        stack,
      );
      return true;
    }
  }

  static Future<bool> canReachHackatime({
    required String slackUserId,
    required String hcaUserId,
  }) async {
    try {
      final resolvedSlackUserId = _resolveSlackUserId(slackUserId);
      final resolvedHcaUserId = _resolveHcaUserId(hcaUserId);

      if (resolvedSlackUserId.isEmpty && resolvedHcaUserId.isEmpty) {
        AppLogger.warning(
          'Hackatime reachability check skipped: No Slack or HCA user ID available',
        );
        return false;
      }

      if (resolvedSlackUserId.isNotEmpty) {
        final url = Uri.parse(
          'https://hackatime.hackclub.com/api/v1/users/$resolvedSlackUserId/stats?features=projects',
        );
        final response = await http.get(url).timeout(Duration(seconds: 5));
        if (response.statusCode == 200) {
          return true;
        }
      }

      if (resolvedHcaUserId.isNotEmpty) {
        final hcaUrl = Uri.parse(
          'https://hackatime.hackclub.com/api/v1/users/$resolvedHcaUserId/stats?features=projects',
        );
        final hcaResponse = await http
            .get(hcaUrl)
            .timeout(Duration(seconds: 5));
        if (hcaResponse.statusCode == 200) {
          return true;
        }
      }

      return false;
    } catch (e, stack) {
      AppLogger.error(
        'Network error checking Hackatime reachability for user $slackUserId',
        e,
        stack,
      );
      return false;
    }
  }

  static Future<Project> getProjectTime({
    required Project project,
    required String slackUserId,
    required String hcaUserId,
    BuildContext? context,
  }) async {
    try {
      final projects = await fetchHackatimeProjects(
        slackUserId: slackUserId,
        hcaUserId: hcaUserId,
        context: context,
      );
      if (projects.isEmpty) {
        AppLogger.warning(
          'Hackatime projects list empty for user $slackUserId',
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
