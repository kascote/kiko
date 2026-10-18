import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

Map<String, Theme> get _shipped => {
  'dark': Theme.dark,
  'catppuccin': Theme.catppuccin,
  'rosePine': Theme.rosePine,
  'gruvbox': Theme.gruvbox,
  'monokai': Theme.monokai,
  'nord': Theme.nord,
  'tokyoNight': Theme.tokyoNight,
  'oneDark': Theme.oneDark,
  'dracula': Theme.dracula,
  'solarized': Theme.solarized,
};

/// The checks each shipped theme fails and keeps, as `name: check`.
const _leftAlone = <String, List<String>>{
  'dark': ['secondary: ink on selection', 'error: ink on selection'],
  'catppuccin': ['error: ink on selection'],
  'rosePine': ['success: text on its fill', 'success: ink on selection'],
  'gruvbox': [
    'primary: ink on selection',
    'secondary: ink on selection',
    'accent: ink on selection',
    'error: ink on selection',
  ],
  'monokai': ['secondary: ink on selection', 'error: ink on selection'],
  'nord': [
    'secondary: text on its fill',
    'accent: text on its fill',
    'error: text on its fill',
    'secondary: ink on selection',
    'accent: ink on selection',
    'error: ink on surface',
    'error: ink on selection',
  ],
  'tokyoNight': [],
  'oneDark': [],
  'dracula': ['error: ink on selection'],
  'solarized': [
    'primary: text on its fill',
    'secondary: text on its fill',
    'accent: text on its fill',
    'error: text on its fill',
    'primary: ink on selection',
    'secondary: ink on surface',
    'secondary: ink on selection',
    'accent: ink on surface',
    'accent: ink on selection',
    'error: ink on surface',
    'error: ink on selection',
    'warning: ink on selection',
    'success: ink on selection',
  ],
};

double _worst(Color color, Theme theme) {
  final onBackground = color.contrastRatio(theme.background.color!);
  final onSurface = color.contrastRatio(theme.surface.color!);
  return onBackground < onSurface ? onBackground : onSurface;
}

