import 'package:boot_app/services/Projects/Project.dart';
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
        _showErrorSnackbar(
          context,
          _getErrorMessage(response.statusCode, 'Failed to initialize user'),
        );
      }
    } catch (e) {
      _showErrorSnackbar(context, 'Network error during initialization');
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
        _showErrorSnackbar(
          context,
          _getErrorMessage(response.statusCode, 'Failed to load projects'),
        );
        return [];
      }
    } catch (e) {
      _showErrorSnackbar(context, 'Network error loading projects');
      return [];
    }
  }

  static Future<HackatimeProject> fetchProjectDetails({
    required List<HackatimeProject> projects,
    required String projectName,
  }) async {
    try {
      final project = projects.firstWhere(
        (p) => p.name.toLowerCase() == projectName.toLowerCase(),
        orElse: () => HackatimeProject(
          name: 'Not Found',
          totalSeconds: 0,
          text: '0m',
          hours: 0,
          minutes: 0,
          digital: '0:00',
        ),
      );
      return project;
    } catch (e) {
      return HackatimeProject(
        name: 'Error',
        totalSeconds: 0,
        text: '0m',
        hours: 0,
        minutes: 0,
        digital: '0:00',
      );
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
        if (trustLevel == 'red' && userId != 4258) return true;
        return false;
      } else {
        _showErrorSnackbar(
          context,
          _getErrorMessage(response.statusCode, 'Failed to check ban status'),
        );
        return false;
      }
    } catch (e) {
      _showErrorSnackbar(context, 'Network error checking ban status');
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
        _showErrorSnackbar(context, 'No Hackatime projects found');
      }
      final hackatimeProject = await fetchProjectDetails(
        projects: projects,
        projectName: project.hackatimeProjects,
      );
      if (hackatimeProject.name == 'Not Found') {
        _showErrorSnackbar(
          context,
          'Project "${project.hackatimeProjects}" not found on Hackatime',
        );
      }
      project.time = hackatimeProject.totalSeconds / 3600.0;
      project.readableTime = hackatimeProject.text;
      return project;
    } catch (e) {
      throw Exception('Error fetching project time: $e');
    }
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
