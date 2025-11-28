import 'dart:io';

import 'package:kiko/kiko.dart';

void main() async {
  final term = await init();
  term.draw((frame) {
    final lines = [
      const Span(
        content: 'Hello, ',
        style: Style(fg: Color.red),
      ),
      const Span(
        content: 'World',
        style: Style(fg: Color.black, bg: Color.yellow),
      ),
      const Span(
        content: '!',
        style: Style(bg: Color.blue),
      ),
    ];
    frame
      ..renderWidget(
        Text.fromLines([Line.fromSpans(lines)]),
        Rect.create(x: 30, y: 10, width: 13, height: 4),
      )
      ..renderWidget(
        Block(borders: Borders.all, borderType: BorderType.rounded)..titleTop(
          Line(
            content: 'Kiko',
            style: const Style(fg: Color.green),
            alignment: Alignment.left,
          ),
        ),
        Rect.create(x: 0, y: 0, width: 20, height: 30),
      );
  });
  sleep(const Duration(seconds: 4));
  await dispose();
}
