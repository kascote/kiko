import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;

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

plume.RenderNode<PaintToken> _ui() => plume.Column<PaintToken>(
  crossAxisAlignment: plume.CrossAxisAlignment.stretch,
  children: [
    plume.Row<PaintToken>(
      children: [
        plume.Expanded<PaintToken>(
          child: lineNode(Line('colors_rgb example, Press q to quit', alignment: Alignment.center)),
        ),
        plume.ConstrainedBox<PaintToken>(
          additionalConstraints: const plume.BoxConstraints(minW: 8, maxW: 8),
          child: _fps,
        ),
      ],
    ),
    plume.Expanded<PaintToken>(child: _grid),
  ],
);

/// Right-aligned frames-per-second counter, redrawn every frame.
class _FpsWidget extends plume.RenderNode<PaintToken> {
  int _frameCount = 0;
  DateTime _lastInstant = DateTime.now();
  double _fps = 0;

  @override
  plume.Size performLayout(plume.BoxConstraints constraints, plume.LayoutContext context) => constraints.biggest;

  @override
  void paintSelf(plume.Surface<PaintToken> surface) {
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
class _ColorGridWidget extends plume.RenderNode<PaintToken> {
  List<List<Color>> _colors = [];
  int _frameCount = 0;

  @override
  plume.Size performLayout(plume.BoxConstraints constraints, plume.LayoutContext context) => constraints.biggest;

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
  void paintSelf(plume.Surface<PaintToken> surface) {
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
