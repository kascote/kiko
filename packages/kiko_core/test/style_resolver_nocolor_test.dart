import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  final resolver = StyleResolver(Theme.dark, policy: RenderPolicy.noColor);

  Style resolve(WidgetState state, PaintClass cls) => resolver.resolve(null, {state}, cls: cls);

  group('StyleResolver NO_COLOR projection policy', () {
    test('a fill degrades to reversed with no color', () {
      final s = resolve(WidgetState.selected, PaintClass.fill);
      expect(s.addModifier.has(Modifier.reversed), isTrue);
      expect(s.fg, isNull);
      expect(s.bg, isNull);
    });

    test('an ink keeps its modifiers but drops the foreground', () {
      final s = resolve(WidgetState.focused, PaintClass.ink);
      expect(s.addModifier.has(Modifier.bold), isTrue);
      expect(s.fg, isNull);
    });

    test('a wash degrades to nothing — the crosshair falls back to the cursor cell', () {
      expect(resolve(WidgetState.selected, PaintClass.wash), equals(const Style()));
      expect(resolve(WidgetState.cursor, PaintClass.wash), equals(const Style()));
      expect(resolve(WidgetState.hover, PaintClass.wash), equals(const Style()));
    });

    // Deliverable: every interaction state stays DISTINGUISHABLE using modifiers
    // alone. Table-driven off the section 5 matrix — the surface (fill) column,
    // which is where each state paints a whole row/face.
    final byFillModifier = <WidgetState, Modifier>{
      WidgetState.selected: Modifier.reversed,
      WidgetState.cursor: Modifier.reversed,
      WidgetState.focused: Modifier.reversed,
      WidgetState.error: Modifier.reversed,
      WidgetState.disabled: Modifier.dim,
      WidgetState.loading: Modifier.slowBlink,
    };
    for (final MapEntry(key: state, value: mod) in byFillModifier.entries) {
      test('$state stays visible via $mod under NO_COLOR (fill)', () {
        final s = resolve(state, PaintClass.fill);
        expect(s.addModifier.has(mod), isTrue, reason: '$state fill must carry $mod');
        expect(s.fg, isNull, reason: 'no color survives NO_COLOR');
        expect(s.bg, isNull, reason: 'no color survives NO_COLOR');
      });
    }

    test('the cursor keeps its bold over the reversed fill', () {
      final s = resolve(WidgetState.cursor, PaintClass.fill);
      expect(s.addModifier.has(Modifier.reversed), isTrue);
      expect(s.addModifier.has(Modifier.bold), isTrue);
    });

    test('the border helper drops color but a focused border stays bold', () {
      final resting = resolver.border(const {});
      expect(resting.fg, isNull);
      final focused = resolver.border(const {WidgetState.focused});
      expect(focused.addModifier.has(Modifier.bold), isTrue);
      expect(focused.fg, isNull);
    });

    test('the color policy is unaffected — fills still carry their tone', () {
      final colorResolver = StyleResolver(Theme.dark, policy: RenderPolicy.color);
      final s = colorResolver.resolve(null, const {WidgetState.selected});
      expect(s.bg, equals(Theme.dark.selection.color));
      expect(s.addModifier.has(Modifier.reversed), isFalse);
    });

    test('defaultPolicy is color until the Application sets it', () {
      expect(StyleResolver.defaultPolicy, RenderPolicy.color);
    });
  });
}
