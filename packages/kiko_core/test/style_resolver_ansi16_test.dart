import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('StyleResolver RenderPolicy.ansi16 projection', () {
    // Theme.dark's own tones, but with no hand-authored tones16 — Theme.dark
    // itself now hand-authors one, so a fresh theme is needed here to
    // exercise the derivation fallback this group is testing.
    final theme = Theme(
      primary: Theme.dark.primary,
      secondary: Theme.dark.secondary,
      accent: Theme.dark.accent,
      error: Theme.dark.error,
      warning: Theme.dark.warning,
      success: Theme.dark.success,
      background: Theme.dark.background,
      surface: Theme.dark.surface,
      border: Theme.dark.border,
      muted: Theme.dark.muted,
      disabled: Theme.dark.disabled,
      focus: Theme.dark.focus,
      selection: Theme.dark.selection,
    );
    final derived = Ansi16Tones.derive(theme);
    final resolver = StyleResolver(theme, policy: RenderPolicy.ansi16);

    test('the resolver resolves the derived table when the theme has none of its own', () {
      expect(resolver.tones, same(derived));
    });

    test('a fill resolves to the named pair from the ANSI-16 table', () {
      final s = resolver.resolve(null, {WidgetState.selected});
      expect(s.fg, equals(derived.selection.on));
      expect(s.bg, equals(derived.selection.color));
    });

    test('an ink resolves to the named fg only, never a background', () {
      final s = resolver.resolve(null, {WidgetState.focused}, cls: PaintClass.ink);
      expect(s.fg, equals(derived.focus.color));
      expect(s.bg, isNull);
    });

    test('a wash resolves to nothing — the 16-name vocabulary has no tints', () {
      expect(resolver.resolve(null, {WidgetState.selected}, cls: PaintClass.wash), equals(const Style()));
      expect(resolver.resolve(null, {WidgetState.cursor}, cls: PaintClass.wash), equals(const Style()));
      expect(resolver.resolve(null, {WidgetState.hover}, cls: PaintClass.wash), equals(const Style()));
    });

    test('the cursor fill still carries its bold modifier', () {
      final s = resolver.resolve(null, {WidgetState.cursor});
      expect(s.fg, equals(derived.cursor.on));
      expect(s.bg, equals(derived.cursor.color));
      expect(s.addModifier.has(Modifier.bold), isTrue);
    });

    test('the border helper reads the named border tone', () {
      final resting = resolver.border(const {});
      expect(resting.fg, equals(derived.border.color));
      expect(resting.bg, isNull);
    });

    test('a hand-authored tones16 wins over derivation', () {
      const handAuthored = Ansi16Tones(
        primary: Tone(color: Color.cyan, on: Color.black),
        secondary: Tone(color: Color.magenta, on: Color.black),
        accent: Tone(color: Color.yellow, on: Color.black),
        error: Tone(color: Color.red, on: Color.white),
        warning: Tone(color: Color.yellow, on: Color.black),
        success: Tone(color: Color.green, on: Color.black),
        background: Tone(color: Color.black, on: Color.white),
        surface: Tone(color: Color.darkGray, on: Color.white),
        border: Tone(color: Color.gray),
        muted: Tone(color: Color.darkGray),
        disabled: Tone(color: Color.darkGray),
        focus: Tone(color: Color.brightCyan, on: Color.black),
        selection: Tone(color: Color.brightMagenta, on: Color.black),
        cursor: Tone(color: Color.brightYellow, on: Color.black),
      );
      final withTable = theme.copyWith(tones16: handAuthored);
      final resolverWithTable = StyleResolver(withTable, policy: RenderPolicy.ansi16);

      expect(resolverWithTable.tones, same(handAuthored));

      final s = resolverWithTable.resolve(null, {WidgetState.selected});
      expect(s.fg, equals(Color.black));
      expect(s.bg, equals(Color.brightMagenta));
      // Distinct from what plain derivation would have produced.
      expect(s.bg, isNot(equals(derived.selection.color)));
    });

    test('the color policy is unaffected by ansi16 — fills still carry full RGB', () {
      final colorResolver = StyleResolver(theme, policy: RenderPolicy.color);
      final s = colorResolver.resolve(null, const {WidgetState.selected});
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
        for (final state in fillStates) state: resolver.resolve(null, {state}),
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
      final s = resolver.resolve(null, {WidgetState.disabled});
      expect(s.fg, equals(derived.disabled.color));
      expect(s.bg, isNull, reason: 'disabled projects through ink even under PaintClass.fill');
      expect(s.addModifier.has(Modifier.dim), isTrue);
    });

    test('loading keeps its slow blink modifier alongside the named warning color', () {
      final s = resolver.resolve(null, {WidgetState.loading});
      expect(s.fg, equals(derived.warning.color));
      expect(s.bg, isNull, reason: 'loading projects through ink even under PaintClass.fill');
      expect(s.addModifier.has(Modifier.slowBlink), isTrue);
    });

    test('unfocused reads through the muted named color, its wash dropped', () {
      final s = resolver.resolve(null, {WidgetState.unfocused});
      expect(s.fg, equals(derived.muted.color));
      expect(s.bg, isNull, reason: 'the surface wash has nothing left to contribute under ansi16');
    });

    test('a hand-authored table can still collapse two states onto the same named color — the '
        'modifier is what tells them apart, same as NO_COLOR', () {
      // Theme.ansiDark hand-authors muted and disabled as the SAME named
      // color (darkGray): an accepted collapse, since disabled still carries
      // its dim modifier on top. This is the ansi16 analogue of NO_COLOR's
      // modifier floor — verified here against a real built-in table, not a
      // constructed one.
      final ansiDarkResolver = StyleResolver(Theme.ansiDark, policy: RenderPolicy.ansi16);
      final unfocused = ansiDarkResolver.resolve(null, {WidgetState.unfocused});
      final disabled = ansiDarkResolver.resolve(null, {WidgetState.disabled});

      expect(unfocused.fg, equals(disabled.fg), reason: 'ansiDark hand-authors both as darkGray');
      expect(unfocused.addModifier.has(Modifier.dim), isFalse);
      expect(disabled.addModifier.has(Modifier.dim), isTrue);
      expect(unfocused, isNot(equals(disabled)), reason: 'the dim modifier is the only thing telling them apart');
    });

    test('the border helper stays colored at rest and gains bold while focused', () {
      final resting = resolver.border(const {});
      expect(resting.fg, equals(derived.border.color));
      expect(resting.addModifier.has(Modifier.bold), isFalse);

      final focused = resolver.border(const {WidgetState.focused});
      expect(focused.fg, equals(derived.focus.color));
      expect(focused.addModifier.has(Modifier.bold), isTrue);
      expect(focused, isNot(equals(resting)), reason: 'focus must read differently from resting chrome');
    });
  });

  group('Ansi16Tones.derive keeps every table readable', () {
    // A derived `on` is always picked fresh from the mapped color's own
    // luminance (see Ansi16Tones.derive), never the theme's original `on` —
    // so it can only ever land on the two ends of the contrast range: pure
    // black or bright white. Verified here across a couple of built-in
    // themes' RGB tones, stripped of their hand-authored tones16 so
    // derivation actually runs.
    Theme bareRgb(Theme source) => Theme(
      primary: source.primary,
      secondary: source.secondary,
      accent: source.accent,
      error: source.error,
      warning: source.warning,
      success: source.success,
      background: source.background,
      surface: source.surface,
      border: source.border,
      muted: source.muted,
      disabled: source.disabled,
      focus: source.focus,
      selection: source.selection,
    );

    final sources = <String, Theme>{'dark': bareRgb(Theme.dark), 'ember': bareRgb(Theme.ember)};

    for (final MapEntry(key: name, value: bare) in sources.entries) {
      test('$name: every derived `on` is black or bright white', () {
        final table = Ansi16Tones.derive(bare);
        final tones = <Tone>[
          table.primary,
          table.secondary,
          table.accent,
          table.error,
          table.warning,
          table.success,
          table.background,
          table.surface,
          table.border,
          table.muted,
          table.disabled,
          table.focus,
          table.selection,
          table.cursor,
        ];

        for (final tone in tones) {
          final on = tone.on;
          if (on == null) continue;
          expect(
            on == Color.black || on == Color.white,
            isTrue,
            reason: '$name: derived `on` $on must be black or bright white, never a named hue',
          );
        }
      });
    }
  });
}
