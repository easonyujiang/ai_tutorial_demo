import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/demo_tutorials.dart';
import '../models/tutorial.dart';

abstract class TutorialService {
  Future<Tutorial> loadTutorial(String videoUrl);
  Future<Tutorial> loadDemoTutorial();
}

class MockTutorialService implements TutorialService {
  @override
  Future<Tutorial> loadTutorial(String videoUrl) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    return DemoTutorials.wifiTutorial;
  }

  @override
  Future<Tutorial> loadDemoTutorial() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    return DemoTutorials.wifiTutorial;
  }
}

class HttpTutorialService implements TutorialService {
  final String baseUrl;

  const HttpTutorialService({required this.baseUrl});

  @override
  Future<Tutorial> loadTutorial(String videoUrl) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/analyze'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'url': videoUrl}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load tutorial (status: ${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response: expected a JSON object.');
    }

    return Tutorial.fromJson(decoded);
  }

  @override
  Future<Tutorial> loadDemoTutorial() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/analyze-demo'),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load demo tutorial (status: ${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response: expected a JSON object.');
    }

    return Tutorial.fromJson(decoded);
  }
}
