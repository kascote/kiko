import 'package:kiko/kiko.dart';

void main() async {
  await Application(title: 'Kiko Example').runStateless(
    update: (_, msg, _) => switch (msg) {
      KeyMsg(key: 'q') => (null, const Quit()),
      _ => (null, null),
    },
    view: (_, frame) {
      final greeting = Line.fromTexts(const [
        Text('Hello, ', style: Style(fg: Color.red)),
        Text(
          'World',
          style: Style(fg: Color.black, bg: Color.yellow),
        ),
        Text('!', style: Style(bg: Color.blue)),
      ]);

      final ui = Column(
        children: [
          ConstrainedBox(
            additionalConstraints: const BoxConstraints(minW: 20, maxW: 20),
            child: Container(
              border: BorderType.rounded,
              topTitles: [Line('Kiko', style: const Style(fg: Color.green))],
              child: greeting,
            ),
          ),
          const Expanded(child: SizedBox()),
        ],
      );

      frame.render(ui);
    },
  );
}
