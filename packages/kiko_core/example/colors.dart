import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;

Future<void> main() async {
  await Application(
    title: 'Color Demo',
  ).runStateless(
    update: (_, msg) => switch (msg) {
      KeyMsg(key: 'q') => (null, const Quit()),
      _ => (null, null),
    },
    view: (_, frame) => draw(frame),
  );
}

void draw(Frame frame) {
  final ui = plume.Column<PaintToken>(
    crossAxisAlignment: plume.CrossAxisAlignment.stretch,
    children: [
      _namedColorsPanel(),
      _indexedColorsPanel(),
      plume.Expanded<PaintToken>(child: _grayScalePanel()),
    ],
  );

  frame.renderNode(ui);
}

const List<Color> _colors = [
  Color.black,
  Color.red,
  Color.green,
  Color.yellow,
  Color.blue,
  Color.magenta,
  Color.cyan,
  Color.gray,
  Color.darkGray,
  Color.brightRed,
  Color.brightGreen,
  Color.brightYellow,
  Color.brightBlue,
  Color.brightMagenta,
  Color.brightCyan,
  Color.white,
];

const List<String> _colorNames = [
  'Black',
  'Red',
  'Green',
  'Yellow',
  'Blue',
  'Magenta',
  'Cyan',
  'Gray',
  'DarkGray',
  'LightRed',
  'LightGreen',
  'LightYellow',
  'LightBlue',
  'LightMagenta',
  'LightCyan',
  'White',
];

/// A centered header line — the plume-native stand-in for the old
/// top-border-only, titled `Block`; [box] only ever draws a uniform border on
/// all four sides or none, so a single-edge rule is no longer expressible.
plume.RenderNode<PaintToken> _sectionTitle(String title) => lineNode(Line(title, alignment: Alignment.center));

// ─── Named colors ────────────────────────────────────────────────────────

plume.RenderNode<PaintToken> _namedColorsPanel() => plume.Column<PaintToken>(
  crossAxisAlignment: plume.CrossAxisAlignment.stretch,
  children: [
    _namedColorFgSection('reset', Color.reset),
    _namedColorFgSection('black', Color.black),
    _namedColorFgSection('darkGray', Color.darkGray),
    _namedColorFgSection('gray', Color.gray),
    _namedColorFgSection('white', Color.white),
    _namedColorBgSection('reset', Color.reset),
    _namedColorBgSection('black', Color.black),
    _namedColorBgSection('darkGray', Color.darkGray),
    _namedColorBgSection('gray', Color.gray),
    _namedColorBgSection('white', Color.white),
  ],
);

/// The 16 named colors as foreground, on a fixed [bg] background.
plume.RenderNode<PaintToken> _namedColorFgSection(String nameCol, Color bg) =>
    _namedColorGrid(title: 'Foreground colors on $nameCol background', fgAt: (i) => _colors[i], bgAt: (_) => bg);

/// The 16 named colors as background, under a fixed [fg] foreground.
plume.RenderNode<PaintToken> _namedColorBgSection(String nameCol, Color fg) =>
    _namedColorGrid(title: 'Background colors with $nameCol foreground', fgAt: (_) => fg, bgAt: (i) => _colors[i]);

plume.RenderNode<PaintToken> _namedColorGrid({
  required String title,
  required Color Function(int) fgAt,
  required Color Function(int) bgAt,
}) {
  plume.RenderNode<PaintToken> row(int start) => plume.Row<PaintToken>(
    children: [
      for (var i = start; i < start + 8; i++)
        plume.Expanded<PaintToken>(
          child: lineNode(
            Line(
              _colorNames[i],
              style: Style(fg: fgAt(i), bg: bgAt(i)),
            ),
          ),
        ),
    ],
  );

  return plume.Column<PaintToken>(
    crossAxisAlignment: plume.CrossAxisAlignment.stretch,
    children: [_sectionTitle(title), row(0), row(8)],
  );
}

// ─── Indexed colors (0-231) ──────────────────────────────────────────────

