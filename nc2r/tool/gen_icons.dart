// Generates the NC2R app icon PNGs without the Flutter rasterizer.
// Run from the package root:  dart run tool/gen_icons.dart
import 'dart:io';
import 'package:image/image.dart' as img;

final maroon = img.ColorRgb8(0x80, 0x00, 0x00);
final maroonDark = img.ColorRgb8(0x59, 0x00, 0x00);
final gold = img.ColorRgb8(0xFF, 0xD7, 0x00);
final goldDeep = img.ColorRgb8(0xC9, 0xA2, 0x27);

void main() {
  Directory('assets/icon').createSync(recursive: true);
  File('assets/icon/app_icon.png')
      .writeAsBytesSync(img.encodePng(renderIcon(1024, foreground: false)));
  File('assets/icon/app_icon_foreground.png')
      .writeAsBytesSync(img.encodePng(renderIcon(1024, foreground: true)));
  stdout.writeln('Wrote assets/icon/app_icon.png and app_icon_foreground.png');
}

img.Image renderIcon(int size, {required bool foreground}) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  final cx = size / 2;
  final cy = size / 2;

  if (!foreground) {
    img.fill(image, color: maroon);
    // Subtle darker-maroon base band for depth.
    img.fillRect(
      image,
      x1: 0,
      y1: (size * 0.70).round(),
      x2: size,
      y2: size,
      color: maroonDark,
    );
    // Gold ring.
    img.fillCircle(
      image,
      x: cx.round(),
      y: cy.round(),
      radius: (size * 0.40).round(),
      color: gold,
      antialias: true,
    );
    img.fillCircle(
      image,
      x: cx.round(),
      y: cy.round(),
      radius: (size * 0.365).round(),
      color: maroon,
      antialias: true,
    );
  }

  // Mortarboard emblem. Full icon: ~62% of canvas; adaptive foreground stays
  // inside the safe zone (~52%).
  final s = size * (foreground ? 0.52 : 0.60);
  final bw = s * 0.30; // board half-width
  final bh = s * 0.14; // board half-height
  final by = cy - s * 0.10; // board center y

  // Diamond (top of the cap).
  img.fillPolygon(
    image,
    vertices: [
      img.Point(cx, by - bh),
      img.Point(cx + bw, by),
      img.Point(cx, by + bh),
      img.Point(cx - bw, by),
    ],
    color: gold,
  );

  // Cap band.
  img.fillRect(
    image,
    x1: (cx - s * 0.13).round(),
    y1: (by + bh * 0.45).round(),
    x2: (cx + s * 0.13).round(),
    y2: (by + bh * 0.45 + s * 0.13).round(),
    color: goldDeep,
    radius: (s * 0.03).round(),
  );

  // Tassel: bar hanging from the right corner + tip.
  final tx = cx + bw - s * 0.015;
  img.fillRect(
    image,
    x1: (tx - s * 0.014).round(),
    y1: by.round(),
    x2: (tx + s * 0.014).round(),
    y2: (by + s * 0.22).round(),
    color: gold,
  );
  img.fillCircle(
    image,
    x: tx.round(),
    y: (by + s * 0.24).round(),
    radius: (s * 0.045).round(),
    color: gold,
    antialias: true,
  );

  return image;
}
