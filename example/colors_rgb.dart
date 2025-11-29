import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:termparser/termparser_events.dart';

Future<void> main() async {
  final app = App();

  await Application(
    title: 'Colors RGB Example',
    onCleanup: (terminal) async {
      stderr.writeln('layoutCache ${layoutCacheStats()}');
    },
  ).run(
    render: (frame) => frame.renderWidget(app, frame.area),
    onEvent: (event) {
      if (event is KeyEvent && event.code.char == 'q') return 0;
      return null;
    },
  );
}

class App implements Widget {
  final fpsWidget = FpsWidget();
  final colorsWidget = ColorsWidget();

  App();

  @override
  void render(Rect area, Buffer buffer) {
    final [top, colors] = Layout.vertical(const [ConstraintLength(1), ConstraintMin(0)]).areas(area);
    final [title, fps] = Layout.horizontal(const [ConstraintMin(0), ConstraintLength(8)]).areas(top);

    Text.raw(
      'colors_rgb example, Press q to quit',
      alignment: Alignment.center,
    ).render(title, buffer);

    fpsWidget.render(fps, buffer);
    colorsWidget.render(colors, buffer);
  }
}

class FpsWidget implements Widget {
  int frameCount = 0;
  DateTime lastInstant = DateTime.now();
  double fps = 0;

  void calculateFps() {
    frameCount++;
    final now = DateTime.now();
    final elapsed = now.difference(lastInstant).inSeconds;
    if (elapsed > 1) {
      fps = frameCount / elapsed;
      frameCount = 0;
      lastInstant = now;
    }
  }

  @override
  void render(Rect area, Buffer buffer) {
    calculateFps();
    Text.raw(
      '${fps}fps',
      alignment: Alignment.right,
      style: const Style(fg: Color.white),
    ).render(area, buffer);
  }
}

class ColorsWidget implements Widget {
  List<List<Color>> colors = [];
  int frameCount = 0;

  void setupColors(Rect size) {
    final width = size.width;
    final height = size.height * 2;

    if (colors.length == height && colors[0].length == width) {
      return;
    }
    colors = List.generate(height, (y) {
      return List.generate(width, (x) {
        final hue = x * 360.0 / width;
        final value = (height - y) / height;
        const saturation = 1.0;
        return Color.fromHSV(hue, saturation, value);
      });
    });
  }

  @override
  void render(Rect area, Buffer buffer) {
    setupColors(area);

    for (final (xi, x) in enumerate(area.left, area.right)) {
      final xii = (xi + frameCount) % area.width;
      for (final (yi, y) in enumerate(area.top, area.bottom)) {
        final fg = colors[yi * 2][xii];
        final bg = colors[yi * 2 + 1][xii];
        buffer[(x: x, y: y)] = Cell(char: '▀', fg: fg, bg: bg);
      }
    }

    frameCount++;
  }
}

Iterable<(int, int)> enumerate(int from, int to) sync* {
  var index = 0;
  for (var i = from; i < to; i++) {
    yield (index++, i);
  }
}
