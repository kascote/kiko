import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

const Theme _theme = Theme.dark;

Frame _frame(int width, int height) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  return Frame(buffer.area, buffer, 0);
}

/// Renders [view] one row tall, the way an app composing a [Combobox] must —
/// exactly like a bare `TextInput`, it fills whatever height it is given, so
/// a taller frame needs the same `Column` + `ConstrainedBox` bound a caller
/// uses for any other single-line field.
void _renderRow(Frame frame, View view) => frame.render(
  Column(
    children: [ConstrainedBox(additionalConstraints: const BoxConstraints(minH: 1, maxH: 1), child: view)],
  ),
);

/// A routed button-down addressed to [targetId], on no marked part.
PointerMsg _pressOn(String targetId) =>
    PointerMsg(global: Position.origin, action: PointerAction.down, local: Position.origin, targetId: targetId);

ComboboxModel<String> _fruitBox({
  List<String> options = const ['Apple', 'Banana', 'Cherry', 'Date'],
  String? value,
  bool focused = true,
  int maxVisibleRows = 3,
}) => ComboboxModel<String>(
  id: 'combo',
  fieldId: 'field',
  toggleId: 'toggle',
  label: (s) => s,
  options: options,
  value: value,
  focused: focused,
  maxVisibleRows: maxVisibleRows,
);

String _cellAt(Buffer buffer, int x, int y) {
  final cell = buffer[(x: x, y: y)];
  return cell.symbol.isEmpty ? ' ' : cell.symbol;
}

String _rowText(Buffer buffer, int y, int left, int width) {
  final b = StringBuffer();
  for (var x = left; x < left + width; x++) {
    b.write(_cellAt(buffer, x, y));
  }
  return b.toString();
}

void main() {
  group('Combobox.build (base row)', () {
    test('the field and toggle each tag their own path under the scope', () {
      final combo = _fruitBox(value: 'Banana');
      final frame = _frame(10, 1)..render(Combobox(model: combo, theme: _theme));

      expect(frame.hits.rectOf('combo/field'), Rect.create(x: 0, y: 0, width: 9, height: 1));
      expect(frame.hits.rectOf('combo/toggle'), Rect.create(x: 9, y: 0, width: 1, height: 1));
    });

    test('shows the closed glyph, then the open one', () {
      final combo = _fruitBox();
      final closed = _frame(10, 1)..render(Combobox(model: combo, theme: _theme));
      expect(_cellAt(closed.buffer, 9, 0), '▾');

      combo.update(_pressOn('combo/toggle'));

      final open = _frame(10, 1)..render(Combobox(model: combo, theme: _theme));
      expect(_cellAt(open.buffer, 9, 0), '▴');
    });

    test('the field shows the committed label', () {
      final combo = _fruitBox(value: 'Banana');
      final frame = _frame(10, 1)..render(Combobox(model: combo, theme: _theme));

      expect(_rowText(frame.buffer, 0, 0, 6), 'Banana');
    });
  });

  group('Combobox.renderPopup', () {
    test('paints nothing while closed', () {
      final combo = _fruitBox();
      final frame = _frame(10, 6);
      _renderRow(frame, Combobox(model: combo, theme: _theme));

      Combobox(model: combo, theme: _theme).renderPopup(frame);

      expect(combo.placement, isNull);
      expect(
        frame.hits.hitId(0, 2),
        isNull,
        reason: 'nothing painted below the closed row — no popup, no scope',
      );
    });

    test('anchors below the field, at the union width of field and toggle', () {
      final combo = _fruitBox()..update(_pressOn('combo/toggle'));
      final view = Combobox(model: combo, theme: _theme);
      final frame = _frame(10, 6);
      _renderRow(frame, view);

      view.renderPopup(frame);

      expect(combo.placement, isNotNull);
      expect(combo.placement!.side, PopupSide.below);
      // Field is 9 wide at x=0, toggle 1 wide at x=9: the union spans the
      // full row, x=0..10, starting one row below the field.
      final listPath = 'combo/${combo.internalList.id}';
      expect(frame.hits.hitId(0, 1), listPath);
      expect(frame.hits.hitId(9, 1), listPath);
    });

    test('shows a row per match, painted through the default item builder', () {
      final combo = _fruitBox(options: const ['Apple', 'Banana'])..update(_pressOn('combo/toggle'));
      final view = Combobox(model: combo, theme: _theme);
      final frame = _frame(10, 6);
      _renderRow(frame, view);

      view.renderPopup(frame);

      expect(_rowText(frame.buffer, 1, 0, 5), 'Apple');
      expect(_rowText(frame.buffer, 2, 0, 6), 'Banana');
    });

    test('a custom itemBuilder paints instead of the default', () {
      final combo = _fruitBox(options: const ['Apple'])..update(_pressOn('combo/toggle'));
      final view = Combobox(
        model: combo,
        theme: _theme,
        itemBuilder: (item, index, state) => [Line('* $item')],
      );
      final frame = _frame(10, 6);
      _renderRow(frame, view);

      view.renderPopup(frame);

      expect(_rowText(frame.buffer, 1, 0, 7), '* Apple');
    });

    test('rows below the matches are styled fill, not transparent, and resolve to the bare scope', () {
      final combo = _fruitBox(options: const ['Apple'])..update(_pressOn('combo/toggle'));
      final view = Combobox(model: combo, theme: _theme);
      final frame = _frame(10, 6);
      _renderRow(frame, view);

      view.renderPopup(frame);

      // One match paints row 1; rows 2 and 3 are the blank popup tail.
      final blankCell = frame.buffer[(x: 0, y: 2)];
      expect(blankCell.bg, isNot(Color.reset), reason: 'the blank tail must be a styled fill, not transparent cells');
      expect(frame.hits.hitId(0, 2), 'combo', reason: 'a blank popup row resolves to the bare scope path');
      expect(frame.hits.rectOf('combo'), isNull, reason: 'a scope has no single rect');
    });

    test('an empty result shows the placeholder', () {
      final combo = _fruitBox()
        ..update(_pressOn('combo/toggle'))
        ..update(const KeyMsg('z', text: 'z')); // matches nothing

      final view = Combobox(model: combo, theme: _theme, emptyPlaceholder: Line('No matches'));
      final frame = _frame(12, 6);
      _renderRow(frame, view);

      view.renderPopup(frame);

      expect(_rowText(frame.buffer, 1, 0, 10), 'No matches');
    });

    test('the placement is held across paints while open, and cleared on close', () {
      final combo = _fruitBox()..update(_pressOn('combo/toggle'));
      final view = Combobox(model: combo, theme: _theme);

      final first = _frame(10, 6);
      _renderRow(first, view);
      view.renderPopup(first);
      final decided = combo.placement;
      expect(decided, isNotNull);

      final second = _frame(10, 6);
      _renderRow(second, view);
      view.renderPopup(second);
      expect(combo.placement, decided, reason: 'the same open session keeps its decided placement');

      combo.close();
      expect(combo.placement, isNull);
    });
  });
}
