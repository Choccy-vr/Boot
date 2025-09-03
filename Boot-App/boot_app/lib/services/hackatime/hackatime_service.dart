import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import '/services/users/User.dart';

class HackatimeService {
  static Future<void> initHackatimeUser({
    required String apiKey,
    required String username,
  }) async {
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
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      final userIdValue = decoded['data']?['user_id'];
      UserService.currentUser?.hackatimeID = userIdValue is int
          ? userIdValue
          : int.tryParse(userIdValue.toString()) ?? 0;
      UserService.updateUser();
    } else {
      throw Exception('Something went wrong while initializing Hackatime user');
    }
  }

  static Future<List<HackatimeProject>> fetchHackatimeProjects({
    required int userId,
    required String apiKey,
  }) async {
    final url = Uri.parse(
      'https://hackatime.hackclub.com/api/v1/users/$userId/stats?features=projects',
    );
    final response = await http.get(
      url,
      headers: {HttpHeaders.authorizationHeader: 'Bearer $apiKey'},
    );
    if (response.statusCode == 200) {
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      final List<dynamic> projects = decoded['data']?['projects'] ?? [];
      return projects.map((project) {
        return HackatimeProject.fromJson(project);
      }).toList();
    } else {
      throw Exception('Failed to load Hackatime projects');
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
