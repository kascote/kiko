import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:termparser/termparser_events.dart' as evt;

Future<void> main() async {
  final term = await init();
  term
    ..enableRawMode()
    ..hideCursor();
  await runLoop(term);
  stderr.writeln('layoutCache ${layoutCacheStats()}');
  term.showCursor();
  await dispose();
}

Future<void> runLoop(Terminal term) async {
  while (true) {
    term.draw(draw);
    final key = await term.readEvent<evt.KeyEvent>();
    if (key is evt.KeyEvent) {
      if (key.code.char == 'q') break;
    }
  }
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
          const [ConstraintPercentage(50), ConstraintPercentage(50)],
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
  )..titleTop(Line(content: 'Borders::$name'));

  final inner = block.inner(area);

  frame
    ..renderWidget(block, area)
    ..renderWidget(text, inner);
}

void renderBorderType(Text text, BorderType borderType, String name, Frame frame, Rect area) {
  final block = Block(
    borders: Borders.all,
    borderType: borderType,
  )..titleTop(Line(content: 'BorderType::$name'));

  final inner = block.inner(area);

  frame
    ..renderWidget(block, area)
    ..renderWidget(text, inner);
}

void renderStyledBlock(Text text, Frame frame, Rect area) {
  final block = Block(
    borders: Borders.all,
    style: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
  )..titleTop(Line(content: 'Styled block'));

  final inner = block.inner(area);

  frame
    ..renderWidget(block, area)
    ..renderWidget(text, inner);
}

void renderStyledBorder(Text text, Frame frame, Rect area) {
  final block = Block(
    borders: Borders.all,
    borderStyle: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
  )..titleTop(Line(content: 'Styled borders'));

  final inner = block.inner(area);

  frame
    ..renderWidget(block, area)
    ..renderWidget(text, inner);
}

void renderStyledTitle(Text text, Frame frame, Rect area) {
  final block = Block(
    borders: Borders.all,
    titlesStyle: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
  )..titleTop(Line(content: 'Styled title'));

  final inner = block.inner(area);

  frame
    ..renderWidget(block, area)
    ..renderWidget(text, inner);
}

void renderStyledTitleContent(Text text, Frame frame, Rect area) {
  final title = Line.fromSpans([
    Span(
      content: 'Styled ',
      style: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
    ),
    Span(
      content: 'title content',
      style: Style(fg: Color.red, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
    ),
  ]);

  final block = Block(
    borders: Borders.all,
  )..titleTop(title);

  final inner = block.inner(area);

  frame
    ..renderWidget(block, area)
    ..renderWidget(text, inner);
}

void renderMultipleTitles(Text text, Frame frame, Rect area) {
  final block =
      Block(
          borders: Borders.all,
        )
        ..titleTop(
          Line(
            content: 'Multiple',
            style: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
          ),
        )
        ..titleTop(
          Line(
            content: 'Titles',
            style: Style(fg: Color.red, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
          ),
        );

  final inner = block.inner(area);

  frame
    ..renderWidget(block, area)
    ..renderWidget(text, inner);
}

void renderMultipleTitlePositions(Text text, Frame frame, Rect area) {
  final block =
      Block(
          borders: Borders.all,
        )
        ..titleTop(Line(content: 'top left', alignment: Alignment.left))
        ..titleTop(Line(content: 'top center', alignment: Alignment.center))
        ..titleTop(Line(content: 'top right', alignment: Alignment.right))
        ..titleBottom(Line(content: 'bottom left', alignment: Alignment.left))
        ..titleBottom(
          Line(content: 'bottom center', alignment: Alignment.center),
        )
        ..titleBottom(
          Line(content: 'bottom right', alignment: Alignment.right),
        );

  final inner = block.inner(area);

  frame
    ..renderWidget(block, area)
    ..renderWidget(text, inner);
}

void renderPadding(Text text, Frame frame, Rect area) {
  final block = Block(
    borders: Borders.all,
    padding: const Padding(left: 5, right: 10, top: 1, bottom: 2),
  )..titleTop(Line(content: 'Padding'));

  final inner = block.inner(area);

  frame
    ..renderWidget(block, area)
    ..renderWidget(text, inner);
}

void renderNestedBlocks(Text text, Frame frame, Rect area) {
  final outerBlock = Block(
    borders: Borders.all,
  )..titleTop(Line(content: 'Outer block'));
  final innerBlock = Block(
    borders: Borders.all,
  )..titleTop(Line(content: 'Inner block'));

  final inner = outerBlock.inner(area);

  frame
    ..renderWidget(outerBlock, area)
    ..renderWidget(innerBlock, inner);
}
