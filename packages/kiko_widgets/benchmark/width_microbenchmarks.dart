// What does one `TermUnicodeMeasurer().widthOf` call cost, per input shape —
// and what does a memo hit cost for the same input? Contextualizes the
// per-call price behind the table/textarea frame numbers, and the hit/miss
// economics a session cache would face (a miss still pays the raw cost plus a
// map write; only a hit is pure savings).
//
// Each `run()` calls `widthOf` (or a memo lookup) [kReps] times and the
// reported score is divided by [kReps] to reach a stable per-call number —
// `benchmark_harness` times a whole `run()`, and a single call is too fast to
// resolve against stopwatch/loop overhead on its own.
//
// Run:  dart run benchmark/width_microbenchmarks.dart

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:termunicode/termunicode.dart';

const int kReps = 5000;

/// One ASCII character — the cheapest possible input.
const _asciiChar = 'a';

/// A single grapheme cluster spanning four codepoints joined by ZWJ (a family
/// emoji) — the expensive end of "one cluster": cluster-splitting has to walk
/// past several codepoints before it can call the cluster done.
const _emojiCluster = '👨‍👩‍👧‍👦';

/// A ~40-character plain-ASCII string.
const _ascii40 = 'the quick brown fox jumps over lazy dog';

/// A ~40-character string mixing ASCII words with CJK and emoji — the shape
/// a real cell/line in the table and textarea benchmarks actually has.
const _mixed40 = 'Ada 田中太郎 ✅ Active 🚀 warp-drive engine';

class WidthOfBenchmark extends BenchmarkBase {
  final String text;
  WidthOfBenchmark(super.name, this.text);

  @override
  void run() {
    var sink = 0;
    for (var i = 0; i < kReps; i++) {
      sink += widthString(text);
    }
    if (sink < 0) throw StateError('unreachable');
  }
}

class MemoHitBenchmark extends BenchmarkBase {
  final String text;
  late Map<String, int> memo;
  MemoHitBenchmark(super.name, this.text);

  @override
  void setup() => memo = {text: widthString(text)}; // pre-warm: only hits are timed

  @override
  void run() {
    var sink = 0;
    for (var i = 0; i < kReps; i++) {
      sink += memo[text] ??= widthString(text);
    }
    if (sink < 0) throw StateError('unreachable');
  }
}

void main() {
  final inputs = <String, String>{
    'ascii 1-char': _asciiChar,
    'emoji cluster (4 codepoints)': _emojiCluster,
    'ascii ~40-char': _ascii40,
    'mixed ~40-char (ascii+cjk+emoji)': _mixed40,
  };

  final rows = <(String, int, double, double)>[];
  for (final MapEntry(key: label, value: text) in inputs.entries) {
    final rawUs = WidthOfBenchmark('widthOf raw — $label', text).measure() / kReps;
    final memoUs = MemoHitBenchmark('memo hit — $label', text).measure() / kReps;
    rows.add((label, text.length, rawUs * 1000, memoUs * 1000)); // µs → ns
  }

  String pad(String s, int w) => s.padRight(w);
  String num(double ns) => '${ns.toStringAsFixed(1).padLeft(8)} ns';

  final buf = StringBuffer()
    ..writeln()
    ..writeln('════════════════════════════════════════════════════════════════════════')
    ..writeln(' widthOf per-call cost — raw vs memo hit')
    ..writeln(' ($kReps calls per measured run() to amplify above stopwatch noise)')
    ..writeln('────────────────────────────────────────────────────────────────────────');
  for (final (label, len, rawNs, memoNs) in rows) {
    buf.writeln(
      ' ${pad('$label (len $len)', 36)} raw ${num(rawNs)}   memo ${num(memoNs)}   '
      '${(rawNs / memoNs).toStringAsFixed(1)}x',
    );
  }
  buf.writeln('════════════════════════════════════════════════════════════════════════');

  // Benchmark output; a plain print is the whole point of this script.
  // ignore: avoid_print
  print(buf);
}
