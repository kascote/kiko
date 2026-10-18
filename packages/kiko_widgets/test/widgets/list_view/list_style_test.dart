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
      resolver: StyleResolver(theme),
      style: style,
      itemBuilder: (item, index, state) => [Line(item)],
    ),
  );
  return buffer;
}

/// [color] moved [amount] of OKLab lightness away from [theme]'s background:
/// lighter on a dark ground, darker on a light one.
Color _lifted(Theme theme, Color color, double amount) {
  final dark = theme.background.color!.toOklab().l < 0.5;
  return color.shiftLightness(dark ? amount : -amount);
}

ListViewModel<String, String> _list(
  List<String> items, {
  bool multiSelect = false,
  bool Function(int index)? isDisabled,
  bool focused = true,
}) => ListViewModel<String, String>(
  items: items,
  focused: focused,
  multiSelect: multiSelect,
  isDisabled: isDisabled,
);

void main() {
  group('ListView anatomy styling', () {
    test('the cursor row lifts the ground one state step and turns bold', () {
      final model = _list(<String>['Apple', 'Banana', 'Cherry']);
      final buffer = _render(model);

      final cursorCell = buffer[(x: 7, y: 0)]; // trailing fill-only cell, cursor row
      expect(cursorCell.bg, equals(_lifted(Theme.dark, Theme.dark.background.color!, Theme.step)));
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

    test('a selected row under the cursor keeps the selection fg and lifts its bg, bold', () {
      // Row 0 is both selected and the cursor: the cursor lifts the
      // selection fill instead of replacing it, so the fact stays visible.
      final model = _list(<String>['Apple', 'Banana'], multiSelect: true)..update(const KeyMsg('space'));
      final buffer = _render(model);

      final cell = buffer[(x: 7, y: 0)];
      expect(cell.fg, equals(Theme.dark.selection.on));
      expect(cell.bg, equals(_lifted(Theme.dark, Theme.dark.selection.color!, Theme.step)));
      expect(cell.modifier.has(Modifier.bold), isTrue);
    });

    test('a hovered row lifts the ground half a state step', () {
      // Hover row 1, away from the cursor at row 0, so only the hover wash paints.
      final model = _list(<String>['Apple', 'Banana', 'Cherry'])..hoverRow = 1;
      final buffer = _render(model);

      final hoverCell = buffer[(x: 7, y: 1)];
      expect(hoverCell.bg, equals(_lifted(Theme.dark, Theme.dark.background.color!, Theme.step / 2)));
    });

    test('hover lifts a cursor row', () {
      // Row 0 is both hovered and the cursor; hover applies last, half a
      // step over the cursor step, lifting it rather than hiding it.
      final model = _list(<String>['Apple', 'Banana'])..hoverRow = 0;
      final buffer = _render(model);

      final cell = buffer[(x: 7, y: 0)];
      final cursorStep = _lifted(Theme.dark, Theme.dark.background.color!, Theme.step);
      expect(cell.bg, equals(_lifted(Theme.dark, cursorStep, Theme.step / 2)));
    });

    test('a disabled row dims', () {
      final model = _list(<String>['Apple', 'Banana'], isDisabled: (i) => i == 1);
      final buffer = _render(model);

      final disabledCell = buffer[(x: 7, y: 1)];
      expect(disabledCell.modifier.has(Modifier.dim), isTrue);
    });

    test('a disabled row shows the same ink with and without the unfocused cursor on it', () {
      const shipped = [
        Theme.dark,
        Theme.catppuccin,
        Theme.rosePine,
        Theme.gruvbox,
        Theme.monokai,
        Theme.nord,
        Theme.tokyoNight,
        Theme.oneDark,
        Theme.dracula,
        Theme.solarized,
      ];
      for (final theme in shipped) {
        final offCursor = _list(<String>['Apple', 'Banana'], isDisabled: (i) => i == 1)..focused = false;
        final underCursor = _list(<String>['Apple', 'Banana'], isDisabled: (i) => i == 1)
          ..moveCursorTo(1)
          ..focused = false;

        final off = _render(offCursor, theme: theme)[(x: 7, y: 1)];
        final under = _render(underCursor, theme: theme)[(x: 7, y: 1)];
        expect(off.fg, equals(theme.disabled.color), reason: theme.name);
        expect(under.fg, equals(off.fg), reason: '${theme.name}: the cursor wash changed the disabled ink');
        expect(
          under.bg,
          equals(_lifted(theme, theme.background.color!, Theme.step)),
          reason: '${theme.name}: the cursor wash marks the row in full',
        );
      }
    });

    test('a disabled row under the focused cursor keeps the cursor bar and takes the disabled ink', () {
      final model = _list(<String>['Apple', 'Banana'], isDisabled: (i) => i == 1)..moveCursorTo(1);
      final buffer = _render(model);

      final cell = buffer[(x: 7, y: 1)];
      expect(cell.bg, equals(_lifted(Theme.dark, Theme.dark.background.color!, Theme.step)));
      expect(cell.fg, equals(Theme.dark.disabled.color));
      expect(cell.modifier.has(Modifier.dim), isTrue);
    });

    test('a disabled selected row blends both colors toward the ground, dim', () {
      // Toggling selection on a disabled row is refused, so row 1 is
      // selected first, then marked disabled for painting — leaving it
      // selected, disabled, and off the cursor.
      final disabledRows = <int>{};
      final model =
          _list(
              <String>['Apple', 'Banana', 'Cherry'],
              multiSelect: true,
              isDisabled: disabledRows.contains,
            )
            ..update(const KeyMsg('down'))
            ..update(const KeyMsg('space'))
            ..update(const KeyMsg('down'));
      disabledRows.add(1);
      final buffer = _render(model);

      final ground = Theme.dark.background.color!;
      final cell = buffer[(x: 7, y: 1)];
      expect(cell.fg, equals(Theme.dark.selection.on.mix(ground, Theme.disabledMix)));
      expect(cell.bg, equals(Theme.dark.selection.color!.mix(ground, Theme.disabledMix)));
      expect(cell.modifier.has(Modifier.dim), isTrue);
    });

    test('an explicit cursorItem style paints verbatim, plus the focused bold', () {
      const override = Style(fg: Color.green, bg: Color.blue);
      final model = _list(<String>['Apple', 'Banana']);
      final buffer = _render(model, style: const ListViewStyle(cursorItem: override));

      final cell = buffer[(x: 7, y: 0)];
      expect(cell.bg, equals(Color.blue));
      expect(cell.fg, equals(Color.green));
      // The slot replaces the cursor step; the focused layer still adds bold.
      expect(cell.modifier.has(Modifier.bold), isTrue);
    });

    test('an explicit cursorItem style replaces the cursor step on a selected cursor row', () {
      const override = Style(fg: Color.green, bg: Color.blue);
      final model = _list(<String>['Apple', 'Banana'], multiSelect: true)..update(const KeyMsg('space'));
      final buffer = _render(model, style: const ListViewStyle(cursorItem: override));

      final cell = buffer[(x: 7, y: 0)];
      expect(cell.fg, equals(Color.green));
      expect(cell.bg, equals(Color.blue));
      expect(cell.modifier.has(Modifier.bold), isTrue);
    });

    test('an unfocused list lifts the cursor on a plain row, no bold', () {
      final model = _list(<String>['Apple', 'Banana'], focused: false);
      final buffer = _render(model);

      final cell = buffer[(x: 7, y: 0)];
      expect(cell.bg, equals(_lifted(Theme.dark, Theme.dark.background.color!, Theme.step)));
      expect(cell.modifier.has(Modifier.bold), isFalse);
    });

    test('an unfocused list lifts the cursor on a selected row, no bold', () {
      // Select and leave the cursor on row 0 while focused, then blur: the
      // model keeps its selection and cursor position across the flip.
      final model = _list(<String>['Apple', 'Banana'], multiSelect: true)
        ..update(const KeyMsg('space'))
        ..focused = false;
      final buffer = _render(model);

      final cell = buffer[(x: 7, y: 0)];
      expect(cell.fg, equals(Theme.dark.selection.on));
      expect(cell.bg, equals(_lifted(Theme.dark, Theme.dark.selection.color!, Theme.step)));
      expect(cell.modifier.has(Modifier.bold), isFalse);
    });

    test('the empty placeholder derives the muted ink', () {
      final model = _list(<String>[]);
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 8, height: 3));
      Frame(buffer.area, buffer, 0).render(
        ListView<String, String>(
          model: model,
          resolver: StyleResolver(Theme.dark),
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
      final gruvboxBuffer = _render(model, theme: Theme.gruvbox, style: styleFor(Theme.gruvbox));
      expect(gruvboxBuffer[(x: 0, y: 0)].bg, equals(Theme.gruvbox.success.color));
    });
  });
}
