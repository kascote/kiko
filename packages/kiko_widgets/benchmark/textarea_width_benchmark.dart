// Is width measurement hot on the text-area render path — steady state, and
// while typing?
//
// Scenario: a textarea with long wrapped lines — 200 logical lines of ~200
// characters each, mixed ASCII with a sprinkling of CJK/emoji, deterministic
// content — sized 100×40, scrolled to mid-document. Measured through the real
// production path: `Frame.render(TextArea(...))`, exactly what an app calls.
//
// TextAreaComponent owns its own wrap cache (`LineCache`, keyed by a hash of
// each line's content): once a line's wrap geometry is cached, repainting the
// SAME unchanged line does not re-run `_wrap`'s widthOf calls, only the
// per-cluster paint-time measuring in `BufferSurface.rawDrawText` (and, under
// the hood, `Buffer`'s own per-cell-write width bookkeeping — see the sibling
// table benchmark's header for why that dominates). Steady state therefore
// mostly exercises paint-time measuring, not wrap-time measuring. A typing
// frame invalidates one line's cached wrap every op, so wrap-time measuring —
// which measures growing prefixes of each word as `_wrap` accumulates it, not
// stable whole-line strings — runs fresh each frame. The two scenarios are
// timed separately, plain vs a benchmark-local memoizing measurer, so the
// gap between them shows how much a session cache actually buys once the
// wrap cache is doing its job vs when it can't (an edit in flight).
//
// Correctness note: `TextAreaComponent.measurer`'s setter clears the wrap
// cache whenever the assigned instance changes (`==`, identity for these
// measurers). The view assigns `model.measurer = context.measurer` (i.e.
// `buffer.measurer`) on every frame, so each benchmark below builds ONE
// [Buffer] with ONE fixed measurer instance in `setup()` and never swaps it —
// the same instance reaches the model every frame, so the wrap cache is never
// invalidated by the benchmark itself, only by the typing scenario's own edits
// (a real invalidation: the edited line's content actually changed).
//
// Run:  dart run benchmark/textarea_width_benchmark.dart

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

// ── Scenario: a wide, tall editor over a long document ───────────────────────
const int kLineCount = 200;
const int kLineChars = 200;
const int kAreaWidth = 100;
const int kAreaHeight = 40;
const int kScrollRow = 100; // mid-document
const int kFrameBudgetUs = 16667; // 60fps

/// Deterministic filler vocabulary — short ASCII words plus a sprinkling of
/// wide (CJK/emoji) glyphs, so both the plain and wide-cell wrap/paint paths
/// are exercised.
const _words = [
  'the',
  'quick',
  'brown',
  'fox',
  'jumps',
  'over',
  'lazy',
  'dog',
  'lorem',
  'ipsum',
  'dolor',
  'sit',
  'amet',
  'consectetur',
  'adipiscing',
  'elit',
  'widget',
  'render',
  'buffer',
  'measure',
  'session',
  'cache',
  'wrap',
  'cursor',
  'scroll',
  'frame',
  'paint',
  'layout',
  'grapheme',
  'cluster',
];
const _wide = ['田', '中', '太', '郎', '明', '✅', '⏸', '🚀', '🔥', '本'];

/// Builds one ~[kLineChars]-character logical line, deterministic by index.
String _buildLine(int lineIndex) {
  final sb = StringBuffer();
  var token = 0;
  while (sb.length < kLineChars - 10) {
    sb
      ..write(_words[(lineIndex * 5 + token) % _words.length])
      ..write(' ');
    if (token % 6 == 5) {
      sb
        ..write(_wide[(lineIndex + token) % _wide.length])
        ..write(' ');
    }
    token++;
  }
  return sb.toString();
}

/// The full document: [kLineCount] lines of ~[kLineChars] characters, joined
/// by newlines — what `TextAreaModel(initial: ...)` loads at construction.
String buildDocument() => List.generate(kLineCount, _buildLine).join('\n');

/// Builds a model over [buildDocument], focused, cursor parked mid-document
/// (row [kScrollRow]) so the first paint scrolls the viewport there instead
/// of showing the top of the file.
TextAreaModel buildTextAreaModel() {
  final model = TextAreaModel(id: 'ta', initial: buildDocument(), focused: true);
  model.textArea
    ..row = kScrollRow
    ..column = 0;
  return model;
}

/// A benchmark-local memoizing measurer — see the table benchmark's header for
/// the full rationale. Thrown away with the rest of this file.
class MemoMeasurer extends TextMeasurer {
  /// Wraps the given measurer behind a memo.
  MemoMeasurer([this._inner = const TermUnicodeMeasurer()]);
  final TextMeasurer _inner;

  /// The memo table; `.length` after a run is what a session-long cache would
  /// hold for this screen.
  final Map<String, int> memo = {};

  @override
  int widthOf(String text) => memo[text] ??= _inner.widthOf(text);
}