plume.RenderNode<PaintToken> _indexedColorsPanel() => plume.Column<PaintToken>(
  crossAxisAlignment: plume.CrossAxisAlignment.stretch,
  children: [
    _sectionTitle('Indexed colors'),
    _indexedRow16(),
    plume.SizedBox<PaintToken>(height: 1),
    _indexedColorBlock(16, 123),
    plume.SizedBox<PaintToken>(height: 1),
    _indexedColorBlock(124, 231),
    plume.SizedBox<PaintToken>(height: 1),
  ],
);

plume.RenderNode<PaintToken> _indexedRow16() => plume.Row<PaintToken>(
  children: [
    for (var i = 0; i < 16; i++)
      plume.ConstrainedBox<PaintToken>(
        additionalConstraints: const plume.BoxConstraints(minW: 5, maxW: 5),
        child: _indexedCell16(i),
      ),
  ],
);

plume.RenderNode<PaintToken> _indexedCell16(int index) {
  final color = Color.indexed(index);
  final colorIndex = index.toString().padLeft(2, '0');
  final bg = index < 1 ? Color.darkGray : Color.black;
  return lineNode(
    Line.fromSpans([
      Span(
        colorIndex,
        style: Style(fg: color, bg: bg),
      ),
      Span(
        '  ',
        style: Style(fg: color, bg: color),
      ),
    ]),
  );
}

/// Three side-by-side 27-column groups, each a 6×6 grid of indexed swatches.
plume.RenderNode<PaintToken> _indexedColorBlock(int startIndex, int endIndex) {
  final groups = <plume.RenderNode<PaintToken>>[];
  var idx = startIndex;
  for (var group = 0; group < 3 && idx <= endIndex; group++) {
    final rows = <plume.RenderNode<PaintToken>>[];
    for (var row = 0; row < 6 && idx <= endIndex; row++) {
      final cells = <plume.RenderNode<PaintToken>>[];
      for (var col = 0; col < 6 && idx <= endIndex; col++) {
        cells.add(plume.Expanded<PaintToken>(child: _indexedCellSmall(idx)));
        idx++;
      }
      rows.add(plume.Row<PaintToken>(children: cells));
    }
    groups.add(
      plume.ConstrainedBox<PaintToken>(
        additionalConstraints: const plume.BoxConstraints(minW: 27, maxW: 27),
        child: plume.Column<PaintToken>(children: rows),
      ),
    );
  }
  return plume.Row<PaintToken>(children: groups);
}

plume.RenderNode<PaintToken> _indexedCellSmall(int index) {
  final color = Color.indexed(index);
  final colorIndex = index.toString().padLeft(3, '0');
  return lineNode(
    Line.fromSpans([
      Span(
        colorIndex,
        style: Style(fg: color, bg: Color.reset),
      ),
      Span(
        '.',
        style: Style(fg: color, bg: color),
      ),
    ]),
  );
}

// ─── Grayscale (232-255) ─────────────────────────────────────────────────

plume.RenderNode<PaintToken> _grayScalePanel() =>
    plume.Column<PaintToken>(children: [_grayScaleRow(232), _grayScaleRow(244)]);

plume.RenderNode<PaintToken> _grayScaleRow(int startIndex) => plume.Row<PaintToken>(
  children: [
    for (var i = startIndex; i < startIndex + 12; i++)
      plume.ConstrainedBox<PaintToken>(
        additionalConstraints: const plume.BoxConstraints(minW: 6, maxW: 6),
        child: _grayScaleCell(i),
      ),
  ],
);

plume.RenderNode<PaintToken> _grayScaleCell(int index) {
  final color = Color.indexed(index);
  final colorIndex = index.toString().padLeft(3, '0');
  final bg = index < 244 ? Color.gray : Color.black;
  return lineNode(
    Line.fromSpans([
      Span(
        colorIndex,
        style: Style(fg: color, bg: bg),
      ),
      Span(
        '  ',
        style: Style(fg: color, bg: color),
      ),
      const Span('       '),
    ]),
  );
}
