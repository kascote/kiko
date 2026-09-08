import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

import '../../example/theme_viewer/main.dart' as viewer;

/// A frame over a fresh in-memory buffer, ready to render into.
Frame _testFrame(int width, int height) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  return Frame(buffer.area, buffer, 0);
}

/// The buffer as a string: one line per row, trailing blanks trimmed.
String _screenText(Buffer buffer) {
  final out = StringBuffer();
  final area = buffer.area;
  for (var y = area.top; y < area.bottom; y++) {
    final row = StringBuffer();
    for (var x = area.left; x < area.right; x++) {
      final cell = buffer[(x: x, y: y)];
      if (cell.skip) continue;
      row.write(cell.symbol.isEmpty ? ' ' : cell.symbol);
    }
    out.writeln(row.toString().trimRight());
  }
  return out.toString();
}

// The theme viewer example, rendered headlessly: it is the canonical example
// for the theming doctrine, so its first frame is where the lift-or-fallback
// rule (a cursor lifting a selected row's fill instead of replacing it)
// shows on a real app screen, not just in a resolver unit test.
void main() {
  test(
    "the gallery list's first row starts selected under the cursor, as the selection fill lifted once",
    () {
      final model = viewer.Model();
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 160, height: 50));
      final frame = Frame(buffer.area, buffer, 0);
      viewer.view(model, frame);

      // The list tags its own rect with the model id, so the row's cells
      // come straight from the hit map rather than hard-coded coordinates.
      final rect = frame.hits.rectOf(model.list.id);
      expect(rect, isNotNull, reason: 'the list paints under its own id');
      final cell = buffer[(x: rect!.x, y: rect.y)];

      expect(cell.fg, equals(Theme.dark.selection.on));
      expect(cell.bg, equals(Theme.dark.selection.color!.lighten(Theme.stateLift)));
      // The list starts unfocused — the name field holds focus first — so
      // the cursor paints in the wash class and adds no bold. Bold marks a
      // collection that owns focus.
      expect(cell.modifier.has(Modifier.bold), isFalse);
    },
  );

  test('the starting frame shows the checked mark, a selected table row under the crosshair, and the crosshair', () {
    final model = viewer.Model();
    final frame = _testFrame(160, 50);
    viewer.view(model, frame);
    final buffer = frame.buffer;

    final box = frame.hits.rectOf(model.agree.id);
    expect(box, isNotNull, reason: 'the checkbox paints under its own id');
    expect(buffer[(x: box!.x + 1, y: box.y)].symbol, 'x', reason: 'seeded checked, so the mark shows');

    expect(model.table.getSelectedKeys(), equals({'R001'}));
    final table = frame.hits.rectOf(model.table.id);
    expect(table, isNotNull, reason: 'the table paints under its own id');
    // The header takes the first row; the selected row sits under the
    // cursor, so the crosshair's row wash lifts the selection fill.
    final selected = buffer[(x: table!.x + 1, y: table.y + 1)];
    expect(selected.fg, equals(Theme.dark.selection.on));
    expect(selected.bg, equals(Theme.dark.selection.color!.lighten(Theme.stateLift)));
    // The cursor column runs down every row: a bare row below the cursor
    // carries the cursor wash in that column.
    expect(buffer[(x: table.x + 1, y: table.y + 2)].bg, equals(Theme.dark.cursor.color));
  });

  test('F4 cycles the header through the three pages', () {
    final model = viewer.Model();
    var frame = _testFrame(160, 50);
    viewer.view(model, frame);
    final ctx = UpdateContext(hits: frame.hits, area: frame.area);

    viewer.update(model, const KeyMsg('f4'), ctx);
    frame = _testFrame(160, 50);
    viewer.view(model, frame);
    expect(_screenText(frame.buffer), contains('Page 3/3: Contrast'));

    viewer.update(model, const KeyMsg('f4'), ctx);
    frame = _testFrame(160, 50);
    viewer.view(model, frame);
    expect(_screenText(frame.buffer), contains('Page 1/3: Reference'));

    viewer.update(model, const KeyMsg('f4'), ctx);
    frame = _testFrame(160, 50);
    viewer.view(model, frame);
    expect(_screenText(frame.buffer), contains('Page 2/3: Gallery'));
  });

  test('the state strip paints each chip as one resolve call over its ground', () {
    final model = viewer.Model();
    final frame = _testFrame(160, 50);
    viewer.view(model, frame);
    final buffer = frame.buffer;
    final resolver = StyleResolver(Theme.dark, policy: RenderPolicy.color);

    // "selected + cursor" resolves to the same fill on both grounds: the fill
    // row's base is bare, so the resolved style carries its own fg and bg and
    // never falls back to the ground underneath it. The chip proves the
    // resolve call, not the ground.
    final selCurRect = frame.hits.rectOf('strip/bg/fill/sel+cur');
    expect(selCurRect, isNotNull, reason: 'the sel+cur chip paints under its own tag');
    final selCurCell = buffer[(x: selCurRect!.x + 1, y: selCurRect.y)];
    final selCurStyle = resolver.resolve(
      null,
      const {WidgetState.selected, WidgetState.cursor},
      cls: PaintClass.fill,
    );
    expect(selCurCell.fg, equals(selCurStyle.fg));
    expect(selCurCell.bg, equals(selCurStyle.bg));
    expect(selCurCell.modifier.has(Modifier.bold), isTrue, reason: 'the cursor adds bold in the fill class');

    // "rest" resolves to an untouched, bare style, so its cell shows whatever
    // ground the group painted underneath it — the one chip where the two
    // groups differ.
    final bgRestRect = frame.hits.rectOf('strip/bg/fill/rest');
    final sfRestRect = frame.hits.rectOf('strip/sf/fill/rest');
    expect(bgRestRect, isNotNull, reason: "the background group's rest chip paints under its own tag");
    expect(sfRestRect, isNotNull, reason: "the surface group's rest chip paints under its own tag");
    final bgRestBg = buffer[(x: bgRestRect!.x + 1, y: bgRestRect.y)].bg;
    final sfRestBg = buffer[(x: sfRestRect!.x + 1, y: sfRestRect.y)].bg;
    expect(bgRestBg, equals(Theme.dark.background.color));
    expect(sfRestBg, equals(Theme.dark.surface.color));
    expect(bgRestBg, isNot(equals(sfRestBg)));

    // "cur" on the surface row lifts nothing — its base is bare — so its bg
    // is the cursor fill's own color, landing on the surface row.
    final sfCurRect = frame.hits.rectOf('strip/sf/fill/cur');
    expect(sfCurRect, isNotNull, reason: "the surface group's cur chip paints under its own tag");
    final sfCurBg = buffer[(x: sfCurRect!.x + 1, y: sfCurRect.y)].bg;
    expect(sfCurBg, equals(Theme.dark.cursor.color));

    // A wash keeps the ground's own text: the "sel" wash chip sets only a
    // background, so its fg still reads back as the background row's own
    // default text.
    final washSelRect = frame.hits.rectOf('strip/bg/wash/sel');
    expect(washSelRect, isNotNull, reason: "the wash row's sel chip paints under its own tag");
    final washSelCell = buffer[(x: washSelRect!.x + 1, y: washSelRect.y)];
    expect(washSelCell.bg, equals(Theme.dark.selection.color));
    expect(washSelCell.fg, equals(Theme.dark.background.on));
  });

  test('the state strip also paints on the reference page', () {
    final model = viewer.Model();
    var frame = _testFrame(160, 50);
    viewer.view(model, frame);
    final ctx = UpdateContext(hits: frame.hits, area: frame.area);

    // Two F4 presses land on page 1, following the same cycle the header
    // test walks: gallery, contrast, reference.
    viewer.update(model, const KeyMsg('f4'), ctx);
    viewer.update(model, const KeyMsg('f4'), ctx);
    frame = _testFrame(160, 50);
    viewer.view(model, frame);
    expect(_screenText(frame.buffer), contains('Page 1/3: Reference'));
    expect(
      frame.hits.rectOf('strip/bg/fill/rest'),
      isNotNull,
      reason: 'the reference page carries the same state strip as the gallery',
    );
  });

  test('the state strip renders without throwing under ANSI-16 and NO_COLOR', () {
    for (final policy in [RenderPolicy.ansi16, RenderPolicy.noColor]) {
      final model = viewer.Model()..policy = policy;
      final frame = _testFrame(160, 50);
      expect(() => viewer.view(model, frame), returnsNormally, reason: 'policy: $policy');
      expect(
        frame.hits.rectOf('strip/bg/fill/rest'),
        isNotNull,
        reason: 'the rest chip still paints under policy: $policy',
      );
    }
  });
}
