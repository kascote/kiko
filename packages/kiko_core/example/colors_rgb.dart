import 'package:kiko/kiko.dart';

Future<void> main() async {
  await Application(
    title: 'Colors RGB Example',
  ).runStateless(
    update: (_, msg) => switch (msg) {
      KeyMsg(key: 'q') => (null, const Quit()),
      _ => (null, null),
    },
    view: (_, frame) => frame.renderNode(_ui()),
  );
}

final _fps = _FpsWidget();
final _grid = _ColorGridWidget();

Node _ui() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Row(
      children: [
        Expanded(
          child: lineNode(Line('colors_rgb example, Press q to quit', alignment: Alignment.center)),
        ),
        ConstrainedBox(
          additionalConstraints: const BoxConstraints(minW: 8, maxW: 8),
          child: _fps,
        ),
      ],
    ),
    Expanded(child: _grid),
  ],
);

/// Right-aligned frames-per-second counter, redrawn every frame.
class _FpsWidget extends Node {
  int _frameCount = 0;
  DateTime _lastInstant = DateTime.now();
  double _fps = 0;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) =>
      Size(constraints.biggest.w, constraints.constrainHeight(1));

  @override
  void paintSelf(Surface surface) {
    _frameCount++;
    final now = DateTime.now();
    final elapsed = now.difference(_lastInstant).inSeconds;
    if (elapsed > 1) {
      _fps = _frameCount / elapsed;
      _frameCount = 0;
      _lastInstant = now;
    }
    paintLine(
      surface,
      Line(
        '${_fps}fps',
        alignment: Alignment.right,
        style: const Style(fg: Color.white),
      ),
      x: rect.x,
      y: rect.y,
      width: rect.width,
    );
  }
}

/// A scrolling HSV gradient painted two vertical pixels per cell via the `▀`
/// half-block glyph — one raw `Surface.drawText` call per pixel.
class _ColorGridWidget extends Node {
  List<List<Color>> _colors = [];
  int _frameCount = 0;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) => constraints.biggest;

  void _setupColors(int width, int pixelHeight) {
    if (_colors.length == pixelHeight && (_colors.isEmpty || _colors[0].length == width)) {
      return;
    }
    _colors = List.generate(
      pixelHeight,
      (y) => List.generate(width, (x) {
        final hue = x * 360.0 / width;
        final value = (pixelHeight - y) / pixelHeight;
        const saturation = 1.0;
        return Color.fromHSV(hue, saturation, value);
      }),
    );
  }

  @override
  void paintSelf(Surface surface) {
    if (rect.width <= 0 || rect.height <= 0) return;
    _setupColors(rect.width, rect.height * 2);

    for (var xi = 0; xi < rect.width; xi++) {
      final xii = (xi + _frameCount) % rect.width;
      for (var yi = 0; yi < rect.height; yi++) {
        final fg = _colors[yi * 2][xii];
        final bg = _colors[yi * 2 + 1][xii];
        surface.drawText(rect.x + xi, rect.y + yi, '▀', PaintToken(Style(fg: fg, bg: bg)));
      }
    }
    _frameCount++;
  }
}
