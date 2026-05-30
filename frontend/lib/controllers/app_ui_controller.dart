import 'dart:ui';
import 'package:flutter/foundation.dart';

class AppUiController extends ChangeNotifier {
  bool _panelOpen = false;
  Offset _avatarPosition = const Offset(0, 100);
  bool _reopenPanelAfterTutorial = false;

  bool get panelOpen => _panelOpen;
  Offset get avatarPosition => _avatarPosition;
  bool get reopenPanelAfterTutorial => _reopenPanelAfterTutorial;

  void openPanel() {
    _panelOpen = true;
    notifyListeners();
  }

  void closePanel() {
    _panelOpen = false;
    notifyListeners();
  }

  void togglePanel() {
    _panelOpen = !_panelOpen;
    notifyListeners();
  }

  void updateAvatarPosition(Offset position) {
    _avatarPosition = position;
    notifyListeners();
  }

  void setInitialAvatarPosition(double left, double top) {
    _avatarPosition = Offset(left, top);
    notifyListeners();
  }

  void markReopenAfterTutorial(bool reopen) {
    _reopenPanelAfterTutorial = reopen;
  }

  void clearTutorialReopenFlag() {
    _reopenPanelAfterTutorial = false;
  }
}
