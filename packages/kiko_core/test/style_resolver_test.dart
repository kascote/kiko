import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  const theme = Theme.dark;
  const resolver = StyleResolver(theme);

  group('StyleResolver / basics', () {
    test('empty states returns base unchanged', () {
      const base = Style(fg: Color.red, bg: Color.blue);
      final result = resolver.resolve(base, {});
      expect(result, base);
    });

    test('null base with no states is an empty style', () {
      expect(resolver.resolve(null, {}), const Style());
    });

    test('null base with a state starts from empty', () {
      final result = resolver.resolve(null, {WidgetState.selected});
      expect(result.fg, theme.selection.on);
      expect(result.bg, theme.selection.color);
    });
  });

  group('StyleResolver / state x class matrix', () {
    const base = Style(fg: Color.white, bg: Color.rgb(0x808080));

    test('hover: wash only', () {
      expect(resolver.resolve(base, {WidgetState.hover}, cls: PaintClass.ink), base);
      expect(resolver.resolve(base, {WidgetState.hover}), base);
      final wash = resolver.resolve(base, {WidgetState.hover}, cls: PaintClass.wash);
      expect(wash.bg, theme.hover.color);
      expect(wash.fg, base.fg); // wash never touches fg
    });

    test('selected: all three classes', () {
      final ink = resolver.resolve(base, {WidgetState.selected}, cls: PaintClass.ink);
      expect(ink.fg, theme.selection.color);
      expect(ink.bg, base.bg); // ink never sets bg

      final fill = resolver.resolve(base, {WidgetState.selected});
      expect(fill.fg, theme.selection.on);
      expect(fill.bg, theme.selection.color);

      final wash = resolver.resolve(base, {WidgetState.selected}, cls: PaintClass.wash);
      expect(wash.bg, theme.selection.color);
      expect(wash.fg, base.fg);
    });

    test('cursor: fill (+bold) and wash, nothing for ink', () {
      expect(resolver.resolve(base, {WidgetState.cursor}, cls: PaintClass.ink), base);

      final fill = resolver.resolve(base, {WidgetState.cursor});
      expect(fill.fg, theme.cursor.on);
      expect(fill.bg, theme.cursor.color);
      expect(fill.addModifier.has(Modifier.bold), isTrue);

      final wash = resolver.resolve(base, {WidgetState.cursor}, cls: PaintClass.wash);
      expect(wash.bg, theme.cursor.color);
    });

    test('focused: ink and fill both bold, nothing for wash', () {
      final ink = resolver.resolve(base, {WidgetState.focused}, cls: PaintClass.ink);
      expect(ink.fg, theme.focus.color);
      expect(ink.bg, base.bg);
      expect(ink.addModifier.has(Modifier.bold), isTrue);

      final fill = resolver.resolve(base, {WidgetState.focused});
      expect(fill.fg, theme.focus.on);
      expect(fill.bg, theme.focus.color);
      expect(fill.addModifier.has(Modifier.bold), isTrue);

      expect(resolver.resolve(base, {WidgetState.focused}, cls: PaintClass.wash), base);
    });

    test('unfocused: muted ink, and muted fg over surface wash for fill', () {
      final ink = resolver.resolve(base, {WidgetState.unfocused}, cls: PaintClass.ink);
      expect(ink.fg, theme.muted.color);
      expect(ink.bg, base.bg);

      final fill = resolver.resolve(base, {WidgetState.unfocused});
      expect(fill.fg, theme.muted.color);
      expect(fill.bg, theme.surface.color);

      expect(resolver.resolve(base, {WidgetState.unfocused}, cls: PaintClass.wash), base);
    });

    test('loading: warning ink + slowBlink for ink and fill', () {
      for (final cls in [PaintClass.ink, PaintClass.fill]) {
        final r = resolver.resolve(base, {WidgetState.loading}, cls: cls);
        expect(r.fg, theme.warning.color, reason: '$cls');
        expect(r.bg, base.bg, reason: '$cls'); // ink-shaped: no bg
        expect(r.addModifier.has(Modifier.slowBlink), isTrue, reason: '$cls');
      }
      expect(resolver.resolve(base, {WidgetState.loading}, cls: PaintClass.wash), base);
    });

    test('error: all three classes', () {
      final ink = resolver.resolve(base, {WidgetState.error}, cls: PaintClass.ink);
      expect(ink.fg, theme.error.color);
      expect(ink.bg, base.bg);

      final fill = resolver.resolve(base, {WidgetState.error});
      expect(fill.fg, theme.error.on);
      expect(fill.bg, theme.error.color);

      final wash = resolver.resolve(base, {WidgetState.error}, cls: PaintClass.wash);
      expect(wash.bg, theme.error.color);
    });

    test('disabled: disabled ink + dim for ink and fill, nothing for wash', () {
      for (final cls in [PaintClass.ink, PaintClass.fill]) {
        final r = resolver.resolve(base, {WidgetState.disabled}, cls: cls);
        expect(r.fg, theme.disabled.color, reason: '$cls');
        expect(r.bg, base.bg, reason: '$cls');
        expect(r.addModifier.has(Modifier.dim), isTrue, reason: '$cls');
      }
      expect(resolver.resolve(base, {WidgetState.disabled}, cls: PaintClass.wash), base);
    });
  });

  group('StyleResolver / priority order', () {
    const base = Style(fg: Color.white, bg: Color.rgb(0x808080));

    test('disabled overrides focused', () {
      final result = resolver.resolve(base, {WidgetState.focused, WidgetState.disabled});
      expect(result.fg, theme.disabled.color);
      expect(result.addModifier.has(Modifier.dim), isTrue);
    });

    test('cursor shows through selected (cursor applied last)', () {
      final result = resolver.resolve(base, {WidgetState.selected, WidgetState.cursor});
      expect(result.fg, theme.cursor.on);
      expect(result.bg, theme.cursor.color);
    });

    test('error patches over selected without clearing its bg', () {
      final result = resolver.resolve(base, {WidgetState.selected, WidgetState.error});
      // error (fill) sets its own fg/bg, applied after selected.
      expect(result.fg, theme.error.on);
      expect(result.bg, theme.error.color);
    });

    test('hover and focused touch disjoint classes — fill matches focus-only', () {
      final both = resolver.resolve(base, {WidgetState.hover, WidgetState.focused});
      final focusOnly = resolver.resolve(base, {WidgetState.focused});
      expect(both, focusOnly);
    });
  });

  group('StyleResolver / overrides', () {
    const base = Style(fg: Color.white);

    test('an override replaces the default for a state', () {
      const custom = Style(fg: Color.green, bg: Color.yellow);
      final result = resolver.resolve(
        base,
        {WidgetState.focused},
        overrides: {WidgetState.focused: custom},
      );
      expect(result.fg, Color.green);
      expect(result.bg, Color.yellow);
    });

    test('an override applies even where the matrix cell is empty', () {
      const custom = Style(bg: Color.blue);
      final result = resolver.resolve(
        base,
        {WidgetState.cursor},
        cls: PaintClass.ink, // cursor x ink is normally empty
        overrides: {WidgetState.cursor: custom},
      );
      expect(result.bg, Color.blue);
    });
  });

  group('StyleResolver / border helper', () {
    test('resting border is border.ink', () {
      final result = resolver.border({});
      expect(result.fg, theme.border.color);
      expect(result.bg, isNull);
    });

    test('focused border tints the fg but never a bg', () {
      final result = resolver.border({WidgetState.focused});
      expect(result.fg, theme.focus.color);
      expect(result.bg, isNull);
      expect(result.addModifier.has(Modifier.bold), isTrue);
    });

    test('selected border is a fg-only tint (F1 is gone)', () {
      final result = resolver.border({WidgetState.selected});
      expect(result.fg, theme.selection.color);
      expect(result.bg, isNull);
    });
  });
}
