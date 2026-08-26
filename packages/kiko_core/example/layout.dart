import 'dart:io';

import 'package:kiko/kiko.dart';

Future<void> main() async {
  exit(
    await Application(
      title: 'Layout proportions Example',
    ).runStateless(
      update: (_, msg, _) => switch (msg) {
        KeyMsg(key: 'q') => (null, const Quit()),
        _ => (null, null),
      },
      view: (_, frame) => draw(frame),
    ),
  );
}

// Cell size for the example grid, in cells.
const _cellWidth = 15;
const _cellHeight = 7;

void draw(Frame frame) {
  final header = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: Line(
          'Plume flex layout example',
          style: const Style(fg: Color.darkGray),
        ),
      ),
      Line('Each row cycles one flex knob across a fixed Row of three swatches.'),
      Line("Note: labels that don't fit their cell are truncated"),
    ],
  );

  final ui = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      header,
      const SizedBox(height: 1),
      _sectionTitle('MainAxisAlignment'),
      _row([for (final a in MainAxisAlignment.values) _cell(a.name, _mainAxisDemo(a))]),
      const SizedBox(height: 1),
      _sectionTitle('CrossAxisAlignment'),
      _row([for (final a in CrossAxisAlignment.values) _cell(a.name, _crossAxisDemo(a))]),
      const SizedBox(height: 1),
      _sectionTitle('Expanded flex ratios'),
      _row([
        _cell('1:1', _flexDemo(1, 1)),
        _cell('1:2', _flexDemo(1, 2)),
        _cell('2:1', _flexDemo(2, 1)),
        _cell('1:3', _flexDemo(1, 3)),
        _cell('3:1', _flexDemo(3, 1)),
      ]),
      const Expanded(child: SizedBox()),
    ],
  );

  frame.render(ui);
}

View _sectionTitle(String title) => Line(title, style: const Style(fg: Color.darkGray));

View _row(List<View> cells) => Row(children: cells);

/// A titled, fixed-size cell holding one flex demo.
View _cell(String title, View demo) => ConstrainedBox(
  additionalConstraints: const BoxConstraints(
    minW: _cellWidth,
    maxW: _cellWidth,
    minH: _cellHeight,
    maxH: _cellHeight,
  ),
  child: Container(
    border: BorderType.plain,
    borderStyle: const Style(fg: Color.darkGray),
    topTitles: [Line(title, style: const Style(fg: Color.green))],
    child: demo,
  ),
);

/// A same-size red/blue/green Row packed by [alignment].
View _mainAxisDemo(MainAxisAlignment alignment) => Row(
  mainAxis: alignment,
  children: [_swatch(Color.red), _swatch(Color.blue), _swatch(Color.green)],
);

/// A different-height red/blue/green Row positioned on the cross axis by
/// [alignment] — `stretch` overrides each swatch's own height, the others
/// keep it.
View _crossAxisDemo(CrossAxisAlignment alignment) => Row(
  crossAxis: alignment,
  children: [
    _swatch(Color.red),
    _swatch(Color.blue, height: 3),
    _swatch(Color.green, height: 2),
  ],
);

/// Two Expanded swatches sharing the row's width by an [a]:[b] flex ratio.
View _flexDemo(int a, int b) => Row(
  crossAxis: CrossAxisAlignment.stretch,
  children: [
    Expanded(flex: a, child: _fill(Color.red)),
    Expanded(flex: b, child: _fill(Color.blue)),
  ],
);

View _swatch(Color color, {int width = 3, int height = 1}) => Container(
  width: width,
  height: height,
  ground: Style(bg: color),
  child: const SizedBox(),
);

View _fill(Color color) => Container(
  ground: Style(bg: color),
  child: const SizedBox(),
);
