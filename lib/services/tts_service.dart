import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-Speech untuk ucapan selamat datang yang dinamis.
class TtsService {
  final FlutterTts _tts = FlutterTts();

  Future<void> init() async {
    try {
      await _tts.setLanguage('id-ID'); // butuh suara Bahasa Indonesia terpasang
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
  }

  Future<void> speakWelcome(String name) =>
      speak('Sistem MasterSafety diverifikasi. Selamat datang, $name');

  Future<void> speak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
