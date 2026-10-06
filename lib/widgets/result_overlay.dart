import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Animasi visual "MATCH FOUND" / "ACCESS DENIED".
class ResultOverlay extends StatelessWidget {
  final bool granted;
  final double similarity;

  /// Teks pengganti baris similarity (mis. alasan verifikasi keaslian gagal).
  final String? reason;

  const ResultOverlay({
    super.key,
    required this.granted,
    required this.similarity,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final color = granted ? MS.ok : MS.bad;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: granted ? Curves.elasticOut : Curves.easeOutBack,
      builder: (context, t, _) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Container(
          color: MS.bg.withOpacity(0.88),
          alignment: Alignment.center,
          child: Transform.scale(
            scale: 0.6 + 0.4 * t,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 4),
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.5), blurRadius: 32),
                    ],
                  ),
                  child: Icon(
                    granted ? Icons.check_rounded : Icons.close_rounded,
                    color: color,
                    size: 72,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  granted ? 'MATCH FOUND' : 'ACCESS DENIED',
                  style: TextStyle(
                    color: color,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  reason ?? 'Similarity ${(similarity * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