// ── (a)/(b): steady state — same frame repainted, wrap cache fully warm ──────

class SteadyStateFrameBenchmark extends BenchmarkBase {
  final TextAreaModel model;
  final Rect area;
  final TextMeasurer measurer;
  late Buffer buffer;
  SteadyStateFrameBenchmark(super.name, {this.measurer = const TermUnicodeMeasurer()})
    : model = buildTextAreaModel(),
      area = Rect.create(x: 0, y: 0, width: kAreaWidth, height: kAreaHeight);

  @override
  void setup() => buffer = Buffer.empty(area, measurer: measurer);

  @override
  void exercise() => run(); // one frame per measured op

  @override
  void run() => Frame(area, buffer, 0).render(TextArea(model: model, theme: Theme.dark));
}

// ── (c): typing — one edit per frame, forcing a wrap recompute ───────────────

class TypingFrameBenchmark extends BenchmarkBase {
  final TextAreaModel model;
  final Rect area;
  final TextMeasurer measurer;
  late Buffer buffer;
  bool _grow = true;
  TypingFrameBenchmark(super.name, {this.measurer = const TermUnicodeMeasurer()})
    : model = buildTextAreaModel(),
      area = Rect.create(x: 0, y: 0, width: kAreaWidth, height: kAreaHeight);

  @override
  void setup() => buffer = Buffer.empty(area, measurer: measurer);

  @override
  void exercise() => run(); // one edit + one frame per measured op

  @override
  void run() {
    // One typing-like edit per frame: append or remove one character at the
    // end of the scrolled-into-view line, alternating so the line's length
    // stays put on average. This is what invalidates that one line's cached
    // wrap (a real content change — `TextAreaComponent`'s `LineCache` is keyed
    // on line content, so this is not a benchmark artifact) and forces `_wrap`
    // to re-run its widthOf calls for that line, every frame.
    final ta = model.textArea
      ..row = kScrollRow
      ..setCursorEnd();
    if (_grow) {
      ta.insert('x');
    } else {
      ta.deleteCharBackward();
    }
    _grow = !_grow;
    Frame(area, buffer, 0).render(TextArea(model: model, theme: Theme.dark));
  }
}

void main() {
  final us = <String, double>{};
  double bench(BenchmarkBase b) => us[b.name] = b.measure();

  final steadyPlain = bench(SteadyStateFrameBenchmark('steadyState plain'));
  final steadyMemoMeasurer = MemoMeasurer();
  final steadyMemo = bench(SteadyStateFrameBenchmark('steadyState memo', measurer: steadyMemoMeasurer));

  final typingPlain = bench(TypingFrameBenchmark('typing plain'));
  final typingMemoMeasurer = MemoMeasurer();
  final typingMemo = bench(TypingFrameBenchmark('typing memo', measurer: typingMemoMeasurer));

  String u(double v) => '${v.toStringAsFixed(1)}µs';
  String budget(double v) => '${(v / kFrameBudgetUs * 100).toStringAsFixed(3)}% of budget';
  String saving(double plain, double memo) {
    final delta = plain - memo;
    final pct = plain == 0 ? 0.0 : delta / plain * 100;
    return '${u(delta)}  (${pct.toStringAsFixed(1)}% of frame, ${budget(delta)})';
  }

  // Benchmark output; a plain print is the whole point of this script.
  // ignore: avoid_print
  print('''

════════════════════════════════════════════════════════════════════════
 Text area render — steady state vs typing, plain vs memoized measurer
 Scenario: $kAreaWidth×$kAreaHeight editor, $kLineCount lines × ~${kLineChars}chars,
           mixed ASCII/CJK/emoji, scrolled to line $kScrollRow
 60fps frame budget: $kFrameBudgetUsµs
────────────────────────────────────────────────────────────────────────
 (a)/(b) STEADY STATE — same frame repainted, wrap cache warm (LineCache
 hits every line; only paint-time per-cluster measuring runs fresh):
   plain .................... ${u(steadyPlain)}   (${budget(steadyPlain)})
   memo ...................... ${u(steadyMemo)}   (${budget(steadyMemo)})
   saving .................... ${saving(steadyPlain, steadyMemo)}
   memo table after the run .. ${steadyMemoMeasurer.memo.length} entries

 (c) TYPING — one append/delete edit per frame at the scrolled-into-view
 line, forcing that line's wrap to recompute (a real LineCache miss) every
 frame, on top of the same paint-time measuring as steady state:
   plain .................... ${u(typingPlain)}   (${budget(typingPlain)})
   memo ...................... ${u(typingMemo)}   (${budget(typingMemo)})
   saving .................... ${saving(typingPlain, typingMemo)}
   memo table after the run .. ${typingMemoMeasurer.memo.length} entries
════════════════════════════════════════════════════════════════════════
''');
}
