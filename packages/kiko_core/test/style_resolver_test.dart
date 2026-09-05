import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  const theme = Theme.dark;
  final resolver = StyleResolver(theme);

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

  group('StyleResolver / tone projections', () {
    const tone = Tone(color: Color.rgb(0x336699), on: Color.rgb(0x101010));

    test('color policy projects the raw tone', () {
      final r = StyleResolver(theme, policy: RenderPolicy.color);
      expect(r.ink(tone).fg, tone.color);
      expect(r.fill(tone).fg, tone.on);
      expect(r.fill(tone).bg, tone.color);
      expect(r.wash(tone).bg, tone.color);
    });

    test('noColor drops ink and wash, re-expresses fill as reversed', () {
      final r = StyleResolver(theme, policy: RenderPolicy.noColor);
      expect(r.ink(tone).fg, isNull);
      expect(r.fill(tone).fg, isNull);
      expect(r.fill(tone).bg, isNull);
      expect(r.fill(tone).addModifier.has(Modifier.reversed), isTrue);
      expect(r.wash(tone).bg, isNull);
    });

    test('ansi16 keeps ink and fill but drops the wash', () {
      final r = StyleResolver(theme, policy: RenderPolicy.ansi16);
      expect(r.ink(tone).fg, tone.color);
      expect(r.fill(tone).fg, tone.on);
      expect(r.fill(tone).bg, tone.color);
      expect(r.wash(tone).bg, isNull);
    });
  });

  group('StyleResolver / ground', () {
    const tone = Tone(color: Color.rgb(0x336699), on: Color.rgb(0x101010));

    test('color policy projects fg and bg, same as fill', () {
      final r = StyleResolver(theme, policy: RenderPolicy.color);
      final ground = r.ground(tone);
      expect(ground.fg, tone.on);
      expect(ground.bg, tone.color);
      expect(ground, r.fill(tone));
    });

    test('ansi16 keeps only the foreground', () {
      final r = StyleResolver(theme, policy: RenderPolicy.ansi16);
      final ground = r.ground(tone);
      expect(ground.fg, tone.on);
      expect(ground.bg, isNull);
    });

    test('noColor drops all color', () {
      final r = StyleResolver(theme, policy: RenderPolicy.noColor);
      expect(r.ground(tone), const Style());
    });

    test('a transparent theme (background.color == null) grounds fg-only', () {
      const transparent = Theme(
        primary: Tone(color: Color.rgb(0x58a6b0), on: Color.rgb(0x0d1117)),
        secondary: Tone(color: Color.rgb(0x8b7ec8), on: Color.rgb(0x0d1117)),
        accent: Tone(color: Color.rgb(0xd4976c), on: Color.rgb(0x0d1117)),
        error: Tone(color: Color.rgb(0xc75d5d), on: Color.rgb(0x0d1117)),
        warning: Tone(color: Color.rgb(0xc9a857), on: Color.rgb(0x0d1117)),
        success: Tone(color: Color.rgb(0x6aab73), on: Color.rgb(0x0d1117)),
        background: Tone(on: Color.rgb(0xc9d1d9)),
        surface: Tone(color: Color.rgb(0x161b22), on: Color.rgb(0xc9d1d9)),
        border: Tone(color: Color.rgb(0x30363d)),
        muted: Tone(color: Color.rgb(0x6e7681)),
        disabled: Tone(color: Color.rgb(0x484f58)),
        focus: Tone(color: Color.rgb(0x6bc5d2), on: Color.rgb(0x0d1117)),
        selection: Tone(color: Color.rgb(0x264a5c), on: Color.rgb(0xc9d1d9)),
        cursor: Tone(on: Color.rgb(0xc9d1d9)),
        hover: Tone(),
      );
      final r = StyleResolver(transparent, policy: RenderPolicy.color);
      final ground = r.ground(transparent.background);
      expect(ground.fg, transparent.background.on);
      expect(ground.bg, isNull);
    });
  });
}
