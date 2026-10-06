import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum LivenessOutcome { passed, noFace, failed }

enum _Step { blink, turnHead }

/// Anti-spoofing AKTIF (challenge-response) memakai stream kamera + ML Kit:
///  - dua tantangan acak urutannya: kedip mata & toleh kepala,
///  - wajah dilacak (trackingId): jika wajah berganti di tengah jalan,
///    proses diulang dari awal,
///  - setelah lolos, wajah harus kembali menatap lurus sebelum foto diambil.
///
/// Efektif melawan foto cetak / foto di layar yang diam. TIDAK menghentikan
/// video replay, deepfake real-time, atau topeng 3D.
class LivenessService {
  final _rand = math.Random.secure();
  late final FaceDetector _detector;

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  void init() {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.25,
      ),
    );
  }

  Future<LivenessOutcome> run(
    CameraController cam, {
    required void Function(String) onPrompt,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final steps = [_Step.blink, _Step.turnHead]..shuffle(_rand);
    final done = Completer<LivenessOutcome>();
    final clock = Stopwatch()..start();

    var processing = false;
    var sawFace = false;
    var stepIdx = 0;
    var inChallenge = false;
    var frontalFrames = 0;
    var seenClosed = false;
    var baseYaw = 0.0;
    int? trackId;

    String promptFor(_Step s) =>
        s == _Step.blink ? 'Kedipkan mata sekali' : 'Tolehkan kepala ke samping';

    LivenessOutcome timeoutOutcome() =>
        sawFace ? LivenessOutcome.failed : LivenessOutcome.noFace;

    Future<void> onFrame(CameraImage frame) async {
      if (processing || done.isCompleted) return;
      processing = true;
      try {
        if (clock.elapsed > timeout) {
          done.complete(timeoutOutcome());
          return;
        }
        final input = _toInputImage(frame, cam);
        if (input == null) return;
        final faces = await _detector.processImage(input);
        if (done.isCompleted || faces.isEmpty) return;

        final f = faces.reduce((a, b) =>
            a.boundingBox.width * a.boundingBox.height >=
                    b.boundingBox.width * b.boundingBox.height
                ? a
                : b);
        sawFace = true;

        // Wajah berganti di tengah proses -> ulang dari awal.
        if (trackId != null && f.trackingId != trackId) {
          trackId = f.trackingId;
          stepIdx = 0;
          inChallenge = false;
          frontalFrames = 0;
          seenClosed = false;
          onPrompt('Lihat lurus ke kamera');
          return;
        }
        trackId ??= f.trackingId;

        final yaw = f.headEulerAngleY ?? 0.0;
        final l = f.leftEyeOpenProbability;
        final r = f.rightEyeOpenProbability;
        final known = l != null && r != null;
        final open = known && l > 0.7 && r > 0.7;
        final closed = known && l < 0.25 && r < 0.25;
        final frontal = yaw.abs() < 12;

        if (!inChallenge) {
          if (frontal && open) {
            frontalFrames++;
            if (stepIdx >= steps.length) {
              if (frontalFrames >= 3) done.complete(LivenessOutcome.passed);
            } else if (frontalFrames >= 2) {
              inChallenge = true;
              seenClosed = false;
              baseYaw = yaw;
              frontalFrames = 0;
              onPrompt(promptFor(steps[stepIdx]));
            }
          } else {
            frontalFrames = 0;
          }
          return;
        }

        var ok = false;
        if (steps[stepIdx] == _Step.blink) {
          if (closed) seenClosed = true;
          if (seenClosed && open) ok = true;
        } else {
          if ((yaw - baseYaw).abs() >= 18) ok = true;
        }
        if (ok) {
          stepIdx++;
          inChallenge = false;
          frontalFrames = 0;
          onPrompt('Lihat lurus ke kamera');
        }
      } catch (_) {
        // frame gagal diproses: lewati
      } finally {
        processing = false;
      }
    }

    // Pengaman bila tidak ada frame yang masuk sama sekali.
    final guard = Timer(timeout + const Duration(seconds: 1), () {
      if (!done.isCompleted) done.complete(timeoutOutcome());
    });

    try {
      await cam.startImageStream(onFrame);
      return await done.future;
    } finally {
      guard.cancel();
      try {
        if (cam.value.isStreamingImages) await cam.stopImageStream();
      } catch (_) {}
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraController cam) {
    final camera = cam.description;
    final sensor = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensor);
    } else if (Platform.isAndroid) {
      var comp = _orientations[cam.value.deviceOrientation];
      if (comp == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        comp = (sensor + comp) % 360;
      } else {
        comp = (sensor - comp + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(comp);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> dispose() => _detector.close();
}
