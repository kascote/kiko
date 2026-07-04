import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;

Future<void> main() async {
  await Application(
    title: 'Layout proportions Example',
  ).runStateless(
    update: (_, msg) => switch (msg) {
      KeyMsg(key: 'q') => (null, const Quit()),
      _ => (null, null),
    },
    view: (_, frame) => draw(frame),
  );
}

// Cell size for the example grid, in cells.
const _cellWidth = 15;
const _cellHeight = 7;

void draw(Frame frame) {
  final header = Text.fromLines([
    Line(
      'Plume flex layout example',
      style: const Style(fg: Color.darkGray),
      alignment: Alignment.center,
    ),
    Line('Each row cycles one flex knob across a fixed Row of three swatches.'),
    Line("Note: labels that don't fit their cell are truncated"),
  ]);

  final ui = plume.Column<PaintToken>(
    crossAxisAlignment: plume.CrossAxisAlignment.stretch,
    children: [
      textNode(header),
      plume.SizedBox<PaintToken>(height: 1),
      _sectionTitle('MainAxisAlignment'),
      _row([for (final a in plume.MainAxisAlignment.values) _cell(a.name, _mainAxisDemo(a))]),
      plume.SizedBox<PaintToken>(height: 1),
      _sectionTitle('CrossAxisAlignment'),
      _row([for (final a in plume.CrossAxisAlignment.values) _cell(a.name, _crossAxisDemo(a))]),
      plume.SizedBox<PaintToken>(height: 1),
      _sectionTitle('Expanded flex ratios'),
      _row([
        _cell('1:1', _flexDemo(1, 1)),
        _cell('1:2', _flexDemo(1, 2)),
        _cell('2:1', _flexDemo(2, 1)),
        _cell('1:3', _flexDemo(1, 3)),
        _cell('3:1', _flexDemo(3, 1)),
      ]),
      plume.Expanded<PaintToken>(child: plume.SizedBox<PaintToken>()),
    ],
  );

  frame.renderNode(ui);
}

plume.RenderNode<PaintToken> _sectionTitle(String title) =>
    lineNode(Line(title, style: const Style(fg: Color.darkGray)));

plume.RenderNode<PaintToken> _row(List<plume.RenderNode<PaintToken>> cells) => plume.Row<PaintToken>(children: cells);

/// A titled, fixed-size cell holding one flex demo.
plume.RenderNode<PaintToken> _cell(String title, plume.RenderNode<PaintToken> demo) => plume.ConstrainedBox<PaintToken>(
  additionalConstraints: const plume.BoxConstraints(
    minW: _cellWidth,
    maxW: _cellWidth,
    minH: _cellHeight,
    maxH: _cellHeight,
  ),
  child: box(
    border: BorderType.plain,
    borderStyle: const Style(fg: Color.darkGray),
    topTitles: [Line(title, style: const Style(fg: Color.green))],
    child: demo,
  ),
);

/// A same-size red/blue/green Row packed by [alignment].
plume.RenderNode<PaintToken> _mainAxisDemo(plume.MainAxisAlignment alignment) => plume.Row<PaintToken>(
  mainAxisAlignment: alignment,
  children: [_swatch(Color.red), _swatch(Color.blue), _swatch(Color.green)],
);

/// A different-height red/blue/green Row positioned on the cross axis by
/// [alignment] — `stretch` overrides each swatch's own height, the others
/// keep it.
plume.RenderNode<PaintToken> _crossAxisDemo(plume.CrossAxisAlignment alignment) => plume.Row<PaintToken>(
  crossAxisAlignment: alignment,
  children: [
    _swatch(Color.red),
    _swatch(Color.blue, height: 3),
    _swatch(Color.green, height: 2),
  ],
);

/// Two Expanded swatches sharing the row's width by an [a]:[b] flex ratio.
plume.RenderNode<PaintToken> _flexDemo(int a, int b) => plume.Row<PaintToken>(
  children: [
    plume.Expanded<PaintToken>(flex: a, child: _fill(Color.red)),
    plume.Expanded<PaintToken>(flex: b, child: _fill(Color.blue)),
  ],
);

plume.RenderNode<PaintToken> _swatch(Color color, {int width = 3, int height = 1}) => plume.Container<PaintToken>(
  width: width,
  height: height,
  background: PaintToken(Style(bg: color)),
  child: plume.SizedBox<PaintToken>(),
);

plume.RenderNode<PaintToken> _fill(Color color) => plume.Container<PaintToken>(
  background: PaintToken(Style(bg: color)),
  child: plume.SizedBox<PaintToken>(),
);
