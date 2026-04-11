import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  const theme = Theme.dark;
  const resolver = StyleResolver(theme);

  group('StyleResolver', () {
    test('empty states returns base unchanged', () {
      const base = Style(fg: Color.red, bg: Color.blue);
      final result = resolver.resolve(base, {});
      expect(result, base);
    });

    test('null base returns empty style when no states', () {
      final result = resolver.resolve(null, {});
      expect(result, const Style());
    });

    test('null base with states starts from empty', () {
      final result = resolver.resolve(null, {WidgetState.focused});
      // Should have focus style patched onto empty.
      expect(result.fg, theme.focus.fg);
      expect(result.addModifier.has(Modifier.bold), isTrue);
    });

    test('focused applies theme.focus', () {
      const base = Style(fg: Color.white);
      final result = resolver.resolve(base, {WidgetState.focused});
      expect(result.fg, theme.focus.fg);
      expect(result.addModifier.has(Modifier.bold), isTrue);
    });

    test('selected applies theme.highlight', () {
      const base = Style(fg: Color.white);
      final result = resolver.resolve(base, {WidgetState.selected});
      expect(result.fg, theme.highlight.fg);
      expect(result.bg, theme.highlight.bg);
    });

    test('unfocused applies muted fg and surface bg', () {
      const base = Style(fg: Color.white, bg: Color.black);
      final result = resolver.resolve(base, {WidgetState.unfocused});
      expect(result.fg, theme.muted.fg);
      expect(result.bg, theme.surface.bg);
    });

    test('disabled applies theme.disabled with dim', () {
      const base = Style(fg: Color.white);
      final result = resolver.resolve(base, {WidgetState.disabled});
      expect(result.fg, theme.disabled.fg);
      expect(result.addModifier.has(Modifier.dim), isTrue);
    });

    test('loading applies warning fg and slowBlink', () {
      const base = Style(fg: Color.white);
      final result = resolver.resolve(base, {WidgetState.loading});
      expect(result.fg, theme.warning.fg);
      expect(result.addModifier.has(Modifier.slowBlink), isTrue);
    });

    test('error applies error fg', () {
      const base = Style(fg: Color.white);
      final result = resolver.resolve(base, {WidgetState.error});
      expect(result.fg, theme.error.fg);
    });

    test('hover applies lightened background', () {
      const base = Style(fg: Color.white, bg: Color.rgb(0x808080));
      final result = resolver.resolve(base, {WidgetState.hover});
      // bg should be lighter than original.
      expect(result.bg, isNot(base.bg));
      expect(result.bg!.kind, ColorKind.rgb);
    });

    test('disabled overrides focused (priority order)', () {
      const base = Style(fg: Color.white);
      final result = resolver.resolve(base, {
        WidgetState.focused,
        WidgetState.disabled,
      });
      // disabled is higher priority, applied last.
      expect(result.fg, theme.disabled.fg);
      expect(result.addModifier.has(Modifier.dim), isTrue);
    });

    test('hover suppressed when focused also active', () {
      const base = Style(fg: Color.white, bg: Color.rgb(0x808080));
      final withBoth = resolver.resolve(base, {
        WidgetState.hover,
        WidgetState.focused,
      });
      final focusOnly = resolver.resolve(base, {WidgetState.focused});
      // hover should be skipped, so result matches focus-only.
      expect(withBoth, focusOnly);
    });

    test('overrides map replaces default for a state', () {
      const base = Style(fg: Color.white);
      const custom = Style(fg: Color.green, bg: Color.yellow);
      final result = resolver.resolve(
        base,
        {WidgetState.focused},
        overrides: {WidgetState.focused: custom},
      );
      expect(result.fg, Color.green);
      expect(result.bg, Color.yellow);
    });

    test('multiple simultaneous states applied in order', () {
      const base = Style(fg: Color.white);
      final result = resolver.resolve(base, {
        WidgetState.selected,
        WidgetState.error,
      });
      // error (index 6) applied after selected (index 2).
      expect(result.fg, theme.error.fg);
      // selected bg should persist since error doesn't set bg.
      expect(result.bg, theme.highlight.bg);
    });
  });
}
