import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;

void main() async {
  await Application(title: 'Kiko Example').runStateless(
    update: (_, msg) => switch (msg) {
      KeyMsg(key: 'q') => (null, const Quit()),
      _ => (null, null),
    },
    view: (_, frame) {
      final greeting = Line.fromSpans(const [
        Span('Hello, ', style: Style(fg: Color.red)),
        Span(
          'World',
          style: Style(fg: Color.black, bg: Color.yellow),
        ),
        Span('!', style: Style(bg: Color.blue)),
      ]);

      final ui = plume.Column<PaintToken>(
        children: [
          plume.ConstrainedBox<PaintToken>(
            additionalConstraints: const plume.BoxConstraints(minW: 20, maxW: 20),
            child: box(
              border: BorderType.rounded,
              topTitles: [Line('Kiko', style: const Style(fg: Color.green))],
              child: lineNode(greeting),
            ),
          ),
          plume.Expanded<PaintToken>(child: plume.SizedBox<PaintToken>()),
        ],
      );

      frame.renderNode(ui);
    },
  );
}
