import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

void main() {
  const size = 512;
  final logo = img.Image(width: size, height: size, numChannels: 4);
  img.fill(logo, color: img.ColorRgba8(0, 0, 0, 0));

  final cx = size ~/ 2;
  final cy = size ~/ 2;

  img.fillCircle(
    logo,
    x: cx,
    y: cy,
    radius: (size * 0.48).round(),
    color: img.ColorRgba8(16, 21, 29, 255),
  );
  img.fillCircle(
    logo,
    x: cx,
    y: cy,
    radius: (size * 0.43).round(),
    color: img.ColorRgba8(30, 136, 229, 255),
  );
  img.fillCircle(
    logo,
    x: cx,
    y: cy,
    radius: (size * 0.40).round(),
    color: img.ColorRgba8(16, 21, 29, 255),
  );

  final trackColor = img.ColorRgba8(60, 78, 105, 255);
  final hullColor = img.ColorRgba8(30, 136, 229, 255);
  final turretColor = img.ColorRgba8(66, 165, 245, 255);
  final barrelColor = img.ColorRgba8(21, 101, 192, 255);
  final highlightColor = img.ColorRgba8(220, 240, 255, 255);

  final trackWidth = (size * 0.09).round();
  final trackHeight = (size * 0.52).round();
  final trackOffset = (size * 0.19).round();
  final trackTop = cy - trackHeight ~/ 2;
  _capsule(
    logo,
    cx - trackOffset,
    trackTop,
    trackWidth,
    trackHeight,
    trackColor,
  );
  _capsule(
    logo,
    cx + trackOffset,
    trackTop,
    trackWidth,
    trackHeight,
    trackColor,
  );

  final hullWidth = (size * 0.34).round();
  final hullHeight = (size * 0.46).round();
  _capsule(
    logo,
    cx - hullWidth ~/ 2,
    cy - hullHeight ~/ 2,
    hullWidth,
    hullHeight,
    hullColor,
  );

  final barrelWidth = (size * 0.08).round();
  final barrelLength = (size * 0.34).round();
  _capsule(
    logo,
    cx - barrelWidth ~/ 2,
    cy - hullHeight ~/ 2 - barrelLength + (size * 0.06).round(),
    barrelWidth,
    barrelLength,
    barrelColor,
  );

  img.fillCircle(
    logo,
    x: cx,
    y: cy,
    radius: (size * 0.13).round(),
    color: turretColor,
  );
  img.fillCircle(
    logo,
    x: cx - (size * 0.04).round(),
    y: cy - (size * 0.04).round(),
    radius: (size * 0.035).round(),
    color: highlightColor,
  );

  final assetsDir = Directory('assets${Platform.pathSeparator}images');
  assetsDir.createSync(recursive: true);
  File('${assetsDir.path}${Platform.pathSeparator}logo.png')
      .writeAsBytesSync(img.encodePng(logo));

  final iconDir = Directory(
    'windows${Platform.pathSeparator}runner${Platform.pathSeparator}resources',
  );
  File('${iconDir.path}${Platform.pathSeparator}app_icon.ico')
      .writeAsBytesSync(_encodeIco(logo));

  stdout.writeln('logo.png and app_icon.ico written');
}

void _capsule(
  img.Image image,
  int x,
  int y,
  int width,
  int height,
  img.Color color,
) {
  img.fillRect(image, x1: x, y1: y, x2: x + width - 1, y2: y + height - 1, color: color);
  final radius = width ~/ 2;
  img.fillCircle(image, x: x + radius, y: y + radius, radius: radius, color: color);
  img.fillCircle(
    image,
    x: x + radius,
    y: y + height - 1 - radius,
    radius: radius,
    color: color,
  );
}

Uint8List _encodeIco(img.Image source) {
  const sizes = [16, 32, 48, 64, 128, 256];
  final images = <img.Image>[
    for (final size in sizes)
      img.copyResize(
        source,
        width: size,
        height: size,
        interpolation: img.Interpolation.cubic,
      ),
  ];
  final pngs = <Uint8List>[
    for (final image in images) Uint8List.fromList(img.encodePng(image)),
  ];

  final builder = BytesBuilder();
  void writeLe(int value, int bytes) {
    for (var i = 0; i < bytes; i++) {
      builder.addByte((value >> (8 * i)) & 0xFF);
    }
  }

  writeLe(0, 2);
  writeLe(1, 2);
  writeLe(images.length, 2);

  var offset = 6 + images.length * 16;
  for (var i = 0; i < images.length; i++) {
    final size = images[i].width;
    builder.addByte(size >= 256 ? 0 : size);
    builder.addByte(size >= 256 ? 0 : size);
    builder.addByte(0);
    builder.addByte(0);
    writeLe(1, 2);
    writeLe(32, 2);
    writeLe(pngs[i].length, 4);
    writeLe(offset, 4);
    offset += pngs[i].length;
  }
  for (final png in pngs) {
    builder.add(png);
  }
  return builder.toBytes();
}
