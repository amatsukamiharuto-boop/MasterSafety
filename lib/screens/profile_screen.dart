import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/user_profile.dart';
import '../services/app_services.dart';

/// Profil MasterSafety: Nama, ID, Status Akses + sapaan Text-to-Speech.
class ProfileScreen extends StatefulWidget {
  final AppServices services;
  final UserProfile user;
  final double similarity;
  const ProfileScreen({
    super.key,
    required this.services,
    required this.user,
    required this.similarity,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // "Sistem MasterSafety diverifikasi. Selamat datang, [Nama]"
      widget.services.tts.speakWelcome(widget.user.name);
    });
  }

  @override
  void dispose() {
    widget.services.tts.stop();
    super.dispose();
  }

  Widget _row(String label, String value, {Color? valueColor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54)),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('MasterSafety'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const CircleAvatar(
                radius: 48,
                backgroundColor: MS.surface,
                child: Icon(Icons.person, size: 56, color: MS.accent),
              ),
              const SizedBox(height: 16),
              const Text('AKSES DIBERIKAN',
                  style: TextStyle(
                      color: MS.ok, letterSpacing: 3, fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: MS.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _row('Nama', u.name),
                    const Divider(color: Colors.white12),
                    _row('ID', u.accessId),
                    const Divider(color: Colors.white12),
                    _row('Status Akses', u.accessStatus, valueColor: MS.ok),
                    const Divider(color: Colors.white12),
                    _row('Similarity',
                        '${(widget.similarity * 100).toStringAsFixed(1)}%'),
                  ],
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => widget.services.tts.speakWelcome(u.name),
                icon: const Icon(Icons.volume_up_outlined),
                label: const Text('Ulangi sapaan'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.lock_outline),
                label: const Text('KUNCI KEMBALI'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
