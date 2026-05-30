import 'dart:convert';
import 'dart:ui';
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
    } on PlatformException {
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
    } on PlatformException {
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
    } on PlatformException {
    }
  }

  static Future<void> stopOverlay() async {
    try {
      await _channel.invokeMethod('stopOverlay');
    } on MissingPluginException {
    } on PlatformException {
    }
  }

  static Future<String?> takeScreenshot() async {
    try {
      return await _channel.invokeMethod<String>('takeScreenshot');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<Rect?> findNodeByText(String targetText) async {
    try {
      final result = await _channel.invokeMethod<Map>('findNodeByText', {
        'targetText': targetText,
      });
      if (result == null) return null;
      return Rect.fromLTRB(
        (result['left'] as num).toDouble(),
        (result['top'] as num).toDouble(),
        (result['right'] as num).toDouble(),
        (result['bottom'] as num).toDouble(),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<Rect?> findNodeByDescription(String targetDesc) async {
    try {
      final result = await _channel.invokeMethod<Map>('findNodeByDescription', {
        'targetDesc': targetDesc,
      });
      if (result == null) return null;
      return Rect.fromLTRB(
        (result['left'] as num).toDouble(),
        (result['top'] as num).toDouble(),
        (result['right'] as num).toDouble(),
        (result['bottom'] as num).toDouble(),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<void> updateTargetRect(Rect rect) async {
    try {
      await _channel.invokeMethod('updateTargetRect', {
        'left': rect.left.toInt(),
        'top': rect.top.toInt(),
        'right': rect.right.toInt(),
        'bottom': rect.bottom.toInt(),
      });
    } on MissingPluginException {
    } on PlatformException {
    }
  }

  static Future<void> updateInstruction(String text) async {
    try {
      await _channel.invokeMethod('updateInstruction', {'text': text});
    } on MissingPluginException {
    } on PlatformException {
    }
  }
}
