import 'dart:convert';
import 'dart:typed_data';

/// A minimal but well-formed MP3: an ID3v2.3 tag (UTF-16 text, so Cyrillic
/// works) followed by silent MPEG-1 Layer III frames (128 kbps, 44.1 kHz).
Uint8List buildMp3({
  String? title,
  String? artist,
  String? album,
  String? albumArtist,
  String? track,
  String? year,
  Uint8List? coverPng,
  int frames = 40,
}) {
  final tagFrames = BytesBuilder()
    ..add(_textFrame('TIT2', title))
    ..add(_textFrame('TPE1', artist))
    ..add(_textFrame('TALB', album))
    ..add(_textFrame('TPE2', albumArtist))
    ..add(_textFrame('TRCK', track))
    ..add(_textFrame('TYER', year));
  if (coverPng != null) {
    final body = BytesBuilder()
      ..addByte(0) // ISO-8859-1 for MIME and description
      ..add(latin1.encode('image/png'))
      ..addByte(0)
      ..addByte(3) // front cover
      ..addByte(0) // empty description
      ..add(coverPng);
    tagFrames.add(_frame('APIC', body.toBytes()));
  }
  final frameBytes = tagFrames.toBytes();

  final out = BytesBuilder()
    ..add(latin1.encode('ID3'))
    ..add([3, 0, 0])
    ..add(_syncSafe(frameBytes.length))
    ..add(frameBytes);
  const frameLength = 417; // 144 * 128000 / 44100
  for (var i = 0; i < frames; i++) {
    out.add([0xFF, 0xFB, 0x90, 0x64]);
    out.add(Uint8List(frameLength - 4));
  }
  return out.toBytes();
}

List<int> _textFrame(String id, String? value) {
  if (value == null) return const [];
  final body = BytesBuilder()
    ..addByte(1) // UTF-16 with BOM
    ..add([0xFF, 0xFE]);
  for (final unit in value.codeUnits) {
    body
      ..addByte(unit & 0xFF)
      ..addByte(unit >> 8);
  }
  return _frame(id, body.toBytes());
}

List<int> _frame(String id, List<int> body) {
  final size = ByteData(4)..setUint32(0, body.length);
  return [...latin1.encode(id), ...size.buffer.asUint8List(), 0, 0, ...body];
}

List<int> _syncSafe(int value) => [
  (value >> 21) & 0x7F,
  (value >> 14) & 0x7F,
  (value >> 7) & 0x7F,
  value & 0x7F,
];

/// 1×1 PNG.
final Uint8List tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
