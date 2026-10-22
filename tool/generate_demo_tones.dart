// Generates the demo tracks in assets/demo_audio/: short, soft chord
// arpeggios synthesised from scratch, so they carry no third-party rights.
//
// Run from the project root:  dart run tool/generate_demo_tones.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const sampleRate = 16000;
const seconds = 12;
const beat = 0.5;

/// File name → chord frequencies (Hz).
const chords = {
  'tone_1': [261.63, 329.63, 392.00, 523.25], // C major
  'tone_2': [220.00, 261.63, 329.63, 440.00], // A minor
  'tone_3': [174.61, 220.00, 261.63, 349.23], // F major
  'tone_4': [196.00, 246.94, 293.66, 392.00], // G major
};

void main() {
  final dir = Directory('assets/demo_audio')..createSync(recursive: true);
  for (final MapEntry(key: name, value: notes) in chords.entries) {
    final file = File('${dir.path}/$name.wav');
    file.writeAsBytesSync(_wav(_render(notes)));
    stdout.writeln('wrote ${file.path} (${file.lengthSync()} bytes)');
  }
}

Int16List _render(List<double> notes) {
  final total = sampleRate * seconds;
  final samples = Int16List(total);
  for (var i = 0; i < total; i++) {
    final t = i / sampleRate;

    // Arpeggio: one chord note per beat with a plucked envelope.
    final step = (t / beat).floor();
    final sinceBeat = t - step * beat;
    final note = notes[step % notes.length];
    final pluck = exp(-sinceBeat * 5) * min(1, sinceBeat * 200);
    var value =
        0.35 *
        pluck *
        (sin(2 * pi * note * t) + 0.3 * sin(2 * pi * note * 2 * t));

    // Soft pad of the whole chord underneath.
    for (final f in notes.take(3)) {
      value += 0.06 * sin(2 * pi * f * t);
    }

    // Fade in and out to avoid clicks.
    final fade = min(1, min(t / 0.5, (seconds - t) / 0.8));
    samples[i] = (value * fade * 32767 * 0.8).round().clamp(-32768, 32767);
  }
  return samples;
}

Uint8List _wav(Int16List samples) {
  final dataBytes = samples.length * 2;
  final header = ByteData(44)
    ..setUint32(0, 0x52494646) // "RIFF"
    ..setUint32(4, 36 + dataBytes, Endian.little)
    ..setUint32(8, 0x57415645) // "WAVE"
    ..setUint32(12, 0x666d7420) // "fmt "
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, 1, Endian.little) // mono
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(36, 0x64617461) // "data"
    ..setUint32(40, dataBytes, Endian.little);
  return (BytesBuilder()
        ..add(header.buffer.asUint8List())
        ..add(samples.buffer.asUint8List()))
      .toBytes();
}
