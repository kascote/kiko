import 'dart:io';

import 'package:kiko/kiko.dart';

void main() async {
  final term = await init();
  term.draw((frame) {
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
                          Span(
                            content: 'Hello, ',
                            style: Style(fg: Color.red),
                          ),
                          Span(
                            content: 'World',
                            style: Style(fg: Color.black, bg: Color.yellow),
                          ),
                          Span(
                            content: '!',
                            style: Style(bg: Color.blue),
                          ),
                        ]),
                      ]),
                    ).titleTop(
                      Line(
                        content: 'Kiko',
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
  });
  sleep(const Duration(seconds: 4));
  await dispose();
}

/// Empty widget for filling space.
class EmptyWidget implements Widget {
  @override
  void render(Rect area, Frame frame) {}
}
