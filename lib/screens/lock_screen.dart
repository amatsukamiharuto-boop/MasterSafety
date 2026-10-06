import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/app_services.dart';
import '../services/eye_embedding_service.dart';
import '../services/liveness_service.dart';
import '../services/matcher.dart';
import '../widgets/ms_logo.dart';
import '../widgets/result_overlay.dart';
import 'calibration_screen.dart';
import 'enroll_screen.dart';
import 'profile_screen.dart';

class LockScreen extends StatefulWidget {
  final AppServices services;
  const LockScreen({super.key, required this.services});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  static const _alarmAfterFails = 3; // Access Denied berturut-turut
  static const _alarmSeconds = 60; // lama alarm (diperpanjang jika ditolak lagi)
  static const _idleHint = 'Posisikan mata di dalam bingkai';

  CameraController? _cam;
  late final AnimationController _pulse;
  bool _busy = false;
  String _hint = _idleHint;
  MatchResult? _result;
  String? _reason;
  int _fails = 0;
  bool _alarmOn = false;
  int _alarmLeft = 0;
  Timer? _alarmTimer;

  AppServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _startCamera();
  }

  Future<void> _startCamera() async {
    try {
      final c = await s.openFrontCamera();
      if (!mounted) {
        await c?.dispose();
        return;
      }
      setState(() {
        _cam = c;
        if (c == null) _hint = 'Izin kamera diperlukan untuk memindai mata';
      });
    } catch (e) {
      if (mounted) setState(() => _hint = 'Kamera tidak dapat dibuka');
    }
  }

  // ------------------------------------------------------------------ scan

  Future<void> _scan() async {
    final cam = _cam;
    if (_busy || cam == null || !cam.value.isInitialized) return;

    setState(() {
      _busy = true;
      _hint = 'Verifikasi keaslian...';
    });

    XFile? shot;
    try {
      await s.audio.playScan();

      // 1) Anti-spoofing aktif: kedip + toleh kepala (urutan acak)
      final live = await s.liveness.run(
        cam,
        onPrompt: (t) {
          if (mounted) setState(() => _hint = t);
        },
      );
      if (live == LivenessOutcome.noFace) {
        if (mounted) setState(() => _hint = 'Wajah tidak terdeteksi. Coba lagi.');
        return;
      }
      if (live == LivenessOutcome.failed) {
        await s.users.logAttempt(null, false, 0);
        await _deny(0, reason: 'Verifikasi keaslian gagal');
        return;
      }

      // 2) Ambil foto, ekstraksi embedding, cocokkan
      if (mounted) setState(() => _hint = 'Memindai pola mata...');
      shot = await cam.takePicture();
      final embedding = await s.eyes.embedFromFile(shot.path);
      final users = await s.users.all();
      final res = s.matcher.match(embedding, users);
      await s.users.logAttempt(res.user?.id, res.granted, res.similarity);

      if (res.granted) {
        await _grant(res);
      } else {
        await _deny(res.similarity);
      }
    } on EyeScanException catch (e) {
      // Mata/wajah tidak terbaca: bukan percobaan akses, cukup beri petunjuk.
      if (mounted) setState(() => _hint = '${e.message}. Coba lagi.');
    } catch (_) {
      if (mounted) setState(() => _hint = 'Pemindaian gagal. Coba lagi.');
    } finally {
      // Hapus foto mentah: data biometrik tidak disimpan di perangkat.
      if (shot != null) {
        try {
          await File(shot.path).delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _grant(MatchResult res) async {
    if (!mounted) return;
    setState(() {
      _result = res;
      _reason = null;
    });
    if (_alarmOn) await _stopAlarm(); // pemindaian sah mematikan alarm
    await s.audio.playMatch(); // SFX Match Found / Access Granted
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    _fails = 0;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProfileScreen(
        services: s,
        user: res.user!,
        similarity: res.similarity,
      ),
    ));
    if (mounted) {
      setState(() {
        _result = null;
        _hint = _idleHint;
      });
    }
  }

  Future<void> _deny(double similarity, {String? reason}) async {
    if (!mounted) return;
    setState(() {
      _result = MatchResult(null, similarity);
      _reason = reason;
    });
    await s.audio.playDenied(); // SFX Access Denied
    _fails++;
    await Future.delayed(const Duration(milliseconds: 1700));
    if (!mounted) return;
    setState(() {
      _result = null;
      _reason = null;
      _hint = 'Akses ditolak ($_fails/$_alarmAfterFails). Coba lagi.';
    });
    if (_fails >= _alarmAfterFails) await _startAlarm();
  }

  // ----------------------------------------------------------------- alarm

  Future<void> _startAlarm() async {
    _alarmLeft = _alarmSeconds; // jika sudah menyala, durasi diperpanjang
    if (_alarmOn) {
      if (mounted) setState(() {});
      return;
    }
    if (mounted) setState(() => _alarmOn = true);
    await s.alarm.start();
    _alarmTimer?.cancel();
    _alarmTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _alarmLeft--;
      if (_alarmLeft <= 0) {
        _stopAlarm();
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _stopAlarm() async {
    _alarmTimer?.cancel();
    _alarmTimer = null;
    await s.alarm.stop();
    _fails = 0;
    if (mounted) {
      setState(() {
        _alarmOn = false;
        _hint = _idleHint;
      });
    }
  }

  @override
  void dispose() {
    _alarmTimer?.cancel();
    s.alarm.stop();
    _pulse.dispose();
    _cam?.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------- UI

  Widget _preview() {
    final c = _cam;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final size = c.value.previewSize!;
    return ClipOval(
      child: SizedBox(
        width: 280,
        height: 280,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.height, // previewSize berorientasi landscape
            height: size.width,
            child: CameraPreview(c),
          ),
        ),
      ),
    );
  }

  Widget _alarmBanner() => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: MS.bad,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'ALARM KEAMANAN AKTIF\n'
                'Akses ditolak $_alarmAfterFails kali • $_alarmLeft dtk. '
                'Pemindaian sah mematikan alarm.',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const MasterSafetyLogo(size: 64),
                  const SizedBox(height: 8),
                  const Text(
                    'MasterSafety',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Text(
                    'LAYAR TERKUNCI  •  AUTENTIKASI MATA',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 11, letterSpacing: 2),
                  ),
                  if (!s.eyes.usingNeuralModel)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: const Text(
                        'MODE DEMO • model terlatih belum terpasang',
                        style: TextStyle(color: Colors.amber, fontSize: 11),
                      ),
                    ),
                  if (_alarmOn) _alarmBanner(),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) {
                      final glow = _busy ? 0.25 + 0.5 * _pulse.value : 0.2;
                      final ring = _alarmOn ? MS.bad : MS.accent;
                      return Container(
                        width: 304,
                        height: 304,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: ring, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: ring.withOpacity(glow),
                              blurRadius: 36,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: _preview(),
                  ),
                  const SizedBox(height: 28),
                  Text(_hint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70)),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _busy ? null : _scan,
                    icon: const Icon(Icons.remove_red_eye_outlined),
                    label: Text(_busy ? 'MEMINDAI...' : 'PINDAI MATA'),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => EnrollScreen(services: s),
                                )),
                        child: const Text('Daftarkan pengguna'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => CalibrationScreen(services: s),
                                )),
                        child: const Text('Kalibrasi ambang'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
          // Kilatan merah layar saat alarm menyala
          if (_alarmOn)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => Container(
                    color: MS.bad.withOpacity(0.04 + 0.18 * _pulse.value),
                  ),
                ),
              ),
            ),
          if (_result != null)
            Positioned.fill(
              child: ResultOverlay(
                granted: _result!.granted,
                similarity: _result!.similarity,
                reason: _reason,
              ),
            ),
        ],
      ),
    );
  }
}
