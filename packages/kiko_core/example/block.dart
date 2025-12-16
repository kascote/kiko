import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:termparser/termparser_events.dart' as evt;

Future<void> main() async {
  await Application(
    title: 'Block Example',
    onCleanup: (terminal) async {
      stderr.writeln('layoutCache ${layoutCacheStats()}');
    },
  ).runStateless(
    update: (_, msg) => switch (msg) {
      KeyMsg(key: evt.KeyEvent(code: evt.KeyCode(char: 'q'))) => (null, const Quit()),
      _ => (null, null),
    },
    view: (_, frame) => draw(frame),
  );
}

void draw(Frame frame) {
  final (titleArea, layout) = calculateLayout(frame.area);

  renderTitle(frame, titleArea);

  final placeHolderText = Text.raw(
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
    style: const Style(fg: Color.darkGray),
  );

  renderBorders(placeHolderText, Borders.all, 'ALL', frame, layout[0][0]);
  renderBorders(placeHolderText, Borders.none, 'NONE', frame, layout[0][1]);
  renderBorders(placeHolderText, Borders.left, 'LEFT', frame, layout[1][0]);
  renderBorders(placeHolderText, Borders.right, 'RIGHT', frame, layout[1][1]);
  renderBorders(placeHolderText, Borders.top, 'TOP', frame, layout[2][0]);
  renderBorders(placeHolderText, Borders.bottom, 'BOTTOM', frame, layout[2][1]);

  renderBorderType(placeHolderText, BorderType.plain, 'PLAIN', frame, layout[3][0]);
  renderBorderType(placeHolderText, BorderType.rounded, 'ROUNDED', frame, layout[3][1]);
  renderBorderType(placeHolderText, BorderType.double, 'DOUBLE', frame, layout[4][0]);
  renderBorderType(placeHolderText, BorderType.thick, 'THICK', frame, layout[4][1]);

  renderStyledBlock(placeHolderText, frame, layout[5][0]);
  renderStyledBorder(placeHolderText, frame, layout[5][1]);
  renderStyledTitle(placeHolderText, frame, layout[6][0]);
  renderStyledTitleContent(placeHolderText, frame, layout[6][1]);
  renderMultipleTitles(placeHolderText, frame, layout[7][0]);
  renderMultipleTitlePositions(placeHolderText, frame, layout[7][1]);
  renderPadding(placeHolderText, frame, layout[8][0]);
  renderNestedBlocks(placeHolderText, frame, layout[8][1]);
}

(Rect, List<List<Rect>>) calculateLayout(Rect area) {
  final mainLayout = Layout.vertical(const [ConstraintLength(1), ConstraintMin(0)]);
  final blockLayout = Layout.vertical(
    List.generate(9, (_) => const ConstraintMax(4)),
  );
  final [titleArea, mainArea] = mainLayout.areas(area);
  final mainAreas = blockLayout
      .split(mainArea)
      .map(
        (a) => Layout.horizontal(
          const [ConstraintPercent(50), ConstraintPercent(50)],
        ).split(a),
      )
      .toList();
  return (titleArea, mainAreas);
}

void renderTitle(Frame frame, Rect area) {
  frame.renderWidget(
    Text.raw(
      'Block example. Press q to quit',
      style: const Style(fg: Color.darkGray),
      alignment: Alignment.center,
    ),
    area,
  );
}

void renderBorders(Text text, Borders border, String name, Frame frame, Rect area) {
  final block = Block(
    borders: border,
  ).titleTop(Line('Borders::$name'));

  final inner = block.inner(area);

  frame
    ..renderWidget(block, area)
    ..renderWidget(text, inner);
}

void renderBorderType(Text text, BorderType borderType, String name, Frame frame, Rect area) {
  final block = Block(
    borders: Borders.all,
    borderType: borderType,
  ).titleTop(Line('BorderType::$name'));

  final inner = block.inner(area);

  frame
    ..renderWidget(block, area)
    ..renderWidget(text, inner);
}

void renderStyledBlock(Text text, Frame frame, Rect area) {
  final block = Block(
    borders: Borders.all,
    style: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
  ).titleTop(Line('Styled block'));

  final inner = block.inner(area);

  frame
    ..renderWidget(block, area)
    ..renderWidget(text, inner);
}

void renderStyledBorder(Text text, Frame frame, Rect area) {
  final block = Block(
    borders: Borders.all,
    borderStyle: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
  ).titleTop(Line('Styled borders'));

  final inner = block.inner(area);

  frame
    ..renderWidget(block, area)
    ..renderWidget(text, inner);
}

void renderStyledTitle(Text text, Frame frame, Rect area) {
  final block = Block(
    borders: Borders.all,
    titlesStyle: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
  ).titleTop(Line('Styled title'));

  final inner = block.inner(area);

  frame
    ..renderWidget(block, area)
    ..renderWidget(text, inner);
}

void renderStyledTitleContent(Text text, Frame frame, Rect area) {
  final title = Line.fromSpans([
    Span(
      'Styled ',
      style: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
    ),
    Span(
      'title content',
      style: Style(fg: Color.red, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
    ),
  ]);

  final block = const Block(borders: Borders.all).titleTop(title);

  final inner = block.inner(area);

  frame
    ..renderWidget(block, area)
    ..renderWidget(text, inner);
}

void renderMultipleTitles(Text text, Frame frame, Rect area) {
  final block = const Block(borders: Borders.all)
      .titleTop(
        Line(
          'Multiple',
          style: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
        ),
      )
      .titleTop(
        Line(
          'Titles',
          style: Style(fg: Color.red, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
        ),
      );

  final inner = block.inner(area);

  frame
    ..renderWidget(block, area)
    ..renderWidget(text, inner);
}

void renderMultipleTitlePositions(Text text, Frame frame, Rect area) {
  final block = const Block(borders: Borders.all)
      .titleTop(Line('top left', alignment: Alignment.left))
      .titleTop(Line('top center', alignment: Alignment.center))
      .titleTop(Line('top right', alignment: Alignment.right))
      .titleBottom(Line('bottom left', alignment: Alignment.left))
      .titleBottom(Line('bottom center', alignment: Alignment.center))
      .titleBottom(Line('bottom right', alignment: Alignment.right));

  final inner = block.inner(area);

  frame
    ..renderWidget(block, area)
    ..renderWidget(text, inner);
}

void renderPadding(Text text, Frame frame, Rect area) {
  final block = const Block(
    borders: Borders.all,
    padding: EdgeInsets(left: 5, right: 10, top: 1, bottom: 2),
  ).titleTop(Line('Padding'));

  final inner = block.inner(area);

  frame
    ..renderWidget(block, area)
    ..renderWidget(text, inner);
}

void renderNestedBlocks(Text text, Frame frame, Rect area) {
  final outerBlock = const Block(borders: Borders.all).titleTop(Line('Outer block'));
  final innerBlock = const Block(borders: Borders.all).titleTop(Line('Inner block'));

  final inner = outerBlock.inner(area);

  frame
    ..renderWidget(outerBlock, area)
    ..renderWidget(innerBlock, inner);
}
