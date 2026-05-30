import 'dart:ui';
import '../models/tutorial.dart';

class DemoTutorials {
  static Tutorial get wifiTutorial {
    return Tutorial(
      id: 'wifi_guide',
      title: '如何连接 Wi-Fi',
      steps: [
        const TutorialStep(
          instruction: '请点击 WLAN 进入设置',
          targetText: 'WLAN',
          pageDescription: '手机设置主页面',
          relativeRect: Rect.fromLTWH(0.05, 0.25, 0.9, 0.06),
          bubbleDirection: 'bottom',
        ),
        const TutorialStep(
          instruction: '点击此开关打开 WLAN',
          targetText: 'WLAN 开关',
          pageDescription: 'WLAN 设置页面',
          relativeRect: Rect.fromLTWH(0.85, 0.15, 0.1, 0.04),
          bubbleDirection: 'left',
        ),
        const TutorialStep(
          instruction: '选择一个网络并连接',
          targetText: '可用网络列表',
          pageDescription: 'Wi-Fi 网络列表',
          relativeRect: Rect.fromLTWH(0.05, 0.45, 0.9, 0.08),
          bubbleDirection: 'bottom',
        ),
      ],
    );
  }

  static Tutorial get blueToothTutorial {
    return Tutorial(
      id: 'bt_guide',
      title: '如何连接蓝牙设备',
      steps: [
        const TutorialStep(
          instruction: '点击蓝牙进入设置',
          targetText: '蓝牙',
          pageDescription: '手机设置主页面',
          relativeRect: Rect.fromLTWH(0.05, 0.32, 0.9, 0.06),
          bubbleDirection: 'bottom',
        ),
        const TutorialStep(
          instruction: '打开蓝牙开关',
          targetText: '蓝牙开关',
          pageDescription: '蓝牙设置页面',
          relativeRect: Rect.fromLTWH(0.85, 0.15, 0.1, 0.04),
          bubbleDirection: 'left',
        ),
        const TutorialStep(
          instruction: '点击要配对的设备名称',
          targetText: '可用设备',
          pageDescription: '设备列表',
          relativeRect: Rect.fromLTWH(0.05, 0.45, 0.9, 0.08),
          bubbleDirection: 'bottom',
        ),
        const TutorialStep(
          instruction: '确认配对请求',
          targetText: '配对',
          pageDescription: '配对确认弹窗',
          relativeRect: Rect.fromLTWH(0.35, 0.7, 0.3, 0.06),
          bubbleDirection: 'top',
        ),
      ],
    );
  }
}
