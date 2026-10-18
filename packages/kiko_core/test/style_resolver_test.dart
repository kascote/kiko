import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

const List<Theme> _shipped = [
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

/// A light ground with a light selection, so lifts run toward black.
const _light = Theme(
  name: 'light',
  primary: SurfaceTone(color: Color.rgb(0x0969da), on: Color.rgb(0xffffff)),
  secondary: SurfaceTone(color: Color.rgb(0x8250df), on: Color.rgb(0xffffff)),
  accent: SurfaceTone(color: Color.rgb(0xbc4c00), on: Color.rgb(0xffffff)),
  error: SurfaceTone(color: Color.rgb(0xcf222e), on: Color.rgb(0xffffff)),
  warning: SurfaceTone(color: Color.rgb(0x9a6700), on: Color.rgb(0xffffff)),
  success: SurfaceTone(color: Color.rgb(0x1a7f37), on: Color.rgb(0xffffff)),
  background: SurfaceTone(color: Color.rgb(0xf6f8fa), on: Color.rgb(0x1f2328)),
  surface: SurfaceTone(color: Color.rgb(0xeaeef2), on: Color.rgb(0x1f2328)),
  border: Tone(color: Color.rgb(0xd0d7de)),
  muted: Tone(color: Color.rgb(0x57606a)),
  disabled: Tone(color: Color.rgb(0x8c959f)),
  selection: SurfaceTone(color: Color.rgb(0xddf4ff), on: Color.rgb(0x1f2328)),
);

double _l(Color color) => color.toOklab().l;

void main() {
  const theme = Theme.dark;
  final resolver = StyleResolver(theme);
  final ground = theme.background.color!;

  // A colored base well inside the gamut, so a lift never clamps.
  const base = Style(fg: Color.white, bg: Color.rgb(0x808080));

  group('StyleResolver / basics', () {
    test('empty states returns base unchanged', () {
      const own = Style(fg: Color.red, bg: Color.blue);
      expect(resolver.resolve(own, {}, cls: PaintClass.fill), own);
    });

    test('a null base with no states starts from the ground in fill and from nothing elsewhere', () {
      expect(resolver.resolve(null, {}, cls: PaintClass.fill), resolver.ground(theme.background));
      expect(resolver.resolve(null, {}, cls: PaintClass.ink), const Style());
      expect(resolver.resolve(null, {}, cls: PaintClass.wash), const Style());
    });

    test('a null base with a state patches the tone over the ground', () {
      final result = resolver.resolve(null, {WidgetState.selected}, cls: PaintClass.fill);
      expect(result.fg, theme.selection.on);
      expect(result.bg, theme.selection.color);
    });

    test('the default resolver is bound to the background and is not de-emphasised', () {
      expect(resolver.groundTone, same(theme.background));
      expect(resolver.isDeEmphasised, isFalse);
    });

    test('a theme without a background color is rejected', () {
      const colorless = Theme(
        name: 'colorless',
        primary: SurfaceTone(color: Color.cyan, on: Color.black),
        secondary: SurfaceTone(color: Color.magenta, on: Color.black),
        accent: SurfaceTone(color: Color.yellow, on: Color.black),
        error: SurfaceTone(color: Color.red, on: Color.white),
        warning: SurfaceTone(color: Color.yellow, on: Color.black),
        success: SurfaceTone(color: Color.green, on: Color.black),
        background: SurfaceTone(on: Color.white),
        surface: SurfaceTone(color: Color.darkGray, on: Color.white),
        border: Tone(color: Color.gray),
        muted: Tone(color: Color.darkGray),
        disabled: Tone(color: Color.darkGray),
        selection: SurfaceTone(color: Color.yellow, on: Color.black),
      );
      expect(() => StyleResolver(colorless), throwsA(isA<AssertionError>()));
      expect(() => resolver.on(const SurfaceTone(on: Color.white)), throwsA(isA<AssertionError>()));
    });
  });

  group('StyleResolver / state x class matrix', () {
    test('hover lifts a fill or wash background half a step and leaves ink alone', () {
      final lifted = base.bg!.shiftLightness(Theme.step / 2);
      for (final cls in [PaintClass.fill, PaintClass.wash]) {
        final result = resolver.resolve(base, {WidgetState.hover}, cls: cls);
        expect(result.bg, lifted, reason: '$cls');
        expect(result.fg, base.fg, reason: '$cls');
      }
      expect(resolver.resolve(base, {WidgetState.hover}, cls: PaintClass.ink), base);
    });

    test('hover lifts the ground color of a base with no background', () {
      const noBg = Style(fg: Color.white);
      final result = resolver.resolve(noBg, {WidgetState.hover}, cls: PaintClass.fill);
      expect(result.bg, ground.shiftLightness(Theme.step / 2));
      expect(result.fg, noBg.fg);
    });

    test('selected: all three classes', () {
      final ink = resolver.resolve(base, {WidgetState.selected}, cls: PaintClass.ink);
      expect(ink.fg, theme.primary.color);
      expect(ink.bg, base.bg); // ink never sets bg
      expect(ink.addModifier.has(Modifier.bold), isFalse);

      final fill = resolver.resolve(base, {WidgetState.selected}, cls: PaintClass.fill);
      expect(fill.fg, theme.selection.on);
      expect(fill.bg, theme.selection.color);

      final wash = resolver.resolve(base, {WidgetState.selected}, cls: PaintClass.wash);
      expect(wash.bg, theme.selection.color);
      expect(wash.fg, base.fg);
    });

    test('cursor on a colored base lifts it one step, with no bold; nothing for ink', () {
      expect(resolver.resolve(base, {WidgetState.cursor}, cls: PaintClass.ink), base);

      for (final cls in [PaintClass.fill, PaintClass.wash]) {
        final result = resolver.resolve(base, {WidgetState.cursor}, cls: cls);
        expect(result.fg, base.fg, reason: '$cls');
        expect(result.bg, base.bg!.shiftLightness(Theme.step), reason: '$cls');
        expect(result.addModifier.has(Modifier.bold), isFalse, reason: '$cls');
      }
    });

    test('cursor on a bare base lifts the ground color', () {
      const bare = Style(fg: Color.white);
      for (final cls in [PaintClass.fill, PaintClass.wash]) {
        final result = resolver.resolve(bare, {WidgetState.cursor}, cls: cls);
        expect(result.bg, ground.shiftLightness(Theme.step), reason: '$cls');
        expect(result.fg, bare.fg, reason: '$cls');
      }
    });

    test('a null-base fill cursor is the ground lifted one step', () {
      final result = resolver.resolve(null, {WidgetState.cursor}, cls: PaintClass.fill);
      expect(result.fg, theme.background.on);
      expect(result.bg, ground.shiftLightness(Theme.step));
    });

    test('focused: ink tints primary plus bold, fill lifts one step plus bold, wash does nothing', () {
      final ink = resolver.resolve(base, {WidgetState.focused}, cls: PaintClass.ink);
      expect(ink.fg, theme.primary.color);
      expect(ink.bg, base.bg);
      expect(ink.addModifier.has(Modifier.bold), isTrue);

      final fill = resolver.resolve(base, {WidgetState.focused}, cls: PaintClass.fill);
      expect(fill.fg, base.fg);
      expect(fill.bg, base.bg!.shiftLightness(Theme.step));
      expect(fill.addModifier.has(Modifier.bold), isTrue);

      expect(resolver.resolve(base, {WidgetState.focused}, cls: PaintClass.wash), base);
    });

    test('focused on a bare fill lifts the ground color and adds bold', () {
      const bare = Style(fg: Color.white);
      final fill = resolver.resolve(bare, {WidgetState.focused}, cls: PaintClass.fill);
      expect(fill.fg, bare.fg);
      expect(fill.bg, ground.shiftLightness(Theme.step));
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

    test('disabled ink swaps to the disabled tone, plus dim', () {
      final ink = resolver.resolve(base, {WidgetState.disabled}, cls: PaintClass.ink);
      expect(ink.fg, theme.disabled.color);
      expect(ink.bg, base.bg);
      expect(ink.addModifier.has(Modifier.dim), isTrue);
    });

    test('disabled on a filled base mixes both fg and bg toward the ground, plus dim', () {
      final fill = resolver.resolve(base, {WidgetState.disabled}, cls: PaintClass.fill);
      expect(fill.fg, base.fg!.mix(ground, Theme.disabledMix));
      expect(fill.bg, base.bg!.mix(ground, Theme.disabledMix));
      expect(fill.addModifier.has(Modifier.dim), isTrue);
    });

    test('disabled on a background with no fg takes the disabled ink and keeps the background', () {
      const washed = Style(bg: Color.rgb(0x224466));
      final fill = resolver.resolve(washed, {WidgetState.disabled}, cls: PaintClass.fill);
      expect(fill.fg, theme.disabled.color);
      expect(fill.bg, washed.bg);
      expect(fill.addModifier.has(Modifier.dim), isTrue);
    });

    test('disabled under the cursor keeps the cursor bar and blends the ink', () {
      final cursorOnly = resolver.resolve(null, {WidgetState.cursor}, cls: PaintClass.fill);
      final fill = resolver.resolve(null, {WidgetState.cursor, WidgetState.disabled}, cls: PaintClass.fill);
      expect(fill.bg, cursorOnly.bg);
      expect(fill.fg, cursorOnly.fg!.mix(ground, Theme.disabledMix));
      expect(fill.addModifier.has(Modifier.dim), isTrue);
    });

    test('a selected row under a focused cursor keeps its lifted selection when disabled', () {
      final lifted = resolver.resolve(
        null,
        {WidgetState.selected, WidgetState.focused, WidgetState.cursor},
        cls: PaintClass.fill,
      );
      final fill = resolver.resolve(
        null,
        {WidgetState.selected, WidgetState.focused, WidgetState.cursor, WidgetState.disabled},
        cls: PaintClass.fill,
      );
      expect(fill.bg, lifted.bg);
      expect(fill.fg, lifted.fg!.mix(ground, Theme.disabledMix));
    });

    test('the disabled cursor bar keeps its background in every shipped theme', () {
      for (final t in _shipped) {
        final r = StyleResolver(t);
        final bar = r.resolve(null, {WidgetState.cursor}, cls: PaintClass.fill).bg!;
        final disabledBar = r.resolve(null, {WidgetState.cursor, WidgetState.disabled}, cls: PaintClass.fill).bg!;
        expect(disabledBar, bar, reason: t.name);
      }
    });

    test('disabled does nothing for wash', () {
      expect(resolver.resolve(base, {WidgetState.disabled}, cls: PaintClass.wash), base);
    });

    test('disabled on a bare base swaps in the disabled ink, plus dim', () {
      const bare = Style(fg: Color.white);
      final fill = resolver.resolve(bare, {WidgetState.disabled}, cls: PaintClass.fill);
      expect(fill.fg, theme.disabled.color);
      expect(fill.bg, isNull);
      expect(fill.addModifier.has(Modifier.dim), isTrue);
    });

    test('an authored base with a Color.reset background is bare', () {
      const resetBase = Style(fg: Color.white, bg: Color.reset);
      final result = resolver.resolve(resetBase, {WidgetState.cursor}, cls: PaintClass.fill);
      expect(result.fg, resetBase.fg);
      expect(result.bg, ground.shiftLightness(Theme.step));
    });
  });

  group('StyleResolver / state layer order', () {
    // One test per adjacent pair in the order: roles (selected, loading,
    // error), focused, cursor, disabled, hover, pressed, de-emphasis.

    test('selected, then loading: loading ink lands on the selection fill', () {
      final result = resolver.resolve(base, {WidgetState.selected, WidgetState.loading}, cls: PaintClass.fill);
      expect(result.fg, theme.warning.color);
      expect(result.bg, theme.selection.color);
      expect(result.addModifier.has(Modifier.slowBlink), isTrue);
    });

    test('loading, then error: the error fill covers the loading ink', () {
      final result = resolver.resolve(base, {WidgetState.loading, WidgetState.error}, cls: PaintClass.fill);
      expect(result.fg, theme.error.on);
      expect(result.bg, theme.error.color);
      expect(result.addModifier.has(Modifier.slowBlink), isTrue);
    });

    test('error, then focused: focus lifts the error fill and keeps error ink on chrome', () {
      final fill = resolver.resolve(base, {WidgetState.error, WidgetState.focused}, cls: PaintClass.fill);
      expect(fill.fg, theme.error.on);
      expect(fill.bg, theme.error.color!.shiftLightness(Theme.step));
      expect(fill.addModifier.has(Modifier.bold), isTrue);

      final ink = resolver.resolve(null, {WidgetState.error, WidgetState.focused}, cls: PaintClass.ink);
      expect(ink.fg, theme.error.color);
      expect(ink.addModifier.has(Modifier.bold), isTrue);
    });

    test('focused, then cursor: a focused cursor row lifts once, not twice', () {
      final focusOnly = resolver.resolve(base, {WidgetState.focused}, cls: PaintClass.fill);
      final both = resolver.resolve(base, {WidgetState.focused, WidgetState.cursor}, cls: PaintClass.fill);
      expect(both, focusOnly);
      expect(both.addModifier.has(Modifier.bold), isTrue);
    });

    test('cursor, then disabled: the lifted background survives and the ink blends', () {
      final cursorOnly = resolver.resolve(base, {WidgetState.cursor}, cls: PaintClass.fill);
      final result = resolver.resolve(base, {WidgetState.cursor, WidgetState.disabled}, cls: PaintClass.fill);
      expect(result.bg, cursorOnly.bg);
      expect(result.fg, base.fg!.mix(ground, Theme.disabledMix));
    });

    test('disabled, then hover and pressed: disabled ends the chain', () {
      final disabledOnly = resolver.resolve(base, {WidgetState.disabled}, cls: PaintClass.fill);
      for (final extra in [
        {WidgetState.hover},
        {WidgetState.pressed},
        {WidgetState.hover, WidgetState.pressed},
      ]) {
        final result = resolver.resolve(base, {WidgetState.disabled, ...extra}, cls: PaintClass.fill);
        expect(result, disabledOnly, reason: '$extra');
      }
    });

    test('hover, then pressed: pressed lifts one more step on top of hover', () {
      final hoverOnly = resolver.resolve(base, {WidgetState.hover}, cls: PaintClass.fill);
      final both = resolver.resolve(base, {WidgetState.hover, WidgetState.pressed}, cls: PaintClass.fill);
      expect(both.bg, hoverOnly.bg!.shiftLightness(Theme.step));
      expect(_l(both.bg!) - _l(base.bg!), closeTo(Theme.step * 1.5, 0.005));
    });

    test('pressed, then de-emphasis: the lift runs on the quiet base, shortened by the blend', () {
      final quiet = resolver.deEmphasised;
      final quietBase = quiet.fill(theme.selection);
      final result = quiet.resolve(quietBase, {WidgetState.pressed}, cls: PaintClass.fill);
      expect(result.bg, quietBase.bg!.shiftLightness(Theme.step * (1 - theme.deEmphasis)));
    });

    test('roles apply in a fixed order whatever the set order', () {
      final a = resolver.resolve(base, {WidgetState.error, WidgetState.selected}, cls: PaintClass.fill);
      final b = resolver.resolve(base, {WidgetState.selected, WidgetState.error}, cls: PaintClass.fill);
      expect(a, b);
      expect(a.bg, theme.error.color);
    });

    test('cursor over a selected fill keeps the selection fg and lifts its bg one step', () {
      final result = resolver.resolve(base, {WidgetState.selected, WidgetState.cursor}, cls: PaintClass.fill);
      expect(result.fg, theme.selection.on);
      expect(result.bg, theme.selection.color!.shiftLightness(Theme.step));
    });

    test('hover lifts a cursor-lifted selection a second, half step', () {
      final result = resolver.resolve(
        base,
        {WidgetState.selected, WidgetState.cursor, WidgetState.hover},
        cls: PaintClass.fill,
      );
      expect(result.bg, theme.selection.color!.shiftLightness(Theme.step).shiftLightness(Theme.step / 2));
    });
  });

  group('StyleResolver / ink class order', () {
    test('error ink wins over focus ink on chrome; selected ink is primary and focus only adds bold', () {
      final errorFocused = resolver.resolve(null, {WidgetState.focused, WidgetState.error}, cls: PaintClass.ink);
      expect(errorFocused.fg, theme.error.color);
      expect(errorFocused.addModifier.has(Modifier.bold), isTrue);

      final selectedFocused = resolver.resolve(null, {WidgetState.selected, WidgetState.focused}, cls: PaintClass.ink);
      expect(selectedFocused.fg, theme.primary.color);
      expect(selectedFocused.addModifier.has(Modifier.bold), isTrue);

      final selected = resolver.resolve(null, {WidgetState.selected}, cls: PaintClass.ink);
      expect(selected.addModifier.has(Modifier.bold), isFalse);
    });

    test('selected plus error ink is the error ink', () {
      final result = resolver.resolve(null, {WidgetState.selected, WidgetState.error}, cls: PaintClass.ink);
      expect(result.fg, theme.error.color);
    });
  });

  group('StyleResolver / pressed', () {
    test('pressed lifts a fill one step and keeps the foreground', () {
      final result = resolver.resolve(base, {WidgetState.pressed}, cls: PaintClass.fill);
      expect(result.fg, base.fg);
      expect(result.bg, base.bg!.shiftLightness(Theme.step));
      expect(_l(result.bg!) - _l(base.bg!), closeTo(Theme.step, 0.005));
    });

    test('pressed is one step past hover', () {
      final hover = resolver.resolve(base, {WidgetState.hover}, cls: PaintClass.fill);
      final pressedOverHover = resolver.resolve(base, {WidgetState.hover, WidgetState.pressed}, cls: PaintClass.fill);
      expect(_l(pressedOverHover.bg!) - _l(hover.bg!), closeTo(Theme.step, 0.005));
    });

    test('pressed does nothing in the ink class', () {
      expect(resolver.resolve(base, {WidgetState.pressed}, cls: PaintClass.ink), base);
    });

    test('pressed on a glyph hovered with a wash never takes the wash color as its ink', () {
      final hovered = resolver.resolve(base, {WidgetState.hover}, cls: PaintClass.wash);
      final result = resolver.resolve(hovered, {WidgetState.pressed}, cls: PaintClass.wash);
      expect(result.fg, base.fg);
    });
  });

  group('StyleResolver / slots', () {
    const slot = Style(fg: Color.green, bg: Color.rgb(0x224422));

    test('a slot for cursor replaces the lift on a bare base', () {
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

    test('a slot for cursor replaces the lift on a colored base too', () {
      final result = resolver.resolve(
        base,
        {WidgetState.cursor},
        cls: PaintClass.fill,
        slots: {WidgetState.cursor: slot},
      );
      expect(result.fg, slot.fg);
      expect(result.bg, slot.bg);
    });

    test('a slot for focused replaces the lift and the bold', () {
      final fill = resolver.resolve(
        base,
        {WidgetState.focused},
        cls: PaintClass.fill,
        slots: {WidgetState.focused: slot},
      );
      expect(fill.bg, slot.bg);
      expect(fill.addModifier.has(Modifier.bold), isFalse);

      final ink = resolver.resolve(
        base,
        {WidgetState.focused},
        cls: PaintClass.ink,
        slots: {WidgetState.focused: slot},
      );
      expect(ink.fg, slot.fg);
      expect(ink.addModifier.has(Modifier.bold), isFalse);
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

    test('a slot for hover and for pressed replaces the lift', () {
      for (final state in [WidgetState.hover, WidgetState.pressed]) {
        final result = resolver.resolve(base, {state}, cls: PaintClass.fill, slots: {state: slot});
        expect(result.fg, slot.fg, reason: '$state');
        expect(result.bg, slot.bg, reason: '$state');
      }
    });

    test('a slot for disabled replaces the blend and still ends the chain', () {
      final result = resolver.resolve(
        base,
        {WidgetState.disabled, WidgetState.hover},
        cls: PaintClass.fill,
        slots: {WidgetState.disabled: slot},
      );
      expect(result.fg, slot.fg);
      expect(result.bg, slot.bg);
      expect(result.addModifier.has(Modifier.dim), isFalse);
    });

    test('a slot for a state that is not active is ignored', () {
      final without = resolver.resolve(base, {WidgetState.hover}, cls: PaintClass.fill);
      final with_ = resolver.resolve(
        base,
        {WidgetState.hover},
        cls: PaintClass.fill,
        slots: {WidgetState.cursor: slot, WidgetState.selected: slot},
      );
      expect(with_, without);
    });
  });

  group('StyleResolver / ground-bound resolver', () {
    final onSurface = resolver.on(theme.surface);
    final surface = theme.surface.color!;

    test('on() rebinds the ground and keeps the theme, tones and policy', () {
      expect(onSurface.groundTone, same(theme.surface));
      expect(onSurface.theme, same(theme));
      expect(onSurface.tones, same(resolver.tones));
      expect(onSurface.policy, resolver.policy);
    });

    test('a null fill base starts from the bound ground', () {
      expect(onSurface.resolve(null, {}, cls: PaintClass.fill), onSurface.ground(theme.surface));
    });

    test('a lift on surface starts from the surface color', () {
      final result = onSurface.resolve(null, {WidgetState.cursor}, cls: PaintClass.fill);
      expect(result.fg, theme.surface.on);
      expect(result.bg, surface.shiftLightness(Theme.step));
    });

    test('disabled blends toward the bound ground', () {
      final result = onSurface.resolve(base, {WidgetState.disabled}, cls: PaintClass.fill);
      expect(result.fg, base.fg!.mix(surface, Theme.disabledMix));
      expect(result.bg, base.bg!.mix(surface, Theme.disabledMix));
    });

    test('a light ground lifts toward black', () {
      final light = StyleResolver(_light);
      final result = light.resolve(null, {WidgetState.cursor}, cls: PaintClass.fill);
      expect(result.bg, _light.background.color!.shiftLightness(-Theme.step));
      expect(_l(result.bg!), lessThan(_l(_light.background.color!)));
    });

    // The same state set must step the same OKLab distance from whatever
    // ground it lands on.
    final stateSets = <String, Set<WidgetState>>{
      'cursor': {WidgetState.cursor},
      'focused': {WidgetState.focused},
      'hover': {WidgetState.hover},
      'pressed': {WidgetState.pressed},
      'hover + pressed': {WidgetState.hover, WidgetState.pressed},
      'focused + hover': {WidgetState.focused, WidgetState.hover},
      'cursor + hover + pressed': {WidgetState.cursor, WidgetState.hover, WidgetState.pressed},
    };

    for (final t in _shipped) {
      test('${t.name}: a state set steps the same distance on background and on surface', () {
        final r = StyleResolver(t);
        final onBackground = r.on(t.background);
        final onSurface = r.on(t.surface);
        for (final MapEntry(key: label, value: states) in stateSets.entries) {
          for (final cls in [PaintClass.fill, PaintClass.wash]) {
            // A wash has no focus layer, so a focus-only set leaves it bare.
            final fromBackground = onBackground.resolve(null, states, cls: cls).bg;
            final fromSurface = onSurface.resolve(null, states, cls: cls).bg;
            if (fromBackground == null || fromSurface == null) {
              expect(fromBackground, equals(fromSurface), reason: '$label $cls');
              continue;
            }
            final deltaBackground = _l(fromBackground) - _l(t.background.color!);
            final deltaSurface = _l(fromSurface) - _l(t.surface.color!);
            expect(deltaSurface, closeTo(deltaBackground, 0.005), reason: '$label $cls');
          }
        }
      });
    }

    test('the step is the same distance on a light ground', () {
      final r = StyleResolver(_light);
      final fromBackground = r.on(_light.background).resolve(null, {WidgetState.cursor}, cls: PaintClass.fill).bg!;
      final fromSurface = r.on(_light.surface).resolve(null, {WidgetState.cursor}, cls: PaintClass.fill).bg!;
      expect(_l(fromBackground) - _l(_light.background.color!), closeTo(-Theme.step, 0.005));
      expect(_l(fromSurface) - _l(_light.surface.color!), closeTo(-Theme.step, 0.005));
    });
  });

  group('StyleResolver / de-emphasis', () {
    final quiet = resolver.deEmphasised;
    final mix = Theme.dark.deEmphasis;
    const tone = SurfaceTone(color: Color.rgb(0x336699), on: Color.rgb(0xeeeeee));

    Color blend(Color color) => color.mix(ground, mix);

    test('deEmphasised keeps the ground and on() keeps the flag', () {
      expect(quiet.isDeEmphasised, isTrue);
      expect(quiet.groundTone, same(resolver.groundTone));
      expect(resolver.on(theme.surface).deEmphasised.groundTone, same(theme.surface));
      expect(quiet.on(theme.surface).isDeEmphasised, isTrue);
      expect(resolver.isDeEmphasised, isFalse);
    });

    test('ink, fill, wash and ground each blend their colors toward the ground once', () {
      expect(quiet.ink(tone).fg, blend(tone.color!));
      expect(quiet.fill(tone).fg, blend(tone.on));
      expect(quiet.fill(tone).bg, blend(tone.color!));
      expect(quiet.wash(tone).bg, blend(tone.color!));
      expect(quiet.ground(tone).fg, blend(tone.on));
      expect(quiet.ground(tone).bg, blend(tone.color!));
    });

    test('border blends once, for a resting and a focused border', () {
      expect(quiet.border(const {}).fg, blend(theme.border.color!));

      final focused = quiet.border({WidgetState.focused});
      expect(focused.fg, blend(theme.primary.color!));
      expect(focused.addModifier.has(Modifier.bold), isTrue);
    });

    test("resolve's own additions blend once", () {
      final error = quiet.resolve(null, {WidgetState.error}, cls: PaintClass.fill);
      expect(error.fg, blend(theme.error.on));
      expect(error.bg, blend(theme.error.color!));

      final selectedInk = quiet.resolve(null, {WidgetState.selected}, cls: PaintClass.ink);
      expect(selectedInk.fg, blend(theme.primary.color!));

      final loading = quiet.resolve(null, {WidgetState.loading}, cls: PaintClass.ink);
      expect(loading.fg, blend(theme.warning.color!));

      final disabledBare = quiet.resolve(null, {WidgetState.disabled}, cls: PaintClass.ink);
      expect(disabledBare.fg, blend(theme.disabled.color!));

      final disabledFill = quiet.resolve(const Style(bg: Color.rgb(0x224466)), {
        WidgetState.disabled,
      }, cls: PaintClass.fill);
      expect(disabledFill.fg, blend(theme.disabled.color!));
    });

    test("the ground's own fill is not changed by the blend, its text is", () {
      final start = quiet.resolve(null, const {}, cls: PaintClass.fill);
      expect(start.bg, theme.background.color);
      expect(start.fg, blend(theme.background.on));
    });

    test('resolve does not blend its base', () {
      const raw = Style(fg: Color.rgb(0xaa5500), bg: Color.rgb(0x334455));
      expect(quiet.resolve(raw, const {}, cls: PaintClass.fill), raw);
      expect(quiet.resolve(raw, {WidgetState.cursor}, cls: PaintClass.fill).fg, raw.fg);
    });

    test('a slot style is blended before it patches', () {
      const slot = Style(fg: Color.rgb(0x88cc44), bg: Color.rgb(0x224422));
      final result = quiet.resolve(
        null,
        {WidgetState.cursor},
        cls: PaintClass.fill,
        slots: {WidgetState.cursor: slot},
      );
      expect(result.fg, blend(slot.fg!));
      expect(result.bg, blend(slot.bg!));
    });

    test('null and reset colors stay as they are', () {
      const reset = Style(fg: Color.reset, bg: Color.reset);
      final onReset = StyleResolver(theme).deEmphasised;
      expect(onReset.ink(const Tone()), const Style());
      expect(onReset.fill(const SurfaceTone(on: Color.reset)).fg, Color.reset);
      expect(onReset.resolve(reset, const {}, cls: PaintClass.fill), reset);
    });

    test('the amount is the theme field', () {
      final custom = StyleResolver(theme.copyWith(deEmphasis: 0.8)).deEmphasised;
      expect(custom.ink(tone).fg, tone.color!.mix(ground, 0.8));
    });

    test('a de-emphasised resolver on surface blends toward the surface', () {
      final onSurface = resolver.on(theme.surface).deEmphasised;
      expect(onSurface.ink(tone).fg, tone.color!.mix(theme.surface.color!, mix));
    });

    test('a de-emphasised state set lifts from the quiet base by the quiet share of a step', () {
      final result = quiet.resolve(quiet.fill(tone), {WidgetState.hover}, cls: PaintClass.fill);
      expect(result.bg, blend(tone.color!).shiftLightness(Theme.step / 2 * (1 - mix)));
    });

    test('a de-emphasised cursor row lifts the ground by the quiet share of a step', () {
      final result = quiet.resolve(null, {WidgetState.cursor}, cls: PaintClass.fill);
      expect(_l(result.bg!) - _l(ground), closeTo(Theme.step * (1 - mix), 0.005));
    });
  });

  group('StyleResolver / border helper', () {
    test('resting border is border.ink', () {
      final result = resolver.border({});
      expect(result.fg, theme.border.color);
      expect(result.bg, isNull);
    });

    test('focused border is the primary ink plus bold, never a bg', () {
      final result = resolver.border({WidgetState.focused});
      expect(result.fg, theme.primary.color);
      expect(result.bg, isNull);
      expect(result.addModifier.has(Modifier.bold), isTrue);
    });

    test('selected border is the plain primary ink', () {
      final result = resolver.border({WidgetState.selected});
      expect(result.fg, theme.primary.color);
      expect(result.bg, isNull);
      expect(result.addModifier.has(Modifier.bold), isFalse);
    });

    test('an error border keeps the error ink even while focused', () {
      final result = resolver.border({WidgetState.error, WidgetState.focused});
      expect(result.fg, theme.error.color);
      expect(result.addModifier.has(Modifier.bold), isTrue);
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
      final projected = r.ground(tone);
      expect(projected.fg, tone.on);
      expect(projected.bg, tone.color);
      expect(projected, r.fill(tone));
    });

    test('ansi16 keeps only the foreground', () {
      final r = StyleResolver(theme, policy: RenderPolicy.ansi16);
      final projected = r.ground(tone);
      expect(projected.fg, tone.on);
      expect(projected.bg, isNull);
    });

    test('noColor drops all color', () {
      final r = StyleResolver(theme, policy: RenderPolicy.noColor);
      expect(r.ground(tone), const Style());
    });
  });
}
