import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class VoiceService {
  static final AudioRecorder _recorder = AudioRecorder();
  static final AudioPlayer _player = AudioPlayer();
  Stream<Uint8List>? _demoStream;
  Timer? _demoTimer;
  bool _isDemoActive = false;

  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<Stream<Uint8List>> startAudioStream({bool demoMode = false}) async {
    if (demoMode) {
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
      _demoStream = ctrl.stream;
      return _demoStream!;
    }

    final hasPermission = await requestMicrophonePermission();
    if (!hasPermission) {
      throw Exception('Microphone permission denied');
    }

    final ok = await _recorder.hasPermission();
    if (!ok) {
      throw Exception('Recording permission denied');
    }

    return _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
  }

  Future<void> stopAudioStream() async {
    _isDemoActive = false;
    _demoTimer?.cancel();
    _demoTimer = null;
    _demoStream = null;
    try {
      await _recorder.stop();
    } catch (_) {}
  }

  Future<void> playAudioResponse(Uint8List audioData) async {
    final bytes = _looksLikeWav(audioData) ? audioData : _wrapPcm16LeToWav(audioData);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/agent_reply_${DateTime.now().millisecondsSinceEpoch}.wav');
    await file.writeAsBytes(bytes, flush: true);
    await _player.stop();
    await _player.setFilePath(file.path);
    await _player.play();
  }

  Future<void> stopPlayback() async {
    await _player.stop();
  }

  bool _looksLikeWav(Uint8List data) {
    if (data.length < 12) return false;
    final riff = String.fromCharCodes(data.sublist(0, 4));
    final wave = String.fromCharCodes(data.sublist(8, 12));
    return riff == 'RIFF' && wave == 'WAVE';
  }

  Uint8List _wrapPcm16LeToWav(Uint8List pcmData, {int sampleRate = 16000, int channels = 1}) {
    final byteRate = sampleRate * channels * 2;
    final blockAlign = channels * 2;
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;

    final header = BytesBuilder()
      ..add(ascii.encode('RIFF'))
      ..add(_u32(fileSize))
      ..add(ascii.encode('WAVE'))
      ..add(ascii.encode('fmt '))
      ..add(_u32(16))
      ..add(_u16(1))
      ..add(_u16(channels))
      ..add(_u32(sampleRate))
      ..add(_u32(byteRate))
      ..add(_u16(blockAlign))
      ..add(_u16(16))
      ..add(ascii.encode('data'))
      ..add(_u32(dataSize))
      ..add(pcmData);

    return header.toBytes();
  }

  Uint8List _u16(int value) {
    final b = ByteData(2)..setUint16(0, value, Endian.little);
    return b.buffer.asUint8List();
  }

  Uint8List _u32(int value) {
    final b = ByteData(4)..setUint32(0, value, Endian.little);
    return b.buffer.asUint8List();
  }
}
