import 'package:kiko/kiko.dart';

void main() async {
  await Application(title: 'Kiko Example').runStateless(
    update: (_, msg) => switch (msg) {
      KeyMsg(key: 'q') => (null, const Quit()),
      _ => (null, null),
    },
    view: (_, frame) {
      final lines = [
        const Span('Hello, ', style: Style(fg: Color.red)),
        const Span(
          'World',
          style: Style(fg: Color.black, bg: Color.yellow),
        ),
        const Span('!', style: Style(bg: Color.blue)),
      ];
      frame
        ..renderWidget(
          Text.fromLines([Line.fromSpans(lines)]),
          Rect.create(x: 30, y: 10, width: 13, height: 4),
        )
        ..renderWidget(
          const Block(borders: Borders.all, borderType: BorderType.rounded).titleTop(
            Line(
              'Kiko',
              style: const Style(fg: Color.green),
              alignment: Alignment.left,
            ),
          ),
          Rect.create(x: 0, y: 0, width: 20, height: 30),
        );
    },
  );
}
