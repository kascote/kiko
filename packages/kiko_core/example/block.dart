import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;

Future<void> main() async {
  await Application(
    title: 'Block Example',
  ).runStateless(
    update: (_, msg) => switch (msg) {
      KeyMsg(key: 'q') => (null, const Quit()),
      _ => (null, null),
    },
    view: (_, frame) => draw(frame),
  );
}

void draw(Frame frame) {
  final rows = <plume.RenderNode<PaintToken>>[
    lineNode(
      Line(
        'Block example. Press q to quit',
        alignment: Alignment.center,
        style: const Style(fg: Color.darkGray),
      ),
    ),
  ];
  for (var i = 0; i < _demos.length; i += 2) {
    rows.add(
      plume.ConstrainedBox<PaintToken>(
        additionalConstraints: const plume.BoxConstraints(minH: 4, maxH: 4),
        child: plume.Row<PaintToken>(
          crossAxisAlignment: plume.CrossAxisAlignment.stretch,
          children: [
            plume.Expanded<PaintToken>(child: _demos[i]()),
            plume.Expanded<PaintToken>(child: _demos[i + 1]()),
          ],
        ),
      ),
    );
  }

  frame.renderNode(
    plume.Column<PaintToken>(crossAxisAlignment: plume.CrossAxisAlignment.stretch, children: rows),
  );
}

/// Demo cells, two per grid row. `Borders.left/right/top/bottom` had no
/// plume-native replacement — [box] only ever draws a uniform border on all
/// four sides or none — so only the ALL/NONE cases from that old demo survive.
final _demos = <plume.RenderNode<PaintToken> Function()>[
  _bordersAll,
  _bordersNone,
  () => _borderType(BorderType.plain, 'PLAIN'),
  () => _borderType(BorderType.rounded, 'ROUNDED'),
  () => _borderType(BorderType.double, 'DOUBLE'),
  () => _borderType(BorderType.thick, 'THICK'),
  _styledBlock,
  _styledBorder,
  _styledTitle,
  _styledTitleContent,
  _multipleTitles,
  _multipleTitlePositions,
  _padding,
  _nestedBlocks,
];

final _placeHolder = Line(
  'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
  style: const Style(fg: Color.darkGray),
);

plume.RenderNode<PaintToken> _bordersAll() =>
    box(border: BorderType.plain, topTitles: [Line('Borders::ALL')], child: lineNode(_placeHolder));

plume.RenderNode<PaintToken> _bordersNone() => box(topTitles: [Line('Borders::NONE')], child: lineNode(_placeHolder));

plume.RenderNode<PaintToken> _borderType(BorderType type, String name) =>
    box(border: type, topTitles: [Line('BorderType::$name')], child: lineNode(_placeHolder));

plume.RenderNode<PaintToken> _styledBlock() => box(
  border: BorderType.plain,
  background: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
  topTitles: [Line('Styled block')],
  child: lineNode(_placeHolder),
);

plume.RenderNode<PaintToken> _styledBorder() => box(
  border: BorderType.plain,
  borderStyle: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
  topTitles: [Line('Styled borders')],
  child: lineNode(_placeHolder),
);

plume.RenderNode<PaintToken> _styledTitle() => box(
  border: BorderType.plain,
  topTitles: [
    Line(
      'Styled title',
      style: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
    ),
  ],
  child: lineNode(_placeHolder),
);

plume.RenderNode<PaintToken> _styledTitleContent() => box(
  border: BorderType.plain,
  topTitles: [
    Line.fromSpans([
      Span(
        'Styled ',
        style: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
      ),
      Span(
        'title content',
        style: Style(fg: Color.red, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
      ),
    ]),
  ],
  child: lineNode(_placeHolder),
);

plume.RenderNode<PaintToken> _multipleTitles() => box(
  border: BorderType.plain,
  topTitles: [
    Line(
      'Multiple',
      style: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
    ),
    Line(
      'Titles',
      style: Style(fg: Color.red, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
    ),
  ],
  child: lineNode(_placeHolder),
);

plume.RenderNode<PaintToken> _multipleTitlePositions() => box(
  border: BorderType.plain,
  topTitles: [
    Line('top left', alignment: Alignment.left),
    Line('top center', alignment: Alignment.center),
    Line('top right', alignment: Alignment.right),
  ],
  bottomTitles: [
    Line('bottom left', alignment: Alignment.left),
    Line('bottom center', alignment: Alignment.center),
    Line('bottom right', alignment: Alignment.right),
  ],
  child: lineNode(_placeHolder),
);

plume.RenderNode<PaintToken> _padding() => box(
  border: BorderType.plain,
  padding: const plume.EdgeInsets.only(left: 5, top: 1, right: 10, bottom: 2),
  topTitles: [Line('Padding')],
  child: lineNode(_placeHolder),
);

plume.RenderNode<PaintToken> _nestedBlocks() => box(
  border: BorderType.plain,
  topTitles: [Line('Outer block')],
  child: box(border: BorderType.plain, topTitles: [Line('Inner block')], child: lineNode(_placeHolder)),
);
