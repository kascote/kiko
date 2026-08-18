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

ComboboxModel<String> _remoteBox({
  String? value,
  bool focused = true,
  int maxVisibleRows = 3,
}) => ComboboxModel<String>(
  id: 'combo',
  fieldId: 'field',
  toggleId: 'toggle',
  label: (s) => s,
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

  group('Combobox.renderPopup (status rows)', () {
    test('shows a loading row after the standing matches while the newest query is in flight', () {
      final combo = _remoteBox()
        ..update(_pressOn('combo/toggle')) // asks QueryKey('')
        ..applyLoad(const LoadResult<List<String>>('combo', key: QueryKey(''), data: ['Apple', 'Banana']))
        ..update(const KeyMsg('c', text: 'c')); // asks QueryKey('c'); the matches above stand while it loads

      final view = Combobox(model: combo, theme: _theme);
      final frame = _frame(12, 6);
      _renderRow(frame, view);
      view.renderPopup(frame);

      expect(_rowText(frame.buffer, 1, 0, 5), 'Apple');
      expect(_rowText(frame.buffer, 2, 0, 6), 'Banana');
      expect(_rowText(frame.buffer, 3, 0, 8), 'Loading…', reason: 'the status row paints after the matches');
    });

    test('a status row takes the last row when the matches would otherwise fill the popup', () {
      final combo = _remoteBox(maxVisibleRows: 2)
        ..update(_pressOn('combo/toggle'))
        ..applyLoad(const LoadResult<List<String>>('combo', key: QueryKey(''), data: ['Apple', 'Banana']))
        ..update(const KeyMsg('c', text: 'c')); // asks QueryKey('c'); 2 matches stand, popup only fits 2 rows

      final view = Combobox(model: combo, theme: _theme);
      final frame = _frame(12, 6);
      _renderRow(frame, view);
      view.renderPopup(frame);

      expect(
        _rowText(frame.buffer, 1, 0, 5),
        'Apple',
        reason: 'one fewer match shows, to leave room for the status row',
      );
      expect(_rowText(frame.buffer, 2, 0, 8), 'Loading…', reason: "the status row takes the popup's last row");
    });

    test('shows an error row after the newest query fails, styled through ComboboxStyle.errorRow', () {
      const errorStyle = Style(fg: Color.indexed(9));
      final combo = _remoteBox()
        ..styles = const ComboboxStyle(errorRow: errorStyle)
        ..update(_pressOn('combo/toggle'))
        ..applyLoad(const LoadResult<List<String>>('combo', key: QueryKey(''), data: ['Apple']))
        ..update(const KeyMsg('z', text: 'z')) // asks QueryKey('z')
        ..applyLoad(const LoadResult<List<String>>('combo', key: QueryKey('z'), error: 'boom'));

      final view = Combobox(model: combo, theme: _theme);
      final frame = _frame(16, 6);
      _renderRow(frame, view);
      view.renderPopup(frame);

      expect(_rowText(frame.buffer, 1, 0, 5), 'Apple', reason: 'the prior options still stand after a failed query');
      expect(_rowText(frame.buffer, 2, 0, 14), 'Failed to load');
      expect(frame.buffer[(x: 0, y: 2)].fg, errorStyle.fg);
    });

    test('the loading row disappears once the newest query installs', () {
      final combo = _remoteBox()..update(_pressOn('combo/toggle')); // asks QueryKey(''), no answer yet
      final view = Combobox(model: combo, theme: _theme);

      final loading = _frame(12, 6);
      _renderRow(loading, view);
      view.renderPopup(loading);
      expect(_rowText(loading.buffer, 1, 0, 8), 'Loading…', reason: 'no options yet, and the query is in flight');

      combo.applyLoad(const LoadResult<List<String>>('combo', key: QueryKey(''), data: ['Apple']));

      final installed = _frame(12, 6);
      _renderRow(installed, view);
      view.renderPopup(installed);
      expect(_rowText(installed.buffer, 1, 0, 5), 'Apple');
      expect(
        installed.hits.hitId(0, 2),
        'combo',
        reason: 'the loading row is gone; the row below the match is back to the blank scope tail',
      );
    });

    test('the status row is painted chrome, not a list row: it resolves to the bare scope path', () {
      final combo = _remoteBox()..update(_pressOn('combo/toggle')); // asks QueryKey(''), still loading
      final view = Combobox(model: combo, theme: _theme);
      final frame = _frame(12, 6);
      _renderRow(frame, view);
      view.renderPopup(frame);

      expect(_rowText(frame.buffer, 1, 0, 8), 'Loading…');
      expect(frame.hits.hitId(0, 1), 'combo', reason: 'the status row is chrome, never part of the embedded list');
    });

    test('a local (non-remote) combobox never shows a status row', () {
      final combo = _fruitBox(options: const ['Apple'])..update(_pressOn('combo/toggle'));
      final view = Combobox(model: combo, theme: _theme);
      final frame = _frame(12, 6);
      _renderRow(frame, view);
      view.renderPopup(frame);

      expect(_rowText(frame.buffer, 2, 0, 8).trim(), isEmpty);
    });
  });
}
