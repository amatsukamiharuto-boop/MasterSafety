import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Logo MasterSafety (perisai + mata), digambar penuh lewat kode.
/// Bentuknya sama dengan tool/generate_icon.py. Ubah warna lewat parameter,
/// atau ubah bentuk di _LogoPainter.paint().
class MasterSafetyLogo extends StatelessWidget {
  final double size;
  final Color accent;
  final Color accentDark;

  const MasterSafetyLogo({
    super.key,
    this.size = 56,
    this.accent = MS.accent,
    this.accentDark = const Color(0xFF0E7490),
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _LogoPainter(accent, accentDark),
      );
}

class _LogoPainter extends CustomPainter {
  final Color accent;
  final Color accentDark;
  const _LogoPainter(this.accent, this.accentDark);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height * 0.94;
    final w = h * 0.86;
    final cx = size.width / 2;
    final cy = size.height / 2 + h * 0.02;
    final top = cy - h / 2, bot = cy + h / 2;
    final r = cx + w / 2, l = cx - w / 2;
    final lw = h * 0.035;

    // ---- perisai
    final shield = Path()
      ..moveTo(cx, top)
      ..quadraticBezierTo(cx + 0.32 * w, top + 0.03 * h, r, top + 0.15 * h)
      ..lineTo(r, cy + 0.06 * h)
      ..cubicTo(r, cy + 0.30 * h, cx + 0.25 * w, bot - 0.10 * h, cx, bot)
      ..cubicTo(cx - 0.25 * w, bot - 0.10 * h, l, cy + 0.30 * h, l, cy + 0.06 * h)
      ..lineTo(l, top + 0.15 * h)
      ..quadraticBezierTo(cx - 0.32 * w, top + 0.03 * h, cx, top)
      ..close();

    canvas.drawPath(
      shield,
      Paint()
        ..color = accent.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lw * 2
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.035),
    );
    canvas.drawPath(shield, Paint()..color = const Color(0xFF0A182E));
    canvas.drawPath(
      shield,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = lw
        ..strokeJoin = StrokeJoin.round,
    );

    // ---- mata (lensa)
    final ew = w * 0.36, eh = h * 0.17;
    final ey = cy - h * 0.04;
    final eye = Path()
      ..moveTo(cx - ew, ey)
      ..quadraticBezierTo(cx, ey - 2 * eh, cx + ew, ey)
      ..quadraticBezierTo(cx, ey + 2 * eh, cx - ew, ey)
      ..close();
    canvas.drawPath(eye, Paint()..color = const Color(0xFF061020));

    // ---- iris, pupil, kilau
    final ir = eh * 0.90;
    final c = Offset(cx, ey);
    canvas.drawCircle(c, ir, Paint()..color = accentDark);
    canvas.drawCircle(
      c,
      ir,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = lw * 0.5,
    );
    canvas.drawCircle(c, ir * 0.42, Paint()..color = const Color(0xFF040A14));
    canvas.drawCircle(
      Offset(cx - ir * 0.30, ey - ir * 0.30),
      ir * 0.14,
      Paint()..color = const Color(0xFFF0FAFF),
    );

    // ---- garis pemindai
    final x0 = cx - w * 0.46, x1 = cx + w * 0.46;
    canvas.drawLine(
      Offset(x0, ey),
      Offset(x1, ey),
      Paint()
        ..color = accent
        ..strokeWidth = lw
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.012),
    );
    canvas.drawLine(
      Offset(x0, ey),
      Offset(x1, ey),
      Paint()
        ..color = const Color(0xE6F0FAFF)
        ..strokeWidth = lw / 3,
    );

    // ---- garis tepi mata
    canvas.drawPath(
      eye,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = lw * 0.7
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) =>
      old.accent != accent || old.accentDark != accentDark;
}
