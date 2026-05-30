import 'dart:async';
import 'dart:typed_data';

class VoiceService {
  StreamController<Uint8List>? _demoCtrl;
  Timer? _demoTimer;
  bool _isDemoActive = false;

  Future<bool> requestMicrophonePermission() async {
    return true;
  }

  Future<Stream<Uint8List>> startAudioStream({bool demoMode = false}) async {
    final ctrl = StreamController<Uint8List>.broadcast();
    _isDemoActive = true;
    _demoTimer?.cancel();
    _demoTimer = Timer.periodic(const Duration(milliseconds: 220), (timer) {
      if (!_isDemoActive) {
        timer.cancel();
        return;
      }
      ctrl.add(Uint8List.fromList(List<int>.filled(320, 0)));
    });
    _demoCtrl = ctrl;
    return ctrl.stream;
  }

  Future<void> stopAudioStream() async {
    _isDemoActive = false;
    _demoTimer?.cancel();
    _demoTimer = null;
    _demoCtrl?.close();
    _demoCtrl = null;
  }

  Future<void> playAudioResponse(Uint8List audioData) async {}

  Future<void> stopPlayback() async {}
}
