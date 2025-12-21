import 'package:kiko/kiko.dart';

void main() async {
  await Application(title: 'Kiko Example (Declarative)').runStateless(
    update: (_, msg) => switch (msg) {
      KeyMsg(key: 'q') => (null, const Quit()),
      _ => (null, null),
    },
    view: (_, frame) {
      final ui = Column(
        children: [
          Fixed(
            10,
            child: Row(
              children: [
                Fixed(
                  20,
                  child:
                      Block(
                        borders: Borders.all,
                        borderType: BorderType.rounded,
                        child: Text.fromLines([
                          Line.fromSpans(const [
                            Span('Hello, ', style: Style(fg: Color.red)),
                            Span(
                              'World',
                              style: Style(fg: Color.black, bg: Color.yellow),
                            ),
                            Span('!', style: Style(bg: Color.blue)),
                          ]),
                        ]),
                      ).titleTop(
                        Line(
                          'Kiko',
                          style: const Style(fg: Color.green),
                          alignment: Alignment.left,
                        ),
                      ),
                ),
                Expanded(child: EmptyWidget()),
              ],
            ),
          ),
          Expanded(child: EmptyWidget()),
        ],
      );

      frame.renderWidget(ui, frame.area);
    },
  );
}

/// Empty widget for filling space.
class EmptyWidget implements Widget {
  @override
  void render(Rect area, Frame frame) {}
}
