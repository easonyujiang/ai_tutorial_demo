import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/demo_tutorials.dart';
import '../models/tutorial.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class TutorialService {
  final String baseUrl;
  final Duration timeout;

  const TutorialService({required this.baseUrl, this.timeout = const Duration(seconds: 30)});

  Future<Map<String, dynamic>> _post(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = body != null
          ? await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
              .timeout(timeout)
          : await http.post(uri, headers: {'Content-Type': 'application/json'}).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(response.statusCode, _extractMessage(response.body));
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on TimeoutException {
      throw ApiException(408, '请求超时，请检查网络连接');
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await http.get(uri, headers: {'Content-Type': 'application/json'}).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(response.statusCode, _extractMessage(response.body));
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on TimeoutException {
      throw ApiException(408, '请求超时，请检查网络连接');
    }
  }

  Future<List<dynamic>> _getList(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await http.get(uri, headers: {'Content-Type': 'application/json'}).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(response.statusCode, _extractMessage(response.body));
      }
      final decoded = jsonDecode(response.body);
      if (decoded is List) return decoded;
      throw ApiException(500, '接口返回格式错误：期望数组');
    } on TimeoutException {
      throw ApiException(408, '请求超时，请检查网络连接');
    }
  }

  String _extractMessage(String body) {
    try {
      final data = jsonDecode(body);
      return data['detail'] ?? data['message'] ?? body;
    } catch (_) {
      return body;
    }
  }

  Future<String> createSession(String videoUrl) async {
    final data = await _post('/api/v1/tutorial/create', body: {'url': videoUrl});
    return data['session_id'] as String;
  }

  Future<SessionStatusData> getStatus(String sessionId) async {
    final data = await _get('/api/v1/tutorial/$sessionId/status');
    return SessionStatusData.fromJson(data);
  }

  Future<bool> waitForReady(String sessionId, {int intervalMs = 1000, int maxRetries = 120}) async {
    for (int i = 0; i < maxRetries; i++) {
      final status = await getStatus(sessionId);
      if (status.status == 'ready') return true;
      if (status.status == 'error') {
        throw ApiException(500, status.errorMessage.isNotEmpty ? status.errorMessage : '分析失败');
      }
      await Future.delayed(Duration(milliseconds: intervalMs));
    }
    throw ApiException(408, '教程分析超时，请稍后重试');
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
    try {
      final response = await http.delete(uri).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(response.statusCode, _extractMessage(response.body));
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on TimeoutException {
      throw ApiException(408, '请求超时，请检查网络连接');
    }
  }

  Future<List<Map<String, dynamic>>> fetchSkills() async {
    final raw = await _getList('/api/skills');
    return raw.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> createSkill(Map<String, dynamic> body) async {
    return await _post('/api/skills', body: body);
  }

  Future<Map<String, dynamic>> analyzeUrlForSkill(String videoUrl) async {
    return await _post('/api/skills/analyze', body: {'url': videoUrl});
  }

  Future<List<Map<String, dynamic>>> fetchDemos() async {
    final raw = await _getList('/api/videos/demos');
    return raw.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> fetchDemo(String demoId) async {
    return await _get('/api/videos/demos/$demoId');
  }
}


class MockTutorialService extends TutorialService {
  final Tutorial _demoTutorial = DemoTutorials.wifiTutorial;

  MockTutorialService() : super(baseUrl: 'http://localhost:8000');

  @override
  Future<String> createSession(String videoUrl) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return 'mock_session_001';
  }

  @override
  Future<bool> waitForReady(String sessionId, {int intervalMs = 2000, int maxRetries = 150}) async {
    await Future.delayed(const Duration(seconds: 2));
    return true;
  }

  @override
  Future<SessionStatusData> getStatus(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return SessionStatusData(
      sessionId: sessionId,
      status: 'ready',
      title: _demoTutorial.title,
      totalSteps: _demoTutorial.steps.length,
      currentStep: 0,
      steps: _demoTutorial.steps,
    );
  }

  @override
  Future<ExecuteData> executeStep(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final steps = _demoTutorial.steps;
    return ExecuteData(
      completed: false,
      stepIndex: 0,
      totalSteps: steps.length,
      instruction: steps[0].instruction,
      targetText: steps[0].targetText,
      pageDescription: steps[0].pageDescription,
    );
  }

  @override
  Future<StepActionData> confirmStep(String sessionId, int stepIndex) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return StepActionData(ok: true, nextStep: stepIndex + 1);
  }

  @override
  Future<StepActionData> skipStep(String sessionId, int stepIndex, {String reason = ''}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return StepActionData(ok: true, nextStep: stepIndex + 1);
  }
}
