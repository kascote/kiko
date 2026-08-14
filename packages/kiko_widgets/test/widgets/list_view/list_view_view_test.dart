import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

const _ctx = plume.LayoutContext(measurer: plume.MonospaceMeasurer());

Frame _frame(int width, int height) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  return Frame(buffer.area, buffer, 0);
}

String _dump(Buffer buffer) {
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

ListViewModel<String, String> _list(List<String> items) => ListViewModel<String, String>(items: items, focused: true);

List<Line> _row(String item, int index, ItemState state) => [Line(item)];

void main() {
  group('list view render', () {
    test('draws the visible items inside a bordered box', () {
      final node = Container(
        border: BorderType.plain,
        child: ListView<String, String>(
          model: _list(<String>['Apple', 'Banana', 'Cherry']),
          theme: Theme.dark,
          itemBuilder: _row,
        ),
      );
      final frame = _frame(12, 5)..render(node);

      expect(_dump(frame.buffer), '''
┌──────────┐
│Apple     │
│Banana    │
│Cherry    │
└──────────┘
''');
    });

    test('windows the rows to the scroll offset', () {
      final model = _list(<String>['a', 'b', 'c', 'd', 'e']);
      final node = ListView<String, String>(model: model, theme: Theme.dark, itemBuilder: _row);

      // First frame fixes the visible count (3 rows) the model scrolls against.
      expect(_dump((_frame(5, 3)..render(node)).buffer), 'a\nb\nc\n');

      // Move the cursor to the end; the window slides down.
      for (var i = 0; i < 4; i++) {
        model.update(const KeyMsg('down'));
      }
      expect(_dump((_frame(5, 3)..render(node)).buffer), 'c\nd\ne\n');
    });

    test('shows the empty placeholder when there are no items', () {
      final node = ListView<String, String>(
        model: _list(<String>[]),
        theme: Theme.dark,
        itemBuilder: _row,
        emptyPlaceholder: Line('(empty)'),
      );
      expect(_dump((_frame(9, 1)..render(node)).buffer), '(empty)\n');
    });

    test('paints real row content through a RecordingSurface, not a hole', () {
      // The row body used to gate on `surface is BufferSurface`, so a golden
      // taken through plume's own RecordingSurface saw a border and nothing
      // else. Rows now paint through the plume Surface protocol directly, so
      // the focused row's fill and its text both land here too.
      final node =
          ListView<String, String>(model: _list(<String>['Apple']), theme: Theme.dark, itemBuilder: _row).build()
            ..layout(plume.BoxConstraints.tight(const plume.Size(5, 1)), _ctx)
            ..place(plume.Offset.zero);
      final surface = plume.RecordingSurface<PaintToken>();
      node.paint(surface);

      final intents = surface.intents.map((i) => '$i').toList();
      expect(intents, hasLength(2));
      expect(intents[0], startsWith('fillRect('));
      expect(intents[1], 'drawText(0, 0, "Apple", ${const PaintToken(Style())})');
    });
  });

  group('placeholders and the older run', () {
    // Width 5 makes the skeleton run (5 * 3) ~/ 4 = 3 cells wide.
    ListViewModel<String, String> paged() => ListViewModel<String, String>(
      id: 'list',
      items: const ['a', 'b', 'c'],
      totalCount: 9,
      pageSize: 3,
      focused: true,
    );

    test('an item whose page is not held paints as a dim run', () {
      final model = ListViewModel<String, String>(totalCount: 4, focused: true);
      final node = ListView<String, String>(model: model, theme: Theme.dark, itemBuilder: _row);

      expect(_dump((_frame(5, 4)..render(node)).buffer), '░░░\n░░░\n░░░\n░░░\n');
    });

    test('a wheel scroll into a page on its way paints the nearest held run', () {
      final model = paged();
      final node = ListView<String, String>(model: model, theme: Theme.dark, itemBuilder: _row);

      // First frame fixes the visible count (3 rows) the model scrolls against.
      _frame(5, 3).render(node);
      // One notch lands the viewport fully on page 1, which is now in flight.
      model.update(const PointerMsg(global: Position.origin, action: PointerAction.wheelDown, local: Position.origin));
      expect(model.scrollOffset, equals(3));
      expect(model.viewportStatus, SliceStatus.filling);

      // The cursor (0) is off screen, so the held run stands in — while the
      // reported scroll state keeps saying where the viewport really is.
      expect(_dump((_frame(5, 3)..render(node)).buffer), 'a\nb\nc\n');
      expect(model.getScrollState().offset, equals(3));
    });

    test('cursor navigation into a page on its way paints the true position', () {
      final model = paged();
      final node = ListView<String, String>(model: model, theme: Theme.dark, itemBuilder: _row);

      _frame(5, 3).render(node);
      for (var i = 0; i < 3; i++) {
        model.update(const KeyMsg('down'));
      }
      expect(model.cursor, equals(3));
      expect(model.viewportStatus, SliceStatus.filling);

      // The cursor is on screen, so no older run may contradict it: the held
      // rows paint where they are and the missing row paints as a run — marked
      // with its real index, so a click on it addresses the row it appears to be.
      final frame = _frame(5, 3)..render(node);
      expect(_dump(frame.buffer), 'b\nc\n░░░\n');
      expect(frame.hits.regionAt('list', 0, 2), const RowRegion(3));
    });

    test('missing rows with nothing coming paint the true position, not an older run', () {
      final model = paged();
      final node = ListView<String, String>(model: model, theme: Theme.dark, itemBuilder: _row);

      _frame(5, 3).render(node);
      // Move the viewport without running a demand pass: page 1 is missing and
      // nothing is on its way, so the stall must show itself.
      model.scrollBy(3);
      expect(model.viewportStatus, SliceStatus.stalled);

      expect(_dump((_frame(5, 3)..render(node)).buffer), '░░░\n░░░\n░░░\n');
    });
  });

  group('list view under a partial clip (viewport)', () {
    test('anchors content at the placement rect, not the clip sub-rect', () {
      // Simulates a Viewport ancestor showing only rows 2-4 of a list placed at
      // (0, 0) with height 5: content must be computed against the full
      // placement (row 2 lands at screen row 2, matching where layout put it),
      // not re-anchored at the clip's origin — that would pin item0 to the top
      // of the visible window instead of scrolling it off.
      final model = _list(<String>['item0', 'item1', 'item2', 'item3', 'item4']);
      final node = ListView<String, String>(model: model, theme: Theme.dark, itemBuilder: _row).build()
        ..layout(plume.BoxConstraints.tight(const plume.Size(5, 5)), _ctx)
        ..place(plume.Offset.zero);

      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 5, height: 5));
      final surface = BufferSurface(buffer)..pushClip(const plume.Rect(0, 2, 5, 3));
      node.paint(surface);
      surface.popClip();

      // Rows scrolled above the clip are absent, not shown squeezed at the top.
      expect(_dump(buffer), '\n\nitem2\nitem3\nitem4\n');
    });
  });

  group('list view click routing', () {
    test('a click in the list resolves to its id', () {
      final model = ListViewModel<String, String>(
        id: 'menu',
        items: const ['a', 'b'],
        focused: true,
      );
      final frame = _frame(5, 2)..render(ListView<String, String>(model: model, theme: Theme.dark, itemBuilder: _row));

      expect(frame.hits.hitId(0, 0), 'menu');
      expect(frame.hits.hitId(2, 1), 'menu');
    });
  });

  group('hit regions (task 0254)', () {
    // A two-line item list with a separator between items — the shape of
    // example/list_view_multiselect.dart, where the old scrollOffset + local.y
    // mapping put a click on the second item onto the fourth. Layout on an 9×9
    // frame: item 0 rows y0-1, separator y2, item 1 rows y3-4, separator y5,
    // item 2 rows y6-7, blank tail y8.
    HitMap regionsFor(List<String> items) {
      final model = ListViewModel<String, String>(
        id: 'list',
        items: items,
        itemHeight: 2,
        focused: true,
      );
      final node = ListView<String, String>(
        model: model,
        theme: Theme.dark,
        itemBuilder: (item, index, state) => [Line(item), Line('$item.2')],
        separatorBuilder: () => Line('---'),
      );
      return (_frame(9, 9)..render(node)).hits;
    }

    test('every line of a two-line item resolves to that item', () {
      final hits = regionsFor(['a', 'b', 'c']);

      expect(hits.regionAt('list', 0, 0), const RowRegion(0));
      expect(hits.regionAt('list', 4, 1), const RowRegion(0), reason: "item 0's second line is still item 0");
      expect(hits.regionAt('list', 0, 3), const RowRegion(1));
      expect(hits.regionAt('list', 8, 4), const RowRegion(1), reason: "item 1's second line is still item 1");
      expect(hits.regionAt('list', 0, 6), const RowRegion(2));
      expect(hits.regionAt('list', 0, 7), const RowRegion(2));
    });

    test('a separator and the blank tail are marked by nobody', () {
      final hits = regionsFor(['a', 'b', 'c']);

      expect(hits.regionAt('list', 0, 2), isNull, reason: 'the separator between items 0 and 1');
      expect(hits.regionAt('list', 0, 5), isNull, reason: 'the separator between items 1 and 2');
      expect(hits.regionAt('list', 0, 8), isNull, reason: 'the blank tail below the last item');
    });
  });
}
