import 'dart:io';

import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/user_repository.dart';
import 'alarm_service.dart';
import 'audio_service.dart';
import 'eye_embedding_service.dart';
import 'liveness_service.dart';
import 'matcher.dart';
import 'tts_service.dart';

/// Kumpulan layanan yang dibagikan ke seluruh layar.
class AppServices {
  static const _thresholdKey = 'match_threshold';

  final audio = AudioService();
  final alarm = AlarmService();
  final tts = TtsService();
  final eyes = EyeEmbeddingService();
  final liveness = LivenessService();
  final users = UserRepository();
  final matcher = MatchService();

  Future<void> init() async {
    await Future.wait([audio.init(), tts.init(), eyes.init()]);
    liveness.init();
    final prefs = await SharedPreferences.getInstance();
    matcher.threshold =
        prefs.getDouble(_thresholdKey) ?? MatchService.defaultThreshold;
  }

  Future<void> saveThreshold(double value) async {
    matcher.threshold = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_thresholdKey, value);
  }

  Future<void> resetThreshold() async {
    matcher.threshold = MatchService.defaultThreshold;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_thresholdKey);
  }

  /// Membuka kamera depan. Mengembalikan null jika izin ditolak.
  /// Format stream NV21 (Android) / BGRA (iOS) dibutuhkan untuk liveness;
  /// takePicture() tetap menghasilkan JPEG.
  Future<CameraController?> openFrontCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return null;
    final cams = await availableCameras();
    if (cams.isEmpty) return null;
    final front = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cams.first,
    );
    final ctrl = CameraController(
      front,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup:
          Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    await ctrl.initialize();
    return ctrl;
  }
}
