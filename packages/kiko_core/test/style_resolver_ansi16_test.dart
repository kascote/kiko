import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('StyleResolver RenderPolicy.ansi16 projection', () {
    const theme = Theme.dark;
    final derived = Ansi16Tones.derive(theme);
    final resolver = StyleResolver(theme, policy: RenderPolicy.ansi16);

    test('the resolver resolves the table derived from the theme', () {
      expect(resolver.tones, same(derived));
    });

    test('a fill resolves to the named pair from the ANSI-16 table', () {
      final s = resolver.resolve(null, {WidgetState.selected}, cls: PaintClass.fill);
      expect(s.fg, equals(derived.selection.on));
      expect(s.bg, equals(derived.selection.color));
    });

    test('an ink resolves to the named fg only, never a background', () {
      final s = resolver.resolve(null, {WidgetState.selected}, cls: PaintClass.ink);
      expect(s.fg, equals(derived.primary.color));
      expect(s.bg, isNull);
    });

    test('a wash projects to nothing — the 16-name vocabulary has no tints', () {
      expect(resolver.resolve(null, {WidgetState.selected}, cls: PaintClass.wash), equals(const Style()));
      expect(resolver.wash(resolver.tones.error), equals(const Style()));
    });

    test('a lifted wash is the bright variant of the ground', () {
      final expected = resolver.tones.background.color!.brighten();
      expect(resolver.resolve(null, {WidgetState.cursor}, cls: PaintClass.wash), equals(Style(bg: expected)));
      expect(resolver.resolve(null, {WidgetState.hover}, cls: PaintClass.wash), equals(Style(bg: expected)));
    });

    test('hover lifts a fill to the bright variant under ansi16', () {
      final fill = resolver.resolve(null, {WidgetState.selected}, cls: PaintClass.fill);
      final result = resolver.resolve(fill, {WidgetState.hover}, cls: PaintClass.fill);
      expect(result.fg, fill.fg);
      expect(result.bg, fill.bg!.brighten());
    });

    test('cursor over a selected fill maps to the bright variant under ansi16, without bold', () {
      final result = resolver.resolve(null, {WidgetState.selected, WidgetState.cursor}, cls: PaintClass.fill);
      expect(result.fg, derived.selection.on);
      expect(result.bg, derived.selection.color!.brighten());
      expect(result.addModifier.has(Modifier.bold), isFalse);
    });

    test('a focused cursor row lifts once and carries bold', () {
      final focusedOnly = resolver.resolve(null, {WidgetState.selected, WidgetState.focused}, cls: PaintClass.fill);
      final both = resolver.resolve(
        null,
        {WidgetState.selected, WidgetState.focused, WidgetState.cursor},
        cls: PaintClass.fill,
      );
      expect(both, equals(focusedOnly));
      expect(both.addModifier.has(Modifier.bold), isTrue);
    });

    test('a second lift under ansi16 is idempotent — a bright slot stays bright', () {
      final onceLifted = resolver.resolve(null, {WidgetState.selected, WidgetState.cursor}, cls: PaintClass.fill);
      final twiceLifted = resolver.resolve(onceLifted, {WidgetState.hover}, cls: PaintClass.fill);
      expect(twiceLifted.bg, onceLifted.bg);
    });

    test('disabled keeps the named pair and adds dim under ansi16', () {
      final selectedFill = resolver.resolve(null, {WidgetState.selected}, cls: PaintClass.fill);
      final result = resolver.resolve(selectedFill, {WidgetState.disabled}, cls: PaintClass.fill);
      expect(result.fg, selectedFill.fg);
      expect(result.bg, selectedFill.bg);
      expect(result.addModifier.has(Modifier.dim), isTrue);
    });

    test('pressed lifts the named pair to the bright variant instead of inverting it', () {
      final fill = resolver.resolve(null, {WidgetState.selected}, cls: PaintClass.fill);
      final result = resolver.resolve(fill, {WidgetState.pressed}, cls: PaintClass.fill);
      expect(result.fg, fill.fg);
      expect(result.bg, fill.bg!.brighten());
    });

    test('a cursor fill with no base lifts the ground color', () {
      final s = resolver.resolve(null, {WidgetState.cursor}, cls: PaintClass.fill);
      expect(s.fg, isNull);
      expect(s.bg, equals(derived.background.color!.brighten()));
    });

    test('on() paints the sixteen-color surface', () {
      final onSurface = resolver.on(resolver.tones.surface);
      expect(onSurface.groundTone, same(derived.surface));
      expect(onSurface.fill(onSurface.groundTone), equals(Style(fg: derived.surface.on, bg: derived.surface.color)));

      final lifted = onSurface.resolve(null, {WidgetState.cursor}, cls: PaintClass.fill);
      expect(lifted.fg, isNull);
      expect(lifted.bg, equals(derived.surface.color!.brighten()));
    });

    test('a de-emphasised resolver adds dim to every projection and result', () {
      final quiet = resolver.deEmphasised;
      expect(quiet.ink(quiet.tones.primary), equals(resolver.ink(resolver.tones.primary).incModifier(Modifier.dim)));
      expect(quiet.fill(quiet.tones.primary), equals(resolver.fill(resolver.tones.primary).incModifier(Modifier.dim)));
      expect(quiet.wash(quiet.tones.primary).addModifier.has(Modifier.dim), isTrue);
      expect(quiet.ground(quiet.tones.surface).addModifier.has(Modifier.dim), isTrue);
      expect(quiet.border(const {}).addModifier.has(Modifier.dim), isTrue);
      expect(quiet.resolve(null, const {}, cls: PaintClass.ink).addModifier.has(Modifier.dim), isTrue);
      expect(quiet.resolve(null, {WidgetState.hover}, cls: PaintClass.fill).addModifier.has(Modifier.dim), isTrue);
    });

    test('the border helper reads the named border tone', () {
      final resting = resolver.border(const {});
      expect(resting.fg, equals(derived.border.color));
      expect(resting.bg, isNull);
    });

    test('an edited tone is re-derived', () {
      final variant = theme.copyWith(selection: theme.error);
      final variantResolver = StyleResolver(variant, policy: RenderPolicy.ansi16);

      expect(variantResolver.tones, same(Ansi16Tones.derive(variant)));
      final s = variantResolver.resolve(null, {WidgetState.selected}, cls: PaintClass.fill);
      expect(s.bg, equals(derived.error.color));
      expect(s.bg, isNot(equals(derived.selection.color)));
    });

    test('the color policy is unaffected by ansi16 — fills still carry full RGB', () {
      final colorResolver = StyleResolver(theme, policy: RenderPolicy.color);
      final s = colorResolver.resolve(null, const {WidgetState.selected}, cls: PaintClass.fill);
      expect(s.bg, equals(theme.selection.color));
    });

    // Deliverable: every interaction state stays DISTINGUISHABLE under
    // ansi16, mirroring the NO_COLOR suite's byFillModifier table. Under
    // ansi16 the states mostly separate by which named color they carry —
    // fill still resolves to a real (fg, bg) pair, not nothing — but a state
    // whose contribution collapses onto another's color still needs a
    // modifier floor to read apart (see the ansiDark case below).
    final fillStates = <WidgetState>[
      WidgetState.selected,
      WidgetState.cursor,
      WidgetState.focused,
      WidgetState.error,
      WidgetState.disabled,
      WidgetState.loading,
    ];
    test('selected/cursor/focused/error/disabled/loading resolve to distinct fills', () {
      final resolved = {
        for (final state in fillStates) state: resolver.resolve(null, {state}, cls: PaintClass.fill),
      };

      expect(resolved.values, everyElement(isNot(equals(const Style()))), reason: 'every state must paint something');

      for (var i = 0; i < fillStates.length; i++) {
        for (var j = i + 1; j < fillStates.length; j++) {
          expect(
            resolved[fillStates[i]],
            isNot(equals(resolved[fillStates[j]])),
            reason: '${fillStates[i]} and ${fillStates[j]} must resolve to different styles',
          );
        }
      }
    });

    test('disabled keeps its dim modifier even though _cell projects it through ink, not fill', () {
      final s = resolver.resolve(null, {WidgetState.disabled}, cls: PaintClass.fill);
      expect(s.fg, equals(derived.disabled.color));
      expect(s.bg, isNull, reason: 'disabled projects through ink even under PaintClass.fill');
      expect(s.addModifier.has(Modifier.dim), isTrue);
    });

    test('loading keeps its slow blink modifier alongside the named warning color', () {
      final s = resolver.resolve(null, {WidgetState.loading}, cls: PaintClass.fill);
      expect(s.fg, equals(derived.warning.color));
      expect(s.bg, isNull, reason: 'loading projects through ink even under PaintClass.fill');
      expect(s.addModifier.has(Modifier.slowBlink), isTrue);
    });

    test('two tones can land on one slot — the modifier is what tells them apart, same as NO_COLOR', () {
      // Muted and disabled derived onto the same slot (gray) is an accepted
      // collapse, since disabled still carries its dim modifier on top. This
      // is the ansi16 analogue of NO_COLOR's modifier floor.
      final collapsed = Theme.dark.copyWith(disabled: Theme.dark.muted);
      final collapsedResolver = StyleResolver(collapsed, policy: RenderPolicy.ansi16);
      final muted = collapsedResolver.ink(collapsedResolver.tones.muted);
      final disabled = collapsedResolver.resolve(null, {WidgetState.disabled}, cls: PaintClass.fill);

      expect(muted.fg, equals(disabled.fg), reason: 'the derivation maps both to the same slot');
      expect(muted.addModifier.has(Modifier.dim), isFalse);
      expect(disabled.addModifier.has(Modifier.dim), isTrue);
      expect(muted, isNot(equals(disabled)), reason: 'the dim modifier is the only thing telling them apart');
    });

    test('the border helper stays colored at rest and gains bold while focused', () {
      final resting = resolver.border(const {});
      expect(resting.fg, equals(derived.border.color));
      expect(resting.addModifier.has(Modifier.bold), isFalse);

      final focused = resolver.border(const {WidgetState.focused});
      expect(focused.fg, equals(derived.primary.color));
      expect(focused.addModifier.has(Modifier.bold), isTrue);
      expect(focused, isNot(equals(resting)), reason: 'focus must read differently from resting chrome');
    });
  });

  group('Ansi16Tones.derive keeps every table readable', () {
    // A derived `on` is picked from the slot the color lands on, so it can
    // only be black or bright white.
    final sources = <String, Theme>{'dark': Theme.dark, 'gruvbox': Theme.gruvbox};

    for (final MapEntry(key: name, value: bare) in sources.entries) {
      test('$name: every derived `on` is black or bright white', () {
        final table = Ansi16Tones.derive(bare);
        final tones = <SurfaceTone>[
          table.primary,
          table.secondary,
          table.accent,
          table.error,
          table.warning,
          table.success,
          table.background,
          table.surface,
          table.selection,
        ];

        for (final tone in tones) {
          expect(
            tone.on == Color.black || tone.on == Color.white,
            isTrue,
            reason: '$name: derived `on` ${tone.on} must be black or bright white, never a named hue',
          );
        }
      });
    }
  });
}
