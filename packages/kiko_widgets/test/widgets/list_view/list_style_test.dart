import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// Renders [model] into a fresh buffer so tests can inspect cell fg/bg/modifier
/// directly (glyph layout is `list_view_view_test.dart`'s job). The list is
/// [width] wide so trailing cells past the short item text are fill-only — a
/// reliable place to read the row's resolved background.
Buffer _render(
  ListViewModel<String, String> model, {
  int width = 8,
  int height = 3,
  Theme theme = Theme.dark,
  ListViewStyle style = const ListViewStyle(),
}) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  Frame(buffer.area, buffer, 0).render(
    ListView<String, String>(
      model: model,
      theme: theme,
      style: style,
      itemBuilder: (item, index, state) => [Line(item)],
    ),
  );
  return buffer;
}

ListViewModel<String, String> _list(
  List<String> items, {
  bool multiSelect = false,
  bool Function(int index)? isDisabled,
}) => ListViewModel<String, String>(
  items: items,
  focused: true,
  multiSelect: multiSelect,
  isDisabled: isDisabled,
);

void main() {
  group('ListView anatomy styling', () {
    test('the cursor row paints the cursor tone, not the focus tone (F2)', () {
      // The regression guard: the current item is WidgetState.cursor, so it
      // must derive from the cursor tone — never the focus tone the old code
      // borrowed for "the current row".
      final model = _list(<String>['Apple', 'Banana', 'Cherry']);
      final buffer = _render(model);

      final cursorCell = buffer[(x: 7, y: 0)]; // trailing fill-only cell, cursor row
      expect(cursorCell.bg, equals(Theme.dark.cursor.color));
      expect(cursorCell.bg, isNot(equals(Theme.dark.focus.color)));
      expect(cursorCell.modifier.has(Modifier.bold), isTrue);
    });

    test('a non-cursor row is left unfilled', () {
      final model = _list(<String>['Apple', 'Banana', 'Cherry']);
      final buffer = _render(model);

      final plainCell = buffer[(x: 7, y: 1)];
      expect(plainCell.bg, equals(Color.reset));
    });

    test('a selected row derives the selection fill', () {
      // Select row 1 (toggle acts at the cursor), then move the cursor off it,
      // so row 1 shows the selection fill alone — not the cursor over it.
      final model = _list(<String>['Apple', 'Banana', 'Cherry'], multiSelect: true)
        ..update(const KeyMsg('down'))
        ..update(const KeyMsg('space'))
        ..update(const KeyMsg('down'));
      final buffer = _render(model);

      final selectedCell = buffer[(x: 7, y: 1)];
      expect(selectedCell.bg, equals(Theme.dark.selection.color));
      expect(selectedCell.fg, equals(Theme.dark.selection.on));
    });

    test('the cursor stays visible over a selected run', () {
      // Row 0 is both selected and the cursor; the cursor fill (patched last)
      // must win over the selection fill.
      final model = _list(<String>['Apple', 'Banana'], multiSelect: true)..update(const KeyMsg('space'));
      final buffer = _render(model);

      final cell = buffer[(x: 7, y: 0)];
      expect(cell.bg, equals(Theme.dark.cursor.color));
    });

    test('a hovered row derives the hover wash', () {
      // Hover row 1, away from the cursor at row 0, so only the hover wash paints.
      final model = _list(<String>['Apple', 'Banana', 'Cherry'])..hoverRow = 1;
      final buffer = _render(model);

      final hoverCell = buffer[(x: 7, y: 1)];
      expect(hoverCell.bg, equals(Theme.dark.hover.color));
    });

    test('hover is the weakest state: a hovered cursor row still reads cursor', () {
      // Row 0 is both hovered and the cursor; the cursor fill (patched after the
      // hover wash) must win.
      final model = _list(<String>['Apple', 'Banana'])..hoverRow = 0;
      final buffer = _render(model);

      final cell = buffer[(x: 7, y: 0)];
      expect(cell.bg, equals(Theme.dark.cursor.color), reason: 'the cursor fill wins over the hover wash');
    });

    test('a disabled row dims', () {
      final model = _list(<String>['Apple', 'Banana'], isDisabled: (i) => i == 1);
      final buffer = _render(model);

      final disabledCell = buffer[(x: 7, y: 1)];
      expect(disabledCell.modifier.has(Modifier.dim), isTrue);
    });

    test('an explicit cursorItem style wins outright over the derivation', () {
      const override = Style(fg: Color.green, bg: Color.blue);
      final model = _list(<String>['Apple', 'Banana']);
      final buffer = _render(model, style: const ListViewStyle(cursorItem: override));

      final cell = buffer[(x: 7, y: 0)];
      expect(cell.bg, equals(Color.blue));
      expect(cell.fg, equals(Color.green));
      // Derivation's bold is not applied when the slot is overridden.
      expect(cell.modifier.has(Modifier.bold), isFalse);
    });

    test('the empty placeholder derives the muted ink', () {
      final model = _list(<String>[]);
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 8, height: 3));
      Frame(buffer.area, buffer, 0).render(
        ListView<String, String>(
          model: model,
          theme: Theme.dark,
          itemBuilder: (item, index, state) => [Line(item)],
          emptyPlaceholder: Line('none'),
        ),
      );

      // Placeholder text 'none' painted at x=0 with the derived muted fg.
      expect(buffer[(x: 0, y: 0)].fg, equals(Theme.dark.muted.color));
    });

    test('a style built from the theme in view never goes stale after a theme switch', () {
      ListViewStyle styleFor(Theme theme) {
        final resolver = StyleResolver(theme);
        return ListViewStyle(selectedItem: resolver.fill(resolver.tones.success));
      }

      // Select row 0, then move the cursor away, so the selected row is not
      // also the cursor row — the cursor fill would otherwise patch over it.
      final model = _list(<String>['Apple', 'Banana'], multiSelect: true)
        ..update(const KeyMsg('space'))
        ..update(const KeyMsg('down'));

      final darkBuffer = _render(model, style: styleFor(Theme.dark));
      expect(darkBuffer[(x: 0, y: 0)].bg, equals(Theme.dark.success.color));

      // Same model, rebuilt style, second theme: the view carries no state of
      // its own, so the new frame reflects the new theme with nothing to reset.
      final lightBuffer = _render(model, theme: Theme.light, style: styleFor(Theme.light));
      expect(lightBuffer[(x: 0, y: 0)].bg, equals(Theme.light.success.color));
    });
  });
}
