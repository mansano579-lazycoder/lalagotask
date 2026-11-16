import 'dart:math' as math;
import 'package:flutter/material.dart';

const dashboardGreen = Color(0xff008547);

class DashboardPlot extends CustomPainter {
  const DashboardPlot(this.values, {this.ring = false});

  final List<int> values;
  final bool ring;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    if (ring) {
      final center = size.center(Offset.zero);
      final radius = (size.shortestSide - 16) / 2;
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..color = const Color(0xffedf0ef);
      canvas.drawCircle(center, radius, paint);
      final total = values.fold(0, (sum, value) => sum + value);
      if (total == 0) return;
      var start = -math.pi / 2;
      const colors = [Color(0xff08a83f), Color(0xffffa425), Color(0xff76b6fa)];
      for (var i = 0; i < values.length; i++) {
        final sweep = 2 * math.pi * values[i] / total;
        paint.color = colors[i];
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start,
          sweep,
          false,
          paint,
        );
        start += sweep;
      }
      return;
    }
    const inset = 9.0;
    final height = size.height - inset * 2;
    for (var i = 0; i <= 4; i++) {
      final y = inset + height * i / 4;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint..color = const Color(0xffeef0ef),
      );
    }
    final peak = values.fold(1, math.max);
    final points = List.generate(
      values.length,
      (i) => Offset(
        size.width * (i + .5) / values.length,
        inset + height * (1 - values[i] / peak),
      ),
    );
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    final area = Path.from(line)
      ..lineTo(points.last.dx, size.height - inset)
      ..lineTo(points.first.dx, size.height - inset)
      ..close();
    canvas.drawPath(
      area,
      paint
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x5508a83f), Color(0x0508a83f)],
        ).createShader(Offset.zero & size),
    );
    paint
      ..shader = null
      ..color = dashboardGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(line, paint);
    paint.style = PaintingStyle.fill;
    for (final point in points) {
      canvas.drawCircle(point, 3.5, paint);
    }
  }

  @override
  bool shouldRepaint(DashboardPlot oldDelegate) =>
      ring != oldDelegate.ring || values != oldDelegate.values;
}

class WorkspaceScooter extends StatelessWidget {
  const WorkspaceScooter({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: Size(136, 108), painter: _ScooterPainter());
}

class _ScooterPainter extends CustomPainter {
  const _ScooterPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 136, size.height / 108);
    final paint = Paint()..isAntiAlias = true;
    const ink = Color(0xff302624);
    const yellow = Color(0xffffd327);
    void line(Offset from, Offset to, Color color, double width) {
      canvas.drawLine(
        from,
        to,
        paint
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawOval(
      const Rect.fromLTWH(5, 92, 128, 11),
      paint..color = const Color(0x302d1b0d),
    );
    for (final x in [27.0, 112.0]) {
      canvas.drawCircle(Offset(x, 84), 16, paint..color = ink);
      canvas.drawCircle(
        Offset(x, 84),
        8,
        paint..color = const Color(0xffc9c0ad),
      );
    }
    final body = Path()
      ..moveTo(12, 77)
      ..quadraticBezierTo(18, 61, 35, 66)
      ..lineTo(48, 43)
      ..quadraticBezierTo(53, 36, 62, 44)
      ..lineTo(58, 68)
      ..quadraticBezierTo(57, 77, 68, 77)
      ..lineTo(81, 77)
      ..lineTo(88, 59)
      ..quadraticBezierTo(115, 54, 127, 65)
      ..quadraticBezierTo(137, 74, 127, 81)
      ..lineTo(49, 87)
      ..quadraticBezierTo(40, 87, 35, 75)
      ..close();
    canvas.drawPath(
      body,
      paint
        ..color = const Color(0xffd68600)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawPath(
      body,
      paint
        ..color = yellow
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(84, 51, 42, 10),
        const Radius.circular(5),
      ),
      paint..color = ink,
    );
    line(const Offset(48, 47), const Offset(58, 26), ink, 6);
    line(const Offset(58, 27), const Offset(71, 28), ink, 5);
    line(const Offset(61, 27), const Offset(62, 13), ink, 2);
    canvas.drawOval(const Rect.fromLTWH(58, 8, 10, 12), paint..color = ink);
    canvas.drawCircle(const Offset(49, 34), 10, paint..color = ink);
    canvas.drawCircle(
      const Offset(47, 34),
      7,
      paint..color = const Color(0xfffff8d6),
    );
    line(
      const Offset(29, 68),
      const Offset(40, 65),
      const Color(0xffffef91),
      3,
    );
  }

  @override
  bool shouldRepaint(_ScooterPainter oldDelegate) => false;
}
