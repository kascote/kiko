import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  const themes = <String, Theme>{
    'dark': Theme.dark,
    'light': Theme.light,
    'ember': Theme.ember,
    'ansiDark': Theme.ansiDark,
  };

  group('built-in themes: tones16 completeness', () {
    for (final entry in themes.entries) {
      final name = entry.key;
      final theme = entry.value;

      test('$name hand-authors a tones16 table', () {
        expect(theme.tones16, isNotNull);
      });

      test('$name: every RGB tone with a color has a matching named pair', () {
        final table = theme.tones16!;
        final rgb = <String, Tone>{
          'primary': theme.primary,
          'secondary': theme.secondary,
          'accent': theme.accent,
          'error': theme.error,
          'warning': theme.warning,
          'success': theme.success,
          'background': theme.background,
          'surface': theme.surface,
          'border': theme.border,
          'muted': theme.muted,
          'disabled': theme.disabled,
          'focus': theme.focus,
          'selection': theme.selection,
        };
        final named = <String, Tone>{
          'primary': table.primary,
          'secondary': table.secondary,
          'accent': table.accent,
          'error': table.error,
          'warning': table.warning,
          'success': table.success,
          'background': table.background,
          'surface': table.surface,
          'border': table.border,
          'muted': table.muted,
          'disabled': table.disabled,
          'focus': table.focus,
          'selection': table.selection,
        };

        for (final key in rgb.keys) {
          final rgbTone = rgb[key]!;
          final namedTone = named[key]!;

          if (rgbTone.color == null) {
            expect(namedTone.color, isNull, reason: '$name.$key has no RGB color, so its named color must stay null');
            continue;
          }
          expect(namedTone.color, isNotNull, reason: '$name.$key has an RGB color but no named color');

          if (rgbTone.on == null) {
            expect(namedTone.on, isNull, reason: '$name.$key has no readable RGB `on`, so its named `on` should match');
          } else {
            expect(namedTone.on, isNotNull, reason: '$name.$key has a readable RGB `on` but no named `on`');
          }
        }
      });

      test('$name: cursor has a named color (no RGB counterpart to mirror)', () {
        expect(theme.tones16!.cursor.color, isNotNull);
      });

      test('$name: every named color is an ANSI color in the 0-15 range', () {
        final table = theme.tones16!;
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
          for (final color in [tone.color, tone.on]) {
            if (color == null) continue;
            expect(color.kind, equals(ColorKind.ansi), reason: '$name: $color must be an ANSI color');
            expect(color.value, inInclusiveRange(0, 15), reason: '$name: $color must be in range 0-15');
          }
        }
      });
    }
  });

  group('built-in themes: tones16 distinctness under RenderPolicy.ansi16', () {
    for (final entry in themes.entries) {
      final name = entry.key;
      final theme = entry.value;

      test('$name: selection, cursor, focus and error resolve to distinct fills', () {
        final resolver = StyleResolver(theme, policy: RenderPolicy.ansi16);

        final resolved = <String, Style>{
          'selection': resolver.resolve(null, {WidgetState.selected}),
          'cursor': resolver.resolve(null, {WidgetState.cursor}),
          'focus': resolver.resolve(null, {WidgetState.focused}),
          'error': resolver.resolve(null, {WidgetState.error}),
        };

        final keys = resolved.keys.toList();
        for (var i = 0; i < keys.length; i++) {
          for (var j = i + 1; j < keys.length; j++) {
            expect(
              resolved[keys[i]],
              isNot(equals(resolved[keys[j]])),
              reason: '$name: ${keys[i]} and ${keys[j]} must resolve to different styles',
            );
          }
        }
      });

      test('$name: cursor and focus fills still carry bold', () {
        final resolver = StyleResolver(theme, policy: RenderPolicy.ansi16);
        final cursor = resolver.resolve(null, {WidgetState.cursor});
        final focus = resolver.resolve(null, {WidgetState.focused});

        expect(cursor.addModifier.has(Modifier.bold), isTrue);
        expect(focus.addModifier.has(Modifier.bold), isTrue);
      });
    }
  });
}
