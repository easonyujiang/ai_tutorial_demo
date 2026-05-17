import 'dart:ui';
import '../models/tutorial.dart';

class DemoTutorials {
  static Tutorial get adTutorial {
    return Tutorial(
      id: 'ad_removal_guide',
      title: '小米手机去广告优化教程',
      steps: [
        TutorialStep(
          imageAsset: '',
          instruction: '在设置主页找到「账号管理」或「XXX(你的小米账号用户名)」选项，点击进入',
          relativeRect: Rect.fromLTWH(0.0, 0.185, 1.0, 0.08),
          bubbleDirection: 'bottom',
        ),
        TutorialStep(
          imageAsset: '',
          instruction: '找到「关于小米账号」并点击',
          relativeRect: Rect.fromLTWH(0.0, 0.845 , 1.0, 0.07),
          bubbleDirection: 'top',
        ),
        TutorialStep(
          imageAsset: '',
          instruction: '找到「系统广告」并点击',
          relativeRect: Rect.fromLTWH(0.0, 0.265, 1.0, 0.05),
          bubbleDirection: 'bottom',
        ),
        TutorialStep(
          imageAsset: '',
          instruction: '关闭「系统工具广告」',
          relativeRect: Rect.fromLTWH(0.0, 0.205, 1.0, 0.05),
          bubbleDirection: 'bottom',
        ),
      ],
    );
  }
}
