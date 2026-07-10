import 'package:kiko/kiko.dart';

Future<void> main() async {
  await Application(
    title: 'Color Demo',
  ).runStateless(
    update: (_, msg, _) => switch (msg) {
      KeyMsg(key: 'q') => (null, const Quit()),
      _ => (null, null),
    },
    view: (_, frame) => draw(frame),
  );
}

void draw(Frame frame) {
  final ui = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      _namedColorsPanel(),
      _indexedColorsPanel(),
      Expanded(child: _grayScalePanel()),
    ],
  );

  frame.render(ui);
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
/// top-border-only, titled `Block`; [Box] only ever draws a uniform border on
/// all four sides or none, so a single-edge rule is no longer expressible.
View _sectionTitle(String title) => Center(child: Line(title));

// ─── Named colors ────────────────────────────────────────────────────────

View _namedColorsPanel() => Column(
  crossAxis: CrossAxisAlignment.stretch,
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
View _namedColorFgSection(String nameCol, Color bg) =>
    _namedColorGrid(title: 'Foreground colors on $nameCol background', fgAt: (i) => _colors[i], bgAt: (_) => bg);

/// The 16 named colors as background, under a fixed [fg] foreground.
View _namedColorBgSection(String nameCol, Color fg) =>
    _namedColorGrid(title: 'Background colors with $nameCol foreground', fgAt: (_) => fg, bgAt: (i) => _colors[i]);

View _namedColorGrid({
  required String title,
  required Color Function(int) fgAt,
  required Color Function(int) bgAt,
}) {
  View row(int start) => Row(
    children: [
      for (var i = start; i < start + 8; i++)
        Expanded(
          child: Line(
            _colorNames[i],
            style: Style(fg: fgAt(i), bg: bgAt(i)),
          ),
        ),
    ],
  );

  return Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [_sectionTitle(title), row(0), row(8)],
  );
}

// ─── Indexed colors (0-231) ──────────────────────────────────────────────

View _indexedColorsPanel() => Column(
  crossAxis: CrossAxisAlignment.stretch,
  children: [
    _sectionTitle('Indexed colors'),
    _indexedRow16(),
    const SizedBox(height: 1),
    _indexedColorBlock(16, 123),
    const SizedBox(height: 1),
    _indexedColorBlock(124, 231),
    const SizedBox(height: 1),
  ],
);

View _indexedRow16() => Row(
  children: [
    for (var i = 0; i < 16; i++)
      ConstrainedBox(
        additionalConstraints: const BoxConstraints(minW: 5, maxW: 5),
        child: _indexedCell16(i),
      ),
  ],
);

View _indexedCell16(int index) {
  final color = Color.indexed(index);
  final colorIndex = index.toString().padLeft(2, '0');
  final bg = index < 1 ? Color.darkGray : Color.black;
  return Line.fromTexts([
    Text(
      colorIndex,
      style: Style(fg: color, bg: bg),
    ),
    Text(
      '  ',
      style: Style(fg: color, bg: color),
    ),
  ]);
}

/// Three side-by-side 27-column groups, each a 6×6 grid of indexed swatches.
View _indexedColorBlock(int startIndex, int endIndex) {
  final groups = <View>[];
  var idx = startIndex;
  for (var group = 0; group < 3 && idx <= endIndex; group++) {
    final rows = <View>[];
    for (var row = 0; row < 6 && idx <= endIndex; row++) {
      final cells = <View>[];
      for (var col = 0; col < 6 && idx <= endIndex; col++) {
        cells.add(Expanded(child: _indexedCellSmall(idx)));
        idx++;
      }
      rows.add(Row(children: cells));
    }
    groups.add(
      ConstrainedBox(
        additionalConstraints: const BoxConstraints(minW: 27, maxW: 27),
        child: Column(children: rows),
      ),
    );
  }
  return Row(children: groups);
}

View _indexedCellSmall(int index) {
  final color = Color.indexed(index);
  final colorIndex = index.toString().padLeft(3, '0');
  return Line.fromTexts([
    Text(
      colorIndex,
      style: Style(fg: color, bg: Color.reset),
    ),
    Text(
      '.',
      style: Style(fg: color, bg: color),
    ),
  ]);
}

// ─── Grayscale (232-255) ─────────────────────────────────────────────────

View _grayScalePanel() => Column(children: [_grayScaleRow(232), _grayScaleRow(244)]);

View _grayScaleRow(int startIndex) => Row(
  children: [
    for (var i = startIndex; i < startIndex + 12; i++)
      ConstrainedBox(
        additionalConstraints: const BoxConstraints(minW: 6, maxW: 6),
        child: _grayScaleCell(i),
      ),
  ],
);

View _grayScaleCell(int index) {
  final color = Color.indexed(index);
  final colorIndex = index.toString().padLeft(3, '0');
  final bg = index < 244 ? Color.gray : Color.black;
  return Line.fromTexts([
    Text(
      colorIndex,
      style: Style(fg: color, bg: bg),
    ),
    Text(
      '  ',
      style: Style(fg: color, bg: color),
    ),
    const Text('       '),
  ]);
}
