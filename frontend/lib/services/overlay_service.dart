import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/tutorial.dart';

class OverlayService {
  static const _channel = MethodChannel('com.example.frontend/overlay');

  static Future<bool> canDrawOverlays() async {
    final result = await _channel.invokeMethod<bool>('canDrawOverlays');
    return result ?? false;
  }

  static Future<void> requestOverlayPermission() async {
    await _channel.invokeMethod('requestOverlayPermission');
  }

  static Future<bool> isAccessibilityEnabled() async {
    final result = await _channel.invokeMethod<bool>('isAccessibilityEnabled');
    return result ?? false;
  }

  static Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  static Future<void> startOverlay({
    required Tutorial tutorial,
  }) async {
    final stepsJson = jsonEncode(
      tutorial.steps
          .map(
            (s) => {
              'instruction': s.instruction,
              'rect': {
                'left': s.relativeRect.left,
                'top': s.relativeRect.top,
                'width': s.relativeRect.width,
                'height': s.relativeRect.height,
              },
              'bubble_dir': s.bubbleDirection,
            },
          )
          .toList(),
    );

    await _channel.invokeMethod('startOverlay', {
      'steps': stepsJson,
    });
  }

  static Future<void> stopOverlay() async {
    await _channel.invokeMethod('stopOverlay');
  }
}
