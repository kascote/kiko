import 'package:kiko/kiko.dart';

// ═══════════════════════════════════════════════════════════
// A grapheme "torture gallery".
//
// Every sample sits in a fixed-width Box. The box's right border only lines up
// if the width measurer counts the sample's cells correctly, so a measurement
// bug shears the borders instead of hiding — the eye is the test oracle.
//
// Tab toggles the frame measurer between default and cjk (ambiguous-width glyphs
// count as two cells); the same ambiguous row renders differently under each.
// ═══════════════════════════════════════════════════════════

class UnicodeModel {
  final bool cjk;

  const UnicodeModel({this.cjk = false});

  UnicodeModel toggleCjk() => UnicodeModel(cjk: !cjk);
}

(UnicodeModel, Cmd?) update(UnicodeModel model, Msg msg) => switch (msg) {
  KeyMsg(key: 'q') => (model, const Quit()),
  KeyMsg(key: 'tab') => (model.toggleCjk(), null),
  _ => (model, null),
};

void view(UnicodeModel model, Frame frame) {
  final measurer = TermUnicodeMeasurer(cjk: model.cjk);

  final ui = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: Line.fromTexts([
          const Text('Unicode / grapheme gallery — '),
          Text(
            model.cjk ? 'measurer: CJK (ambiguous = wide)' : 'measurer: default',
            style: const Style(fg: Color.yellow, addModifier: Modifier.bold),
          ),
        ]),
      ),
      Center(
        child: Line(
          'Tab toggles cjk · q quits · borders shear on a width bug',
          style: const Style(fg: Color.darkGray),
        ),
      ),
      const SizedBox(height: 1),
      _section('Fullwidth / CJK', const [
        _Sample('hanzi', '世界'),
        _Sample('kana', 'こんにちは'),
        _Sample('fullwidth', 'ＡＢＣ１２３'),
        _Sample('mixed', 'aあb'),
      ]),
      _section('Emoji (single codepoint)', const [
        _Sample('star', '★ ☆'),
        _Sample('symbols', '🔥 🎯 ✨'),
        _Sample('arrows', '→ ⇒ ⟶'),
      ]),
      _section('Emoji clusters (ZWJ / flags / skin tone)', const [
        _Sample('family', '👨‍👩‍👧‍👦'),
        _Sample('tech', '🧑‍💻'),
        _Sample('flags', '🇯🇵 🇦🇷'),
        _Sample('skin', '👋🏽 👍🏿'),
      ]),
      _section('Combining marks (base + accent = one cluster)', const [
        _Sample('acute', 'é á ó'),
        _Sample('tilde', 'ñ'),
        _Sample('stacked', 'ạ́'),
      ]),
      _section('Ambiguous width (changes with cjk)', const [
        _Sample('greek', 'αβγδ'),
        _Sample('marks', '§¶±×'),
        _Sample('lines', '│─┼'),
      ]),
      _mixedRuns(),
      const Expanded(child: SizedBox()),
    ],
  );

  frame.render(ui, measurer: measurer);
}

/// Long heterogeneous runs in one full-width box, each right-aligned so its
/// final glyph should land flush against the right border. The small boxes above
/// hold one glyph type each; these mix scripts, emoji, clusters and combining
/// marks in a single run, where width bugs hide at the boundaries between types
/// and accumulate over length. If every glyph is measured right, all four line
/// ends form a straight column against the border; a mismeasure floats one off.
View _mixedRuns() => Column(
  crossAxis: CrossAxisAlignment.stretch,
  children: [
    Line('Mixed runs — each line ends flush at the right border', style: const Style(fg: Color.green)),
    Box(
      border: BorderType.rounded,
      borderStyle: const Style(fg: Color.darkGray),
      child: Column(
        crossAxis: CrossAxisAlignment.stretch,
        children: [
          for (final (i, run) in _mixedRunLines.indexed)
            Row(mainAxis: MainAxisAlignment.end, children: [_mixedLine(run, i)]),
        ],
      ),
    ),
  ],
);

/// Builds one right-aligned run, coloring its trailing marker so we can see the
/// styled glyph stops exactly at the border and never tints the border cell.
/// The color alternates by line, so odd and even ends are visibly distinct.
View _mixedLine((String, String) run, int index) {
  final (head, tail) = run;
  final tailColor = index.isEven ? Color.brightGreen : Color.brightMagenta;
  return Line.fromTexts([
    Text(head),
    Text(
      tail,
      style: Style(fg: tailColor, addModifier: Modifier.bold),
    ),
  ]);
}

// Each run is (body, trailing marker); the marker is the colored, border-hugging
// glyph under test.
const _mixedRunLines = <(String, String)>[
  ('latin→cjk→emoji:  café · 世界 · 🔥 · 日本語 · ★ ', '✓'),
  ('clusters:  👨‍👩‍👧‍👦 family · 🇯🇵 flag · 👋🏽 wave · 🧑‍💻 ', '‖'),
  ('combining:  e̋ ñ ō̈ · base+mark · aあb mixed width ', '⟩'),
  ('symbols/box:  ┌─┬─┐ · ½ ¾ · §¶±× · αβγ ambiguous ', '⟨end⟩'),
];

/// One labelled sample in a fixed-width box; the right border is the assertion.
class _Sample {
  final String label;
  final String text;
  const _Sample(this.label, this.text);
}

/// A titled row of same-width sample boxes.
View _section(String title, List<_Sample> samples) => Column(
  crossAxis: CrossAxisAlignment.stretch,
  children: [
    Line(title, style: const Style(fg: Color.green)),
    Row(
      crossAxis: CrossAxisAlignment.stretch,
      children: [for (final s in samples) _sampleCell(s)],
    ),
    const SizedBox(height: 1),
  ],
);

View _sampleCell(_Sample s) => ConstrainedBox(
  additionalConstraints: const BoxConstraints(minW: 18, maxW: 18, minH: 4, maxH: 4),
  child: Box(
    border: BorderType.rounded,
    borderStyle: const Style(fg: Color.darkGray),
    topTitles: [Line(s.label, style: const Style(fg: Color.blue))],
    child: Center(child: Line(s.text)),
  ),
);

void main() async {
  await Application(title: 'Unicode gallery').run(
    init: const UnicodeModel(),
    update: update,
    view: view,
  );
}
