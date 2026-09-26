// Generates the bundled alarm sound (`assets/audio/alarm.wav`).
//
// A two-tone urgent beep pattern that loops seamlessly when played on repeat:
//   880 Hz / 660 Hz alternating, with a short envelope on each beep to avoid
//   clicks, plus a brief silence tail so the loop reads as "beep beep … beep beep".
//
// Run: dart run tool/generate_alarm_wav.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int sampleRate = 44100;

void main() {
  final samples = _buildSamples();
  final bytes = _toWav(samples);
  final file = File('assets/audio/alarm.wav');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
  stdout.writeln(
    'Wrote ${file.path} (${bytes.length} bytes, '
    '${samples.length ~/ sampleRate}s)',
  );
}

List<double> _buildSamples() {
  // (frequency, startSeconds, durationSeconds)
  const beeps = [
    (880.0, 0.00, 0.35),
    (660.0, 0.45, 0.35),
    (880.0, 0.90, 0.35),
    (660.0, 1.35, 0.35),
  ];
  const totalSeconds = 2.0;
  const amplitude = 0.72;
  const attackSeconds = 0.02;

  final samples = List<double>.filled((totalSeconds * sampleRate).round(), 0.0);
  for (final (freq, start, dur) in beeps) {
    final startIndex = (start * sampleRate).round();
    final durSamples = (dur * sampleRate).round();
    final attackSamples = (attackSeconds * sampleRate).round();
    for (var i = 0; i < durSamples; i++) {
      final t = i / sampleRate;
      var envelope = 1.0;
      if (i < attackSamples) {
        envelope = i / attackSamples;
      } else if (i > durSamples - attackSamples) {
        envelope = (durSamples - i) / attackSamples;
      }
      final sample = math.sin(2 * math.pi * freq * t);
      samples[startIndex + i] += sample * amplitude * envelope;
    }
  }
  return samples;
}

Uint8List _toWav(List<double> samples) {
  const channels = 1;
  const bitsPerSample = 16;
  final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
  final blockAlign = channels * (bitsPerSample ~/ 8);
  final dataSize = samples.length * (bitsPerSample ~/ 8);

  final out = BytesBuilder();
  // RIFF header
  out.add(_ascii('RIFF'));
  out.add(_u32(36 + dataSize));
  out.add(_ascii('WAVE'));
  // fmt chunk
  out.add(_ascii('fmt '));
  out.add(_u32(16));
  out.add(_u16(1)); // PCM
  out.add(_u16(channels));
  out.add(_u32(sampleRate));
  out.add(_u32(byteRate));
  out.add(_u16(blockAlign));
  out.add(_u16(bitsPerSample));
  // data chunk
  out.add(_ascii('data'));
  out.add(_u32(dataSize));
  for (final s in samples) {
    final clamped = s.clamp(-1.0, 1.0);
    out.add(_u16((clamped * 0x7FFF).round() & 0xFFFF));
  }
  return out.toBytes();
}

List<int> _ascii(String s) => s.codeUnits;

List<int> _u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];

List<int> _u32(int v) => [
  v & 0xFF,
  (v >> 8) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 24) & 0xFF,
];
