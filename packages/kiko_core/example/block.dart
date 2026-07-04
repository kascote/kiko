import 'package:kiko/kiko.dart';

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
  final rows = <Node>[
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
      ConstrainedBox(
        additionalConstraints: const BoxConstraints(minH: 4, maxH: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _demos[i]()),
            Expanded(child: _demos[i + 1]()),
          ],
        ),
      ),
    );
  }

  frame.renderNode(
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
  );
}

/// Demo cells, two per grid row. `Borders.left/right/top/bottom` had no
/// plume-native replacement — [box] only ever draws a uniform border on all
/// four sides or none — so only the ALL/NONE cases from that old demo survive.
final _demos = <Node Function()>[
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

Node _bordersAll() => box(border: BorderType.plain, topTitles: [Line('Borders::ALL')], child: lineNode(_placeHolder));

Node _bordersNone() => box(topTitles: [Line('Borders::NONE')], child: lineNode(_placeHolder));

Node _borderType(BorderType type, String name) =>
    box(border: type, topTitles: [Line('BorderType::$name')], child: lineNode(_placeHolder));

Node _styledBlock() => box(
  border: BorderType.plain,
  background: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
  topTitles: [Line('Styled block')],
  child: lineNode(_placeHolder),
);

Node _styledBorder() => box(
  border: BorderType.plain,
  borderStyle: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
  topTitles: [Line('Styled borders')],
  child: lineNode(_placeHolder),
);

Node _styledTitle() => box(
  border: BorderType.plain,
  topTitles: [
    Line(
      'Styled title',
      style: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
    ),
  ],
  child: lineNode(_placeHolder),
);

Node _styledTitleContent() => box(
  border: BorderType.plain,
  topTitles: [
    Line.fromSpans([
      Text(
        'Styled ',
        style: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
      ),
      Text(
        'title content',
        style: Style(fg: Color.red, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
      ),
    ]),
  ],
  child: lineNode(_placeHolder),
);

Node _multipleTitles() => box(
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

Node _multipleTitlePositions() => box(
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

Node _padding() => box(
  border: BorderType.plain,
  padding: const EdgeInsets.only(left: 5, top: 1, right: 10, bottom: 2),
  topTitles: [Line('Padding')],
  child: lineNode(_placeHolder),
);

Node _nestedBlocks() => box(
  border: BorderType.plain,
  topTitles: [Line('Outer block')],
  child: box(border: BorderType.plain, topTitles: [Line('Inner block')], child: lineNode(_placeHolder)),
);
