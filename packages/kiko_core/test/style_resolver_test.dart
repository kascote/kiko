import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  const theme = Theme.dark;
  final resolver = StyleResolver(theme);

  group('StyleResolver / basics', () {
    test('empty states returns base unchanged', () {
      const base = Style(fg: Color.red, bg: Color.blue);
      final result = resolver.resolve(base, {}, cls: PaintClass.fill);
      expect(result, base);
    });

    test('null base with no states is an empty style', () {
      expect(resolver.resolve(null, {}, cls: PaintClass.fill), const Style());
    });

    test('null base with a state starts from empty', () {
      final result = resolver.resolve(null, {WidgetState.selected}, cls: PaintClass.fill);
      expect(result.fg, theme.selection.on);
      expect(result.bg, theme.selection.color);
    });
  });

  group('StyleResolver / state x class matrix', () {
    const base = Style(fg: Color.white, bg: Color.rgb(0x808080));

    test('hover lifts a background toward the ground, not toward the color itself', () {
      // Theme.dark's ground is dark, so hover lightens here even though the
      // base color's own luminance (0x808080) sits past the midpoint that
      // Color.lift would have darkened by.
      final lifted = base.bg!.lighten(Theme.hoverLift);
      for (final cls in PaintClass.values) {
        final result = resolver.resolve(base, {WidgetState.hover}, cls: cls);
        expect(result.bg, lifted, reason: '$cls');
        expect(result.fg, base.fg, reason: '$cls');
      }
    });

    test('hover washes a base with no background', () {
      const noBg = Style(fg: Color.white);
      final result = resolver.resolve(noBg, {WidgetState.hover}, cls: PaintClass.fill);
      expect(result.bg, theme.hover.color);
      expect(result.fg, noBg.fg);
    });

    test('selected: all three classes', () {
      final ink = resolver.resolve(base, {WidgetState.selected}, cls: PaintClass.ink);
      expect(ink.fg, theme.selection.color);
      expect(ink.bg, base.bg); // ink never sets bg

      final fill = resolver.resolve(base, {WidgetState.selected}, cls: PaintClass.fill);
      expect(fill.fg, theme.selection.on);
      expect(fill.bg, theme.selection.color);

      final wash = resolver.resolve(base, {WidgetState.selected}, cls: PaintClass.wash);
      expect(wash.bg, theme.selection.color);
      expect(wash.fg, base.fg);
    });

    test('cursor on a colored base lifts it instead of replacing it, nothing for ink', () {
      expect(resolver.resolve(base, {WidgetState.cursor}, cls: PaintClass.ink), base);

      final fill = resolver.resolve(base, {WidgetState.cursor}, cls: PaintClass.fill);
      expect(fill.fg, base.fg);
      expect(fill.bg, base.bg!.lighten(Theme.stateLift));
      expect(fill.addModifier.has(Modifier.bold), isTrue);

      final wash = resolver.resolve(base, {WidgetState.cursor}, cls: PaintClass.wash);
      expect(wash.fg, base.fg);
      expect(wash.bg, base.bg!.lighten(Theme.stateLift));
      expect(wash.addModifier.has(Modifier.bold), isFalse);
    });

    test('cursor on a bare base is the cursor fill (+bold) and wash, unchanged', () {
      const bare = Style(fg: Color.white);

      final fill = resolver.resolve(bare, {WidgetState.cursor}, cls: PaintClass.fill);
      expect(fill.fg, theme.cursor.on);
      expect(fill.bg, theme.cursor.color);
      expect(fill.addModifier.has(Modifier.bold), isTrue);

      final wash = resolver.resolve(bare, {WidgetState.cursor}, cls: PaintClass.wash);
      expect(wash.bg, theme.cursor.color);
      expect(wash.addModifier.has(Modifier.bold), isFalse);
    });

    test('focused on a colored base lifts it instead of replacing it; ink still tints', () {
      final ink = resolver.resolve(base, {WidgetState.focused}, cls: PaintClass.ink);
      expect(ink.fg, theme.focus.color);
      expect(ink.bg, base.bg);
      expect(ink.addModifier.has(Modifier.bold), isTrue);

      final fill = resolver.resolve(base, {WidgetState.focused}, cls: PaintClass.fill);
      expect(fill.fg, base.fg);
      expect(fill.bg, base.bg!.lighten(Theme.stateLift));
      expect(fill.addModifier.has(Modifier.bold), isTrue);

      expect(resolver.resolve(base, {WidgetState.focused}, cls: PaintClass.wash), base);
    });

    test('focused on a bare base is the focus fill, bold (unchanged)', () {
      const bare = Style(fg: Color.white);
      final fill = resolver.resolve(bare, {WidgetState.focused}, cls: PaintClass.fill);
      expect(fill.fg, theme.focus.on);
      expect(fill.bg, theme.focus.color);
      expect(fill.addModifier.has(Modifier.bold), isTrue);
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

      final fill = resolver.resolve(base, {WidgetState.error}, cls: PaintClass.fill);
      expect(fill.fg, theme.error.on);
      expect(fill.bg, theme.error.color);

      final wash = resolver.resolve(base, {WidgetState.error}, cls: PaintClass.wash);
      expect(wash.bg, theme.error.color);
    });

    test('disabled ink keeps the swap to the disabled tone, plus dim', () {
      final ink = resolver.resolve(base, {WidgetState.disabled}, cls: PaintClass.ink);
      expect(ink.fg, theme.disabled.color);
      expect(ink.bg, base.bg);
      expect(ink.addModifier.has(Modifier.dim), isTrue);
    });

    test('disabled on a filled base mixes both fg and bg toward the ground, plus dim', () {
      final ground = theme.background.color!;
      final fill = resolver.resolve(base, {WidgetState.disabled}, cls: PaintClass.fill);
      expect(fill.fg, base.fg!.mix(ground, Theme.disabledMix));
      expect(fill.bg, base.bg!.mix(ground, Theme.disabledMix));
      expect(fill.addModifier.has(Modifier.dim), isTrue);
    });

    test('disabled does nothing for wash', () {
      expect(resolver.resolve(base, {WidgetState.disabled}, cls: PaintClass.wash), base);
    });

    test('disabled on a bare base swaps in the disabled ink, plus dim (unchanged)', () {
      const bare = Style(fg: Color.white);
      final fill = resolver.resolve(bare, {WidgetState.disabled}, cls: PaintClass.fill);
      expect(fill.fg, theme.disabled.color);
      expect(fill.bg, isNull);
      expect(fill.addModifier.has(Modifier.dim), isTrue);
    });

    test('disabled on a filled base only adds dim when the ground has no color', () {
      final groundless = theme.copyWith(background: const SurfaceTone(on: Color.rgb(0xc9d1d9)));
      final r = StyleResolver(groundless, policy: RenderPolicy.color);
      final fill = r.resolve(base, {WidgetState.disabled}, cls: PaintClass.fill);
      expect(fill.fg, base.fg);
      expect(fill.bg, base.bg);
      expect(fill.addModifier.has(Modifier.dim), isTrue);
    });
  });

  group('StyleResolver / priority order', () {
    const base = Style(fg: Color.white, bg: Color.rgb(0x808080));

    test('cursor over a selected fill keeps the selection fg and lifts its bg, bold', () {
      final result = resolver.resolve(base, {WidgetState.selected, WidgetState.cursor}, cls: PaintClass.fill);
      expect(result.fg, theme.selection.on);
      expect(result.bg, theme.selection.color!.lighten(Theme.stateLift));
      expect(result.addModifier.has(Modifier.bold), isTrue);
    });

    test('cursor in the wash class lifts a selected fill, no bold', () {
      final result = resolver.resolve(base, {WidgetState.selected, WidgetState.cursor}, cls: PaintClass.wash);
      expect(result.bg, theme.selection.color!.lighten(Theme.stateLift));
      expect(result.addModifier.has(Modifier.bold), isFalse);
    });

    test('error patches over selected without clearing its bg', () {
      final result = resolver.resolve(base, {WidgetState.selected, WidgetState.error}, cls: PaintClass.fill);
      // error (fill) sets its own fg/bg, applied after selected.
      expect(result.fg, theme.error.on);
      expect(result.bg, theme.error.color);
    });

    test("hover lifts the focus fill a second step, in the ground's direction", () {
      final focusOnly = resolver.resolve(base, {WidgetState.focused}, cls: PaintClass.fill);
      final both = resolver.resolve(base, {WidgetState.hover, WidgetState.focused}, cls: PaintClass.fill);
      expect(both, focusOnly.copyWith(bg: focusOnly.bg!.lighten(Theme.hoverLift)));
    });

    test("hover lifts a cursor-lifted selection a second step, in the ground's direction", () {
      void expectSecondLift(Theme t, Color Function(Color color, double amount) step) {
        final r = StyleResolver(t, policy: RenderPolicy.color);
        final result = r.resolve(base, {
          WidgetState.selected,
          WidgetState.cursor,
          WidgetState.hover,
        }, cls: PaintClass.fill);
        final expectedBg = step(step(t.selection.color!, Theme.stateLift), Theme.hoverLift);
        expect(result.fg, t.selection.on);
        expect(result.bg, expectedBg);
      }

      // A light ground: the same tones over a near-white base, so the lift
      // runs the other way.
      final light = Theme.dark.copyWith(
        background: const SurfaceTone(color: Color.rgb(0xf6f8fa), on: Color.rgb(0x1f2328)),
        selection: const SurfaceTone(color: Color.rgb(0xddf4ff), on: Color.rgb(0x1f2328)),
      );
      expectSecondLift(Theme.dark, (color, amount) => color.lighten(amount));
      expectSecondLift(light, (color, amount) => color.darken(amount));
    });

    test('hover and pressed leave a disabled result unchanged', () {
      final disabledOnly = resolver.resolve(base, {WidgetState.disabled}, cls: PaintClass.fill);
      final withHover = resolver.resolve(base, {WidgetState.disabled, WidgetState.hover}, cls: PaintClass.fill);
      final withPressed = resolver.resolve(base, {WidgetState.disabled, WidgetState.pressed}, cls: PaintClass.fill);
      final withBoth = resolver.resolve(base, {
        WidgetState.disabled,
        WidgetState.hover,
        WidgetState.pressed,
      }, cls: PaintClass.fill);
      expect(withHover, disabledOnly);
      expect(withPressed, disabledOnly);
      expect(withBoth, disabledOnly);
    });

    test('disabled runs after focused, blending the already-lifted fill', () {
      final ground = theme.background.color!;
      final focusOnly = resolver.resolve(base, {WidgetState.focused}, cls: PaintClass.fill);
      final result = resolver.resolve(base, {WidgetState.focused, WidgetState.disabled}, cls: PaintClass.fill);
      expect(result.fg, focusOnly.fg!.mix(ground, Theme.disabledMix));
      expect(result.bg, focusOnly.bg!.mix(ground, Theme.disabledMix));
      expect(result.addModifier.has(Modifier.dim), isTrue);
    });
  });

  group('StyleResolver / ink class order', () {
    test('error ink wins over focus ink on chrome, focus ink wins over selection ink', () {
      final errorFocused = resolver.resolve(null, {WidgetState.focused, WidgetState.error}, cls: PaintClass.ink);
      expect(errorFocused.fg, theme.error.color);
      expect(errorFocused.addModifier.has(Modifier.bold), isTrue);

      final selectedFocused = resolver.resolve(null, {WidgetState.selected, WidgetState.focused}, cls: PaintClass.ink);
      expect(selectedFocused.fg, theme.focus.color);
      expect(selectedFocused.addModifier.has(Modifier.bold), isTrue);
    });
  });

  group('StyleResolver / slots', () {
    const base = Style(fg: Color.white, bg: Color.rgb(0x808080));
    const slot = Style(fg: Color.green, bg: Color.rgb(0x224422));

    test('a slot for cursor replaces the fallback on a bare base', () {
      const bare = Style(fg: Color.white);
      final result = resolver.resolve(
        bare,
        {WidgetState.cursor},
        cls: PaintClass.fill,
        slots: {WidgetState.cursor: slot},
      );
      expect(result.fg, slot.fg);
      expect(result.bg, slot.bg);
    });

    test('a slot for cursor is ignored on a colored base — the lift still runs', () {
      final result = resolver.resolve(
        base,
        {WidgetState.cursor},
        cls: PaintClass.fill,
        slots: {WidgetState.cursor: slot},
      );
      expect(result.fg, base.fg);
      expect(result.bg, base.bg!.lighten(Theme.stateLift));
    });

    test('a slot for selected replaces the matrix cell', () {
      final result = resolver.resolve(
        base,
        {WidgetState.selected},
        cls: PaintClass.fill,
        slots: {WidgetState.selected: slot},
      );
      expect(result.fg, slot.fg);
      expect(result.bg, slot.bg);
    });

    test('a slot for hover is ignored — only selected, loading, error, cursor and focused read slots', () {
      final withoutSlot = resolver.resolve(base, {WidgetState.hover}, cls: PaintClass.fill);
      final withSlot = resolver.resolve(
        base,
        {WidgetState.hover},
        cls: PaintClass.fill,
        slots: {WidgetState.hover: slot},
      );
      expect(withSlot, withoutSlot);
    });
  });

  group('StyleResolver / bare base rules', () {
    test('an authored base with a Color.reset background is bare', () {
      const resetBase = Style(fg: Color.white, bg: Color.reset);
      final result = resolver.resolve(resetBase, {WidgetState.cursor}, cls: PaintClass.fill);
      expect(result.fg, theme.cursor.on);
      expect(result.bg, theme.cursor.color);
      expect(result.addModifier.has(Modifier.bold), isTrue);
    });
  });

  group('StyleResolver / pressed transform', () {
    const base = Style(fg: Color.white, bg: Color.rgb(0x808080));

    test('pressed inverts a fill', () {
      final result = resolver.resolve(base, {WidgetState.pressed}, cls: PaintClass.fill);
      expect(result, base.inverted);
    });

    test('pressed inverts after tone patches — proves transforms run last', () {
      final focusOnly = resolver.resolve(base, {WidgetState.focused}, cls: PaintClass.fill);
      final result = resolver.resolve(base, {WidgetState.pressed, WidgetState.focused}, cls: PaintClass.fill);
      expect(result, focusOnly.inverted);
    });

    test('hover runs before pressed', () {
      final hoverOnly = resolver.resolve(base, {WidgetState.hover}, cls: PaintClass.fill);
      final result = resolver.resolve(base, {WidgetState.hover, WidgetState.pressed}, cls: PaintClass.fill);
      expect(result, hoverOnly.inverted);
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
    const tone = SurfaceTone(color: Color.rgb(0x336699), on: Color.rgb(0x101010));

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
    const tone = SurfaceTone(color: Color.rgb(0x336699), on: Color.rgb(0x101010));

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
        name: 'transparent',
        primary: SurfaceTone(color: Color.rgb(0x58a6b0), on: Color.rgb(0x0d1117)),
        secondary: SurfaceTone(color: Color.rgb(0x8b7ec8), on: Color.rgb(0x0d1117)),
        accent: SurfaceTone(color: Color.rgb(0xd4976c), on: Color.rgb(0x0d1117)),
        error: SurfaceTone(color: Color.rgb(0xc75d5d), on: Color.rgb(0x0d1117)),
        warning: SurfaceTone(color: Color.rgb(0xc9a857), on: Color.rgb(0x0d1117)),
        success: SurfaceTone(color: Color.rgb(0x6aab73), on: Color.rgb(0x0d1117)),
        background: SurfaceTone(on: Color.rgb(0xc9d1d9)),
        surface: SurfaceTone(color: Color.rgb(0x161b22), on: Color.rgb(0xc9d1d9)),
        border: Tone(color: Color.rgb(0x30363d)),
        muted: Tone(color: Color.rgb(0x6e7681)),
        disabled: Tone(color: Color.rgb(0x484f58)),
        focus: SurfaceTone(color: Color.rgb(0x6bc5d2), on: Color.rgb(0x0d1117)),
        selection: SurfaceTone(color: Color.rgb(0x264a5c), on: Color.rgb(0xc9d1d9)),
        cursor: SurfaceTone(on: Color.rgb(0xc9d1d9)),
        hover: Tone(),
      );
      final r = StyleResolver(transparent, policy: RenderPolicy.color);
      final ground = r.ground(transparent.background);
      expect(ground.fg, transparent.background.on);
      expect(ground.bg, isNull);
    });
  });
}
