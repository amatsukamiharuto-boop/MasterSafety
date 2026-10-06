import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/user_profile.dart';
import '../services/app_services.dart';
import '../services/eye_embedding_service.dart';
import '../services/matcher.dart';

/// Kalibrasi ambang kecocokan dari data nyata.
/// 1) pilih pengguna terdaftar, 2) kumpulkan skor PEMILIK (genuine) dan
/// skor PENYUSUP (orang lain / foto), 3) terapkan ambang yang memisahkan
/// keduanya. Pada produksi, layar ini harus dibatasi untuk administrator.
class CalibrationScreen extends StatefulWidget {
  final AppServices services;
  const CalibrationScreen({super.key, required this.services});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  CameraController? _cam;
  List<UserProfile> _users = [];
  UserProfile? _selected;
  final _genuine = <double>[];
  final _impostor = <double>[];
  bool _busy = false;
  String _hint = 'Pilih pengguna, lalu kumpulkan skor (min. 5 per jenis)';

  AppServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    s.users.all().then((u) {
      if (mounted) {
        setState(() {
          _users = u;
          _selected = u.isEmpty ? null : u.first;
        });
      }
    });
    s.openFrontCamera().then((c) {
      if (!mounted) {
        c?.dispose();
        return;
      }
      setState(() => _cam = c);
    });
  }

  Future<void> _sample(bool genuine) async {
    final cam = _cam;
    final user = _selected;
    if (cam == null || user == null || _busy) return;
    setState(() {
      _busy = true;
      _hint = 'Mengambil sampel...';
    });
    XFile? shot;
    try {
      await s.audio.playScan();
      shot = await cam.takePicture();
      final e = await s.eyes.embedFromFile(shot.path);
      final score = cosineSimilarity(e, user.embedding);
      setState(() {
        (genuine ? _genuine : _impostor).add(score);
        _hint = 'Skor ${score.toStringAsFixed(3)} dicatat';
      });
    } on EyeScanException catch (e) {
      if (mounted) setState(() => _hint = '${e.message}. Coba lagi.');
    } catch (_) {
      if (mounted) setState(() => _hint = 'Gagal mengambil sampel');
    } finally {
      if (shot != null) {
        try {
          await File(shot.path).delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  double? get _minGenuine =>
      _genuine.isEmpty ? null : _genuine.reduce(math.min);
  double? get _maxImpostor =>
      _impostor.isEmpty ? null : _impostor.reduce(math.max);

  /// Titik tengah antara skor pemilik terendah dan penyusup tertinggi.
  double? get _suggested {
    final g = _minGenuine, i = _maxImpostor;
    if (g == null || i == null || _genuine.length < 5 || _impostor.length < 5) {
      return null;
    }
    return g > i ? (g + i) / 2 : null;
  }

  @override
  void dispose() {
    _cam?.dispose();
    super.dispose();
  }

  Widget _scores(String title, List<double> v, Color c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title (${v.length})',
              style: TextStyle(color: c, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: v
                .map((x) => Chip(
                      label: Text(x.toStringAsFixed(3)),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final sug = _suggested;
    final overlap = _minGenuine != null &&
        _maxImpostor != null &&
        _genuine.length >= 5 &&
        _impostor.length >= 5 &&
        sug == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalibrasi Ambang'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Ambang saat ini: ${s.matcher.threshold.toStringAsFixed(3)}',
                style: const TextStyle(
                    color: MS.accent, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            if (_users.isEmpty)
              const Text('Belum ada pengguna terdaftar. Daftarkan dulu.')
            else
              DropdownButtonFormField<UserProfile>(
                value: _selected,
                decoration: const InputDecoration(
                  labelText: 'Pengguna yang dikalibrasi',
                  border: OutlineInputBorder(),
                ),
                items: _users
                    .map((u) => DropdownMenuItem(
                        value: u, child: Text('${u.name} (${u.accessId})')))
                    .toList(),
                onChanged: _busy ? null : (u) => setState(() => _selected = u),
              ),
            const SizedBox(height: 12),
            Text(_hint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy || _selected == null ? null : () => _sample(true),
                    child: const Text('SCAN PEMILIK'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: MS.bad),
                    onPressed: _busy || _selected == null ? null : () => _sample(false),
                    child: const Text('SCAN PENYUSUP'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Penyusup = orang lain atau foto/layar milik pemilik.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 16),
            _scores('Skor pemilik', _genuine, MS.ok),
            const SizedBox(height: 12),
            _scores('Skor penyusup', _impostor, MS.bad),
            const SizedBox(height: 16),
            if (sug != null) ...[
              Text('Ambang disarankan: ${sug.toStringAsFixed(3)}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () async {
                  await s.saveThreshold(sug);
                  if (mounted) setState(() => _hint = 'Ambang diterapkan');
                },
                child: const Text('TERAPKAN AMBANG'),
              ),
            ],
            if (overlap)
              const Text(
                'Skor pemilik dan penyusup TUMPANG TINDIH. Embedding/model ini '
                'tidak cukup membedakan orang; jangan dipakai untuk keamanan. '
                'Pasang model terlatih (eye_embedder.tflite) lalu ulangi kalibrasi.',
                style: TextStyle(color: Colors.amber),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await s.resetThreshold();
                if (mounted) setState(() => _hint = 'Ambang dikembalikan ke 0.90');
              },
              child: const Text('Kembalikan ke 0.90'),
            ),
            TextButton(
              onPressed: () => setState(() {
                _genuine.clear();
                _impostor.clear();
              }),
              child: const Text('Hapus semua sampel'),
            ),
          ],
        ),
      ),
    );
  }
}
