import 'dart:io';
import 'dart:math' as math;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class EyeScanException implements Exception {
  final String message;
  EyeScanException(this.message);
  @override
  String toString() => message;
}

/// Pipeline: foto -> ML Kit (lokalisasi mata) -> crop mata kiri/kanan -> embedding.
///
/// Embedding memakai model TFLite jika `assets/models/eye_embedder.tflite`
/// tersedia (input [1,H,W,3], output [1,N]). Jika tidak ada, dipakai
/// deskriptor LBP buatan tangan (HANYA untuk demo/prototipe).
class EyeEmbeddingService {
  late final FaceDetector _detector;
  Interpreter? _interpreter;

  bool get usingNeuralModel => _interpreter != null;

  Future<void> init() async {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableClassification: true, // probabilitas mata terbuka
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    try {
      _interpreter =
          await Interpreter.fromAsset('assets/models/eye_embedder.tflite');
    } catch (_) {
      _interpreter = null; // fallback ke deskriptor LBP
    }
  }

  /// Rata-rata embedding dari beberapa foto (dipakai saat pendaftaran).
  Future<List<double>> embedAverage(List<String> paths) async {
    final all = <List<double>>[];
    for (final p in paths) {
      all.add(await embedFromFile(p));
    }
    final dim = all.first.length;
    final avg = List<double>.filled(dim, 0);
    for (final e in all) {
      for (var i = 0; i < dim; i++) {
        avg[i] += e[i] / all.length;
      }
    }
    return _l2(avg);
  }

  Future<List<double>> embedFromFile(String path) async {
    final faces = await _detector.processImage(InputImage.fromFilePath(path));
    if (faces.isEmpty) throw EyeScanException('Wajah tidak terdeteksi');

    final face = faces.reduce((a, b) =>
        a.boundingBox.width * a.boundingBox.height >=
                b.boundingBox.width * b.boundingBox.height
            ? a
            : b);

    final l = face.leftEyeOpenProbability ?? 1.0;
    final r = face.rightEyeOpenProbability ?? 1.0;
    if (l < 0.4 || r < 0.4) {
      throw EyeScanException('Buka kedua mata lebar-lebar');
    }

    final decoded = img.decodeImage(await File(path).readAsBytes());
    if (decoded == null) throw EyeScanException('Gambar tidak dapat dibaca');
    final image = img.bakeOrientation(decoded);

    final left = _cropEye(image, face.contours[FaceContourType.leftEye]);
    final right = _cropEye(image, face.contours[FaceContourType.rightEye]);

    return _l2([..._embedCrop(left), ..._embedCrop(right)]);
  }

  // ---------------------------------------------------------------- crop

  img.Image _cropEye(img.Image src, FaceContour? contour) {
    if (contour == null || contour.points.isEmpty) {
      throw EyeScanException('Kontur mata tidak ditemukan');
    }
    var minX = 1 << 30, minY = 1 << 30, maxX = -1, maxY = -1;
    for (final p in contour.points) {
      minX = math.min(minX, p.x);
      minY = math.min(minY, p.y);
      maxX = math.max(maxX, p.x);
      maxY = math.max(maxY, p.y);
    }
    final w = maxX - minX, h = maxY - minY;
    final padX = (w * 0.35).round(), padY = (h * 0.8).round();
    final x = (minX - padX).clamp(0, src.width - 2).toInt();
    final y = (minY - padY).clamp(0, src.height - 2).toInt();
    final cw = (w + 2 * padX).clamp(2, src.width - x).toInt();
    final ch = (h + 2 * padY).clamp(2, src.height - y).toInt();
    return img.copyCrop(src, x: x, y: y, width: cw, height: ch);
  }

  // ----------------------------------------------------------- embedding

  List<double> _embedCrop(img.Image crop) =>
      usingNeuralModel ? _embedTflite(crop) : _embedHandcrafted(crop);

  List<double> _embedTflite(img.Image crop) {
    final itp = _interpreter!;
    final shape = itp.getInputTensor(0).shape; // [1, H, W, 3]
    final h = shape[1], w = shape[2];
    final resized = img.copyResize(crop, width: w, height: h);

    final input = [
      List.generate(
        h,
        (y) => List.generate(w, (x) {
          final p = resized.getPixel(x, y);
          return [
            (p.r - 127.5) / 127.5,
            (p.g - 127.5) / 127.5,
            (p.b - 127.5) / 127.5,
          ];
        }),
      ),
    ];
    final outLen = itp.getOutputTensor(0).shape.last;
    final output = [List<double>.filled(outLen, 0.0)];
    itp.run(input, output);
    return _l2(List<double>.from(output[0]));
  }

  /// Deskriptor LBP 4x2 sel x 32 bin (256 dimensi), dipusatkan agar cosine
  /// similarity lebih diskriminatif. Ini BUKAN pengenalan iris sungguhan.
  List<double> _embedHandcrafted(img.Image crop) {
    const w = 64, h = 32, gx = 4, gy = 2, bins = 32;
    final g = img.grayscale(img.copyResize(crop, width: w, height: h));
    double lum(int x, int y) => img.getLuminance(g.getPixel(x, y)).toDouble();

    const offs = [
      [-1, -1], [0, -1], [1, -1], [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0],
    ];
    final hist = List<double>.filled(gx * gy * bins, 0);
    final counts = List<int>.filled(gx * gy, 0);

    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final c = lum(x, y);
        var code = 0;
        for (var k = 0; k < 8; k++) {
          if (lum(x + offs[k][0], y + offs[k][1]) >= c) code |= 1 << k;
        }
        final cell = (y * gy ~/ h) * gx + (x * gx ~/ w);
        hist[cell * bins + (code >> 3)] += 1;
        counts[cell]++;
      }
    }
    for (var cell = 0; cell < gx * gy; cell++) {
      for (var b = 0; b < bins; b++) {
        final i = cell * bins + b;
        hist[i] = hist[i] / math.max(1, counts[cell]) - 1.0 / bins;
      }
    }
    return _l2(hist);
  }

  List<double> _l2(List<double> v) {
    var s = 0.0;
    for (final x in v) {
      s += x * x;
    }
    final n = math.sqrt(s);
    if (n == 0) return v;
    return v.map((x) => x / n).toList();
  }

  Future<void> dispose() async {
    await _detector.close();
    _interpreter?.close();
  }
}