void main() {
  group('deriveTheme on the shipped themes', () {
    for (final MapEntry(:key, value: theme) in _shipped.entries) {
      test('$key comes back unchanged with no replaced color', () {
        final (derived, report) = deriveTheme(theme);

        expect(report.changes, isEmpty);
        expect(report.hasChanges, isFalse);
        expect(derived, theme);
      });

      test('$key keeps exactly the failures it is known to keep', () {
        final (_, report) = deriveTheme(theme);

        expect([for (final kept in report.leftAlone) '${kept.name}: ${kept.check}'], _leftAlone[key]);
      });

      test('$key meets every rung target on both grounds', () {
        expect(_worst(theme.border.color!, theme), greaterThanOrEqualTo(ContrastTargets.border));
        expect(_worst(theme.disabled.color!, theme), greaterThanOrEqualTo(ContrastTargets.disabled));
        expect(_worst(theme.muted.color!, theme), greaterThanOrEqualTo(ContrastTargets.muted));
      });
    }
  });

  group('deriveTheme', () {
    // A dark theme whose three rungs all sit too close to the grounds.
    final failing = Theme.dark.copyWith(
      name: 'Failing',
      border: const Tone(color: Color.rgb(0x1a1f26)),
      muted: const Tone(color: Color.rgb(0x3a4048)),
      disabled: const Tone(color: Color.rgb(0x2a3038)),
    );

    test('gives a failing muted a color that reads at 4.5 on both grounds', () {
      final (derived, report) = deriveTheme(failing);

      expect(_worst(derived.muted.color!, derived), greaterThanOrEqualTo(4.5));
      final change = report.changes.singleWhere((c) => c.name == 'muted');
      expect(change.from, failing.muted.color);
      expect(change.to, derived.muted.color);
      expect(change.failedGrounds, ['background', 'surface']);
      expect(change.before, lessThan(4.5));
      expect(change.after, greaterThanOrEqualTo(4.5));
    });

    test('gives border and disabled colors that meet their targets', () {
      final (derived, report) = deriveTheme(failing);

      expect(_worst(derived.border.color!, derived), greaterThanOrEqualTo(1.5));
      expect(_worst(derived.disabled.color!, derived), greaterThanOrEqualTo(3));
      expect(report.changes.map((c) => c.name), unorderedEquals(['border', 'disabled', 'muted']));
    });

    test('is idempotent', () {
      final (once, _) = deriveTheme(failing);
      final (twice, report) = deriveTheme(once);

      expect(twice, once);
      expect(report.changes, isEmpty);
    });

    test('keeps the name, the roles and the de-emphasis', () {
      final (derived, _) = deriveTheme(failing.copyWith(deEmphasis: 0.3));

      expect(derived.name, 'Failing');
      expect(derived.primary, failing.primary);
      expect(derived.selection, failing.selection);
      expect(derived.deEmphasis, 0.3);
    });

    test('keeps the hue of the color it moves', () {
      final (derived, _) = deriveTheme(failing);

      final from = failing.muted.color!.toOklab();
      final to = derived.muted.color!.toOklab();
      expect(to.l, greaterThan(from.l));
      expect((to.a / to.chroma - from.a / from.chroma).abs(), lessThan(0.1));
      expect((to.b / to.chroma - from.b / from.chroma).abs(), lessThan(0.1));
    });

    test('moves a rung darker on a light theme', () {
      final light = Theme.dark.copyWith(
        background: const SurfaceTone(color: Color.rgb(0xfafafa), on: Color.rgb(0x202020)),
        surface: const SurfaceTone(color: Color.rgb(0xeeeeee), on: Color.rgb(0x202020)),
        muted: const Tone(color: Color.rgb(0xaaaaaa)),
      );

      final (derived, report) = deriveTheme(light);

      expect(derived.muted.color!.toOklab().l, lessThan(light.muted.color!.toOklab().l));
      expect(_worst(derived.muted.color!, derived), greaterThanOrEqualTo(4.5));
      expect(report.changes.map((c) => c.name), contains('muted'));
    });

    test('never changes a role color, and reports one that fails', () {
      final weak = Theme.dark.copyWith(
        error: const SurfaceTone(color: Color.rgb(0x2a1010), on: Color.rgb(0x302020)),
      );

      final (derived, report) = deriveTheme(weak);

      expect(derived.error, weak.error);
      final names = [for (final kept in report.leftAlone) '${kept.name}: ${kept.check}'];
      expect(names, containsAll(['error: text on its fill', 'error: ink on background', 'error: ink on surface']));
      final text = report.leftAlone.firstWhere((k) => k.check == 'text on its fill' && k.name == 'error');
      expect(text.target, ContrastTargets.onFill);
      expect(text.ratio, lessThan(ContrastTargets.onFill));
    });

    test('keeps the best color it found when no color meets the target', () {
      // No gray reads at 4.5 on both black and mid gray.
      final impossible = Theme.dark.copyWith(
        background: const SurfaceTone(color: Color.rgb(0x000000), on: Color.rgb(0xffffff)),
        surface: const SurfaceTone(color: Color.rgb(0x808080), on: Color.rgb(0xffffff)),
        muted: const Tone(color: Color.rgb(0x606060)),
      );

      final (derived, report) = deriveTheme(impossible);

      final change = report.changes.singleWhere((c) => c.name == 'muted');
      expect(change.after, lessThan(ContrastTargets.muted));
      expect(change.after, greaterThan(change.before));
      expect(derived.muted.color, change.to);
    });

    test('leaves a rung without a color alone', () {
      final bare = Theme.dark.copyWith(border: const Tone());

      final (derived, report) = deriveTheme(bare);

      expect(derived.border, const Tone());
      expect(report.changes, isEmpty);
    });
  });

  group('DerivationReport', () {
    test('prints a line per change and per kept failure', () {
      final failing = Theme.dark.copyWith(muted: const Tone(color: Color.rgb(0x3a4048)));

      final (_, report) = deriveTheme(failing);
      final text = report.toString();

      expect(text, contains('Changed 1 color'));
      expect(text, contains('muted #3a4048 reads'));
      expect(text, contains('on background and surface'));
      expect(text, contains('secondary ink on selection reads 2.67'));
      expect(text, contains('kept as published'));
    });

    test('says so when there is nothing to report', () {
      expect(const DerivationReport().toString(), 'No color changed.\nNo published color fails a check.');
    });

    test('compares by value', () {
      const change = RungChange(
        name: 'muted',
        from: Color.rgb(0x111111),
        to: Color.rgb(0x999999),
        failedGrounds: ['surface'],
        before: 2,
        after: 4.6,
        target: 4.5,
      );
      const kept = KeptFailure(name: 'error', check: 'ink on selection', ratio: 2, target: 3);

      expect(
        const DerivationReport(changes: [change], leftAlone: [kept]),
        const DerivationReport(changes: [change], leftAlone: [kept]),
      );
      expect(const DerivationReport(changes: [change]), isNot(const DerivationReport()));
      expect(const DerivationReport(changes: [change]).hashCode, const DerivationReport(changes: [change]).hashCode);
    });
  });

  group('Theme.system', () {
    const intents = ['primary', 'secondary', 'accent', 'error', 'warning', 'success'];
    SurfaceTone intent(Theme t, String name) => switch (name) {
      'primary' => t.primary,
      'secondary' => t.secondary,
      'accent' => t.accent,
      'error' => t.error,
      'warning' => t.warning,
      _ => t.success,
    };

    for (final (label, probe) in [
      ('a dark', const Color.rgb(0x1e1e2e)),
      ('a black', const Color.rgb(0x000000)),
      ('a light', const Color.rgb(0xfdf6e3)),
      ('a white', const Color.rgb(0xffffff)),
    ]) {
      test('over $label probed background every intent ink reads at 4.5 on both grounds', () {
        final theme = Theme.system(probe);

        for (final name in intents) {
          expect(_worst(intent(theme, name).color!, theme), greaterThanOrEqualTo(4.5), reason: name);
          final tone = intent(theme, name);
          expect(tone.on.contrastRatio(tone.color!), greaterThanOrEqualTo(3), reason: '$name on');
        }
        expect(_worst(theme.background.on, theme), greaterThanOrEqualTo(4.5));
        expect(theme.background.color, probe);
        expect(theme.name, 'System');
      });

      test('over $label probed background the rungs pass derivation unchanged', () {
        final theme = Theme.system(probe);

        final (derived, report) = deriveTheme(theme);

        expect(report.changes, isEmpty);
        expect(derived, theme);
      });
    }

    test('lifts the surface lighter on a dark background and darker on a light one', () {
      final dark = Theme.system(const Color.rgb(0x1e1e2e));
      final light = Theme.system(const Color.rgb(0xfdf6e3));

      final darkGap = dark.surface.color!.toOklab().l - dark.background.color!.toOklab().l;
      final lightGap = light.surface.color!.toOklab().l - light.background.color!.toOklab().l;
      expect(darkGap, closeTo(Theme.step, 0.01));
      expect(lightGap, closeTo(-Theme.step, 0.01));
    });

    test('puts the selection two steps from the background', () {
      final dark = Theme.system(const Color.rgb(0x1e1e2e));
      final light = Theme.system(const Color.rgb(0xfdf6e3));

      expect(dark.selection.color!.toOklab().l - dark.background.color!.toOklab().l, closeTo(2 * Theme.step, 0.01));
      expect(light.selection.color!.toOklab().l - light.background.color!.toOklab().l, closeTo(-2 * Theme.step, 0.01));
    });

    test('keeps the intent hues of Theme.dark', () {
      final theme = Theme.system(const Color.rgb(0xfdf6e3));

      final from = Theme.dark.error.color!.toOklab();
      final to = theme.error.color!.toOklab();
      expect((to.a / to.chroma - from.a / from.chroma).abs(), lessThan(0.1));
      expect((to.b / to.chroma - from.b / from.chroma).abs(), lessThan(0.1));
    });

    test('falls back to Theme.dark when the probe never answered', () {
      expect(Theme.system(null), Theme.dark);
    });
  });
}
