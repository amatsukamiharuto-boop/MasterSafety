import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/user_profile.dart';
import '../services/app_services.dart';
import '../services/eye_embedding_service.dart';

/// Pendaftaran: ambil 3 foto mata, rata-ratakan embedding, simpan ke SQLite.
/// Pada produksi, layar ini HARUS dilindungi (mis. hanya Administrator).
class EnrollScreen extends StatefulWidget {
  final AppServices services;
  const EnrollScreen({super.key, required this.services});

  @override
  State<EnrollScreen> createState() => _EnrollScreenState();
}

class _EnrollScreenState extends State<EnrollScreen> {
  static const _shots = 3;
  static const _statuses = ['Administrator', 'Staff', 'Tamu'];

  final _name = TextEditingController();
  String _status = _statuses[1];
  CameraController? _cam;
  bool _busy = false;
  String _hint = 'Isi nama, lalu tekan Daftarkan';

  AppServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    s.openFrontCamera().then((c) {
      if (!mounted) {
        c?.dispose();
        return;
      }
      setState(() {
        _cam = c;
        if (c == null) _hint = 'Izin kamera diperlukan';
      });
    });
  }

  Future<void> _enroll() async {
    final cam = _cam;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _hint = 'Nama wajib diisi');
      return;
    }
    if (cam == null || _busy) return;

    setState(() => _busy = true);
    final paths = <String>[];
    try {
      for (var i = 1; i <= _shots; i++) {
        setState(() => _hint = 'Foto $i dari $_shots — lihat ke kamera');
        await Future.delayed(const Duration(milliseconds: 900));
        await s.audio.playScan();
        final shot = await cam.takePicture();
        paths.add(shot.path);
      }
      setState(() => _hint = 'Mengekstraksi pola mata...');
      final embedding = await s.eyes.embedAverage(paths);
      final accessId = await s.users.nextAccessId();
      await s.users.insert(UserProfile(
        name: name,
        accessId: accessId,
        accessStatus: _status,
        embedding: embedding,
      ));
      await s.audio.playMatch();
      await s.tts.speak('Pendaftaran berhasil. $name terdaftar di MasterSafety.');
      if (mounted) Navigator.of(context).pop();
    } on EyeScanException catch (e) {
      await s.audio.playDenied();
      if (mounted) setState(() => _hint = '${e.message}. Ulangi pendaftaran.');
    } catch (_) {
      await s.audio.playDenied();
      if (mounted) setState(() => _hint = 'Pendaftaran gagal. Ulangi.');
    } finally {
      for (final p in paths) {
        try {
          await File(p).delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _cam?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _cam;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftarkan Pengguna'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: MS.accent, width: 3),
                ),
                child: ClipOval(
                  child: (c == null || !c.value.isInitialized)
                      ? const Center(child: CircularProgressIndicator())
                      : FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: c.value.previewSize!.height,
                            height: c.value.previewSize!.width,
                            child: CameraPreview(c),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama lengkap',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Status akses',
                border: OutlineInputBorder(),
              ),
              items: _statuses
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: _busy ? null : (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 16),
            Text(_hint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _enroll,
              child: Text(_busy ? 'MEMPROSES...' : 'DAFTARKAN'),
            ),
          ],
        ),
      ),
    );
  }
}
