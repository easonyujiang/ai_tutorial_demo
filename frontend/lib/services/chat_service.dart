import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ChatService {
  final String baseUrl;

  const ChatService({required this.baseUrl});

  Future<String> sendTextMessage(String text, String? sessionId) async {
    final uri = Uri.parse('$baseUrl/api/v1/chat/text');
    final body = <String, dynamic>{'text': text};
    if (sessionId != null) {
      body['session_id'] = sessionId;
    }
    final response = await http
        .post(uri,
            headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Server error (${response.statusCode}): ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['reply'] ?? data['message'] ?? '').toString();
  }

  Future<WebSocket> connectVoiceStream(String? sessionId) async {
    if (baseUrl.isEmpty) {
      throw StateError('baseUrl is empty; cannot connect WebSocket.');
    }
    final wsUrl = baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    final query = sessionId != null ? '?session_id=$sessionId' : '';
    final uri = Uri.parse('$wsUrl/api/v1/chat/voice-stream$query');
    return WebSocket.connect(uri.toString()).timeout(const Duration(seconds: 15));
  }
}
