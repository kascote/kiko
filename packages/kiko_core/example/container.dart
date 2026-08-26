import 'dart:io';

import 'package:kiko/kiko.dart';

Future<void> main() async {
  exit(
    await Application(
      title: 'Container Example',
    ).runStateless(
      update: (_, msg, _) => switch (msg) {
        KeyMsg(key: 'q') => (null, const Quit()),
        _ => (null, null),
      },
      view: (_, frame) => draw(frame),
    ),
  );
}

void draw(Frame frame) {
  final rows = <View>[
    Center(
      child: Line(
        'Container example. Press q to quit',
        style: const Style(fg: Color.darkGray),
      ),
    ),
  ];
  for (var i = 0; i < _demos.length; i += 2) {
    rows.add(
      ConstrainedBox(
        additionalConstraints: const BoxConstraints(minH: 4, maxH: 4),
        child: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _demos[i]()),
            Expanded(child: _demos[i + 1]()),
          ],
        ),
      ),
    );
  }

  frame.render(
    Column(crossAxis: CrossAxisAlignment.stretch, children: rows),
  );
}

/// Demo cells, two per grid row. `Borders.left/right/top/bottom` had no
/// plume-native replacement — [Container] only ever draws a uniform border on
/// all four sides or none — so only the ALL/NONE cases from that old demo survive.
final _demos = <View Function()>[
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
  _titlesBothEdges,
  _padding,
  _nestedBlocks,
];

final _placeHolder = Line(
  'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
  style: const Style(fg: Color.darkGray),
);

View _bordersAll() => Container(border: BorderType.plain, topTitles: [Line('Borders::ALL')], child: _placeHolder);

View _bordersNone() => Container(topTitles: [Line('Borders::NONE')], child: _placeHolder);

View _borderType(BorderType type, String name) =>
    Container(border: type, topTitles: [Line('BorderType::$name')], child: _placeHolder);

View _styledBlock() => Container(
  border: BorderType.plain,
  ground: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
  topTitles: [Line('Styled block')],
  child: _placeHolder,
);

View _styledBorder() => Container(
  border: BorderType.plain,
  borderStyle: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
  topTitles: [Line('Styled borders')],
  child: _placeHolder,
);

View _styledTitle() => Container(
  border: BorderType.plain,
  topTitles: [
    Line(
      'Styled title',
      style: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
    ),
  ],
  child: _placeHolder,
);

View _styledTitleContent() => Container(
  border: BorderType.plain,
  topTitles: [
    Line.fromTexts([
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
  child: _placeHolder,
);

View _multipleTitles() => Container(
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
  child: _placeHolder,
);

/// Per-title side positioning (left/center/right) had no plume-native
/// replacement — [Container] packs every title at the start of its edge — so
/// this now just shows several titles riding both the top and bottom edges.
View _titlesBothEdges() => Container(
  border: BorderType.plain,
  topTitles: [Line('top one'), Line('top two'), Line('top three')],
  bottomTitles: [Line('bottom one'), Line('bottom two'), Line('bottom three')],
  child: _placeHolder,
);

View _padding() => Container(
  border: BorderType.plain,
  padding: const EdgeInsets.only(left: 5, top: 1, right: 10),
  topTitles: [Line('Padding')],
  child: _placeHolder,
);

View _nestedBlocks() => Container(
  border: BorderType.plain,
  topTitles: [Line('Outer block')],
  child: Container(border: BorderType.plain, topTitles: [Line('Inner block')], child: _placeHolder),
);
