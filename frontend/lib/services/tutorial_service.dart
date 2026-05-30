import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tutorial.dart';

class TutorialService {
  final String baseUrl;

  const TutorialService({required this.baseUrl});

  Future<Map<String, dynamic>> _post(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = body != null
        ? await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        : await http.post(uri, headers: {'Content-Type': 'application/json'});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API error (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.get(uri, headers: {'Content-Type': 'application/json'});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API error (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<String> createSession(String videoUrl) async {
    final data = await _post('/api/v1/tutorial/create', body: {'url': videoUrl});
    return data['session_id'] as String;
  }

  Future<SessionStatusData> getStatus(String sessionId) async {
    final data = await _get('/api/v1/tutorial/$sessionId/status');
    return SessionStatusData.fromJson(data);
  }

  Future<bool> waitForReady(String sessionId, {int intervalMs = 2000}) async {
    while (true) {
      final status = await getStatus(sessionId);
      if (status.status == 'ready') return true;
      if (status.status == 'error') throw Exception(status.errorMessage.isNotEmpty ? status.errorMessage : '分析失败');
      await Future.delayed(Duration(milliseconds: intervalMs));
    }
  }

  Future<ExecuteData> executeStep(String sessionId) async {
    final data = await _post('/api/v1/tutorial/$sessionId/execute');
    return ExecuteData.fromJson(data);
  }

  Future<OcrResultData> uploadScreenshot(String sessionId, int stepIndex, String imageBase64, int screenWidth, int screenHeight) async {
    final data = await _post('/api/v1/tutorial/$sessionId/screenshot', body: {
      'step_index': stepIndex,
      'image_base64': imageBase64,
      'screen_width': screenWidth,
      'screen_height': screenHeight,
    });
    return OcrResultData.fromJson(data);
  }

  Future<StepActionData> confirmStep(String sessionId, int stepIndex) async {
    final data = await _post('/api/v1/tutorial/$sessionId/confirm', body: {'step_index': stepIndex});
    return StepActionData.fromJson(data);
  }

  Future<StepActionData> skipStep(String sessionId, int stepIndex, {String reason = ''}) async {
    final data = await _post('/api/v1/tutorial/$sessionId/skip', body: {'step_index': stepIndex, 'reason': reason});
    return StepActionData.fromJson(data);
  }

  Future<Map<String, dynamic>> cancelSession(String sessionId) async {
    final uri = Uri.parse('$baseUrl/api/v1/tutorial/$sessionId');
    final response = await http.delete(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API error (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}


class MockTutorialService extends TutorialService {
  MockTutorialService() : super(baseUrl: 'http://localhost:8000');

  @override
  Future<String> createSession(String videoUrl) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return 'mock_session_001';
  }

  @override
  Future<bool> waitForReady(String sessionId, {int intervalMs = 2000}) async {
    await Future.delayed(const Duration(seconds: 2));
    return true;
  }

  @override
  Future<SessionStatusData> getStatus(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return SessionStatusData(
      sessionId: sessionId,
      status: 'ready',
      title: '小米手机去广告教程',
      totalSteps: 4,
      currentStep: 0,
      steps: Tutorial.mockSteps,
    );
  }

  @override
  Future<ExecuteData> executeStep(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final steps = Tutorial.mockSteps;
    return ExecuteData(
      completed: false,
      stepIndex: 0,
      totalSteps: steps.length,
      instruction: steps[0].instruction,
      targetText: steps[0].targetText,
      pageDescription: steps[0].pageDescription,
    );
  }
}
