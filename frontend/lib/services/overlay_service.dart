import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/tutorial.dart';

class OverlayService {
  static const MethodChannel _channel = MethodChannel('com.example.frontend/overlay');

  static Future<bool> canDrawOverlays() async {
    try {
      final result = await _channel.invokeMethod<bool>('canDrawOverlays');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } on MissingPluginException {
      // no-op in pure Flutter demo
    } on PlatformException {
      // no-op
    }
  }

  static Future<bool> isAccessibilityEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on MissingPluginException {
      // no-op
    } on PlatformException {
      // no-op
    }
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

    try {
      await _channel.invokeMethod('startOverlay', {
        'steps': stepsJson,
        'title': tutorial.title,
        'id': tutorial.id,
        'targetPackage': tutorial.launchPackage,
        'targetActivity': tutorial.launchActivity,
      });
    } on MissingPluginException {
      // no-op
    } on PlatformException {
      // no-op
    }
  }

  static Future<void> stopOverlay() async {
    try {
      await _channel.invokeMethod('stopOverlay');
    } on MissingPluginException {
      // no-op
    } on PlatformException {
      // no-op
    }
  }
}
