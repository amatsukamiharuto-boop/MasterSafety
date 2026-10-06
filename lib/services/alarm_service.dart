import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Alarm sirene (looping) + getar. Dipakai saat Access Denied 3 kali.
class AlarmService {
  final AudioPlayer _player = AudioPlayer();
  Timer? _vibrate;
  bool _ringing = false;

  bool get isRinging => _ringing;

  Future<void> start() async {
    if (_ringing) return;
    _ringing = true;
    try {
      // Jalur volume ALARM di Android (bukan volume media).
      await _player.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
      ));
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource('audio/alarm.wav'));
    } catch (_) {}
    _vibrate = Timer.periodic(const Duration(milliseconds: 700), (_) {
      HapticFeedback.vibrate();
    });
  }

  Future<void> stop() async {
    _ringing = false;
    _vibrate?.cancel();
    _vibrate = null;
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
