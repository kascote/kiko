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

      test('$name: every RGB surface tone with a color has a matching named pair', () {
        final table = theme.tones16!;
        final rgb = <String, SurfaceTone>{
          'primary': theme.primary,
          'secondary': theme.secondary,
          'accent': theme.accent,
          'error': theme.error,
          'warning': theme.warning,
          'success': theme.success,
          'background': theme.background,
          'surface': theme.surface,
          'focus': theme.focus,
          'selection': theme.selection,
        };
        final named = <String, SurfaceTone>{
          'primary': table.primary,
          'secondary': table.secondary,
          'accent': table.accent,
          'error': table.error,
          'warning': table.warning,
          'success': table.success,
          'background': table.background,
          'surface': table.surface,
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
          expect(namedTone.on, isNotNull, reason: '$name.$key must always carry a readable named `on`');
        }
      });

      test('$name: every RGB chrome tone with a color has a matching named color', () {
        final table = theme.tones16!;
        final rgb = <String, Tone>{'border': theme.border, 'muted': theme.muted, 'disabled': theme.disabled};
        final named = <String, Tone>{'border': table.border, 'muted': table.muted, 'disabled': table.disabled};

        for (final key in rgb.keys) {
          final rgbTone = rgb[key]!;
          final namedTone = named[key]!;

          if (rgbTone.color == null) {
            expect(namedTone.color, isNull, reason: '$name.$key has no RGB color, so its named color must stay null');
          } else {
            expect(namedTone.color, isNotNull, reason: '$name.$key has an RGB color but no named color');
          }
        }
      });

      test('$name: cursor has a named color (no RGB counterpart to mirror)', () {
        expect(theme.tones16!.cursor.color, isNotNull);
      });

      test('$name: every named color is an ANSI color in the 0-15 range', () {
        final table = theme.tones16!;
        final colors = <Color?>[
          table.primary.color, table.primary.on, //
          table.secondary.color, table.secondary.on,
          table.accent.color, table.accent.on,
          table.error.color, table.error.on,
          table.warning.color, table.warning.on,
          table.success.color, table.success.on,
          table.background.color, table.background.on,
          table.surface.color, table.surface.on,
          table.border.color,
          table.muted.color,
          table.disabled.color,
          table.focus.color, table.focus.on,
          table.selection.color, table.selection.on,
          table.cursor.color, table.cursor.on,
        ];

        for (final color in colors) {
          if (color == null) continue;
          expect(color.kind, equals(ColorKind.ansi), reason: '$name: $color must be an ANSI color');
          expect(color.value, inInclusiveRange(0, 15), reason: '$name: $color must be in range 0-15');
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
          'selection': resolver.resolve(null, {WidgetState.selected}, cls: PaintClass.fill),
          'cursor': resolver.resolve(null, {WidgetState.cursor}, cls: PaintClass.fill),
          'focus': resolver.resolve(null, {WidgetState.focused}, cls: PaintClass.fill),
          'error': resolver.resolve(null, {WidgetState.error}, cls: PaintClass.fill),
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
        final cursor = resolver.resolve(null, {WidgetState.cursor}, cls: PaintClass.fill);
        final focus = resolver.resolve(null, {WidgetState.focused}, cls: PaintClass.fill);

        expect(cursor.addModifier.has(Modifier.bold), isTrue);
        expect(focus.addModifier.has(Modifier.bold), isTrue);
      });
    }
  });
}
