import 'package:audioplayers/audioplayers.dart';

/// Memutar efek suara (SFX) MasterSafety dari assets/audio/.
class AudioService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> init() async {
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setVolume(1.0);
  }

  /// SFX: Match Found / Access Granted
  Future<void> playMatch() => _play('audio/match_found.wav');

  /// SFX: Access Denied
  Future<void> playDenied() => _play('audio/access_denied.wav');

  /// SFX: bunyi singkat saat pemindaian dimulai
  Future<void> playScan() => _play('audio/scan_beep.wav');

  Future<void> _play(String assetPath) async {
    try {
      await _player.stop();
      // AssetSource otomatis menambahkan prefix "assets/"
      await _player.play(AssetSource(assetPath));
    } catch (_) {
      // Audio tidak boleh menggagalkan alur autentikasi.
    }
  }

  Future<void> dispose() => _player.dispose();
}
