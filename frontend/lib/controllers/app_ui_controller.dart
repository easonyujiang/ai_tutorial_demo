import 'package:flutter/foundation.dart';

enum MainPage { analysis, skillLibrary }

class PermissionStatus {
  bool overlayGranted;
  bool accessibilityEnabled;
  bool checking;

  PermissionStatus({
    this.overlayGranted = false,
    this.accessibilityEnabled = false,
    this.checking = true,
  });
}

class AppUiController extends ChangeNotifier {
  MainPage _currentPage = MainPage.analysis;
  bool _reopenPanelAfterTutorial = false;
  bool _demoMode = true;
  PermissionStatus _permissions = PermissionStatus();

  MainPage get currentPage => _currentPage;
  bool get reopenPanelAfterTutorial => _reopenPanelAfterTutorial;
  bool get isDemoMode => _demoMode;
  PermissionStatus get permissions => _permissions;

  void switchTo(MainPage page) {
    if (_currentPage == page) return;
    _currentPage = page;
    notifyListeners();
  }

  void setDemoMode(bool demo) {
    _demoMode = demo;
    notifyListeners();
  }

  void markReopenAfterTutorial(bool reopen) {
    _reopenPanelAfterTutorial = reopen;
  }

  void clearTutorialReopenFlag() {
    _reopenPanelAfterTutorial = false;
  }

  void updatePermissions({
    bool? overlayGranted,
    bool? accessibilityEnabled,
    bool? checking,
  }) {
    _permissions = PermissionStatus(
      overlayGranted: overlayGranted ?? _permissions.overlayGranted,
      accessibilityEnabled: accessibilityEnabled ?? _permissions.accessibilityEnabled,
      checking: checking ?? _permissions.checking,
    );
    notifyListeners();
  }
}
