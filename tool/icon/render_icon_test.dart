// Renders the AralMap app icon to PNG files used by flutter_launcher_icons
// and flutter_native_splash (see pubspec.yaml).
//
// Run from the project root:  flutter test tool/icon/render_icon_test.dart
// Then:                       dart run flutter_launcher_icons
//                             dart run flutter_native_splash:create
//
// Motif: the Aral Sea — turquoise water, sand dunes, a sun and a white
// sailing boat.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;

const _seaTop = Color(0xFF39B3A3);
const _seaBottom = Color(0xFF1E5F58);
const _sand = Color(0xFFE7A857);
const _sandDark = Color(0xFFC98B3C);
const _sun = Color(0xFFFBE3A6);

/// Draws into a [_size]² square. Android adaptive icons are two layers that
/// the launcher masks and moves separately: the background (sea, waves,
/// dunes — full bleed) and the foreground (sun and boat — on transparent,
/// shrunk by [scale] into the central safe zone).
void _paintMotif(
  Canvas canvas, {
  bool background = true,
  bool foreground = true,
  double scale = 1,
}) {
  final s = _size;
  if (background) _paintBackground(canvas);
  if (foreground) {
    canvas.save();
    canvas.translate(s / 2, s / 2);
    canvas.scale(scale);
    canvas.translate(-s / 2, -s / 2);
    _paintForeground(canvas);
    canvas.restore();
  }
}

void _paintForeground(Canvas canvas) {
  final s = _size;
  // Sun
  canvas.drawCircle(
    Offset(s * 0.72, s * 0.28),
    s * 0.11,
    Paint()..color = _sun,
  );

  // Boat: hull + two sails
  final white = Paint()..color = const Color(0xFFFFFFFF);
  final hull = Path()
    ..moveTo(s * 0.30, s * 0.53)
    ..lineTo(s * 0.70, s * 0.53)
    ..lineTo(s * 0.62, s * 0.60)
    ..lineTo(s * 0.38, s * 0.60)
    ..close();
  canvas.drawPath(hull, white);
  canvas.drawRect(
    Rect.fromLTWH(s * 0.495, s * 0.25, s * 0.012, s * 0.28),
    white,
  );
  canvas.drawPath(
    Path()
      ..moveTo(s * 0.49, s * 0.27)
      ..lineTo(s * 0.49, s * 0.50)
      ..lineTo(s * 0.33, s * 0.50)
      ..close(),
    white,
  );
  canvas.drawPath(
    Path()
      ..moveTo(s * 0.515, s * 0.32)
      ..lineTo(s * 0.515, s * 0.50)
      ..lineTo(s * 0.64, s * 0.50)
      ..close(),
    Paint()..color = const Color(0xE6FFFFFF),
  );
}

void _paintBackground(Canvas canvas) {
  final s = _size;
  canvas.drawRect(
    Rect.fromLTWH(0, 0, s, s),
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, s), [
        _seaTop,
        _seaBottom,
      ]),
  );

  // Waves
  final wave = Paint()
    ..color = const Color(0x55FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * 0.02
    ..strokeCap = StrokeCap.round;
  for (final y in [0.60, 0.67]) {
    final path = Path()..moveTo(s * 0.18, s * y);
    for (var i = 0; i < 4; i++) {
      final x = s * (0.18 + i * 0.16);
      path.quadraticBezierTo(
        x + s * 0.04,
        s * (y - 0.025),
        x + s * 0.08,
        s * y,
      );
      path.quadraticBezierTo(
        x + s * 0.12,
        s * (y + 0.025),
        x + s * 0.16,
        s * y,
      );
    }
    canvas.drawPath(path, wave);
  }

  // Dunes (the dried sea bed)
  canvas.drawPath(
    Path()
      ..moveTo(0, s * 0.80)
      ..quadraticBezierTo(s * 0.30, s * 0.70, s * 0.62, s * 0.80)
      ..quadraticBezierTo(s * 0.85, s * 0.87, s, s * 0.80)
      ..lineTo(s, s)
      ..lineTo(0, s)
      ..close(),
    Paint()..color = _sandDark,
  );
  canvas.drawPath(
    Path()
      ..moveTo(0, s * 0.88)
      ..quadraticBezierTo(s * 0.40, s * 0.78, s, s * 0.90)
      ..lineTo(s, s)
      ..lineTo(0, s)
      ..close(),
    Paint()..color = _sand,
  );
}

Future<void> _write(String path, void Function(Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(1024, 1024);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('render app icon PNGs', (tester) async {
    await tester.runAsync(() async {
      // Full icon (legacy launchers, iOS, Play Store listing).
      await _write('assets/icon/icon.png', (c) => _paintMotif(c));
      // Android adaptive icon layers.
      await _write(
        'assets/icon/icon_background.png',
        (c) => _paintMotif(c, foreground: false),
      );
      await _write(
        'assets/icon/icon_foreground.png',
        (c) => _paintMotif(c, background: false, scale: 0.8),
      );
      // Splash: the motif on a circle, shown on the brand colour.
      await _write('assets/icon/splash.png', (c) {
        c.clipPath(Path()..addOval(const Rect.fromLTWH(0, 0, _size, _size)));
        _paintMotif(c);
      });
    });
    expect(File('assets/icon/icon.png').existsSync(), isTrue);
  });
}
