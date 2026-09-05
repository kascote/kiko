import 'package:meta/meta.dart';

import 'ansi16_tones.dart';
import 'cell.dart';
import 'colors.dart';
import 'style.dart';
import 'theme.dart';
import 'tone.dart';
import 'widget_state.dart';

/// How a tone lands as paint on a given part.
///
/// States pick tones; the call site picks a paint class. The same tone through
/// two classes is how a selected pane border ([ink]) and a selected row
/// ([fill]) share one color without the border dragging a background.
enum PaintClass {
  /// Foreground only — line glyphs, separators, accent text.
  ink,

  /// A filled surface — the tone's `on` over its `color` — selected rows,
  /// button faces.
  fill,

  /// Background only — tints existing content, preserving its foreground.
  wash,
}

/// Whether the resolver may use color, must re-express meaning without it, or
/// must re-express it through a fixed 16-color palette.
///
/// Under [noColor] (a `NO_COLOR` terminal) color fidelity is not a downgrade
/// but a *semantic* gap: a selection whose whole identity is its background
/// becomes invisible, not merely dimmer. The re-expression happens here, at the
/// projection — the one place that still knows the intent — so widgets never
/// know: a `fill` degrades to [Modifier.reversed], an `ink` keeps its modifiers
/// but drops its foreground, and a `wash` (a tint that cannot exist without
/// color) degrades to nothing.
///
/// Under [ansi16] color survives, but only through sixteen named slots
/// instead of free RGB: `ink`/`fill` paint through the theme's
/// [Theme.tones16] table (hand-authored, or derived once via
/// [Ansi16Tones.derive]) instead of its RGB tones, and a `wash` still drops
/// entirely — the 16-name vocabulary has no subtle tints to spend on one.
enum RenderPolicy {
  /// Colors render as themed, in full RGB.
  color,

  /// Colors are dropped; meaning survives through modifiers alone.
  noColor,

  /// Colors render through the theme's named ANSI-16 table instead of RGB;
  /// washes drop, same as [noColor].
  ansi16,
}

/// Resolves a [Style] from a [Theme], active [WidgetState]s, and a [PaintClass].
///
/// This is the single place the built-in look lives: for each active tone
/// state, in priority order, it patches the state's contribution for the
/// requested paint class onto a base style. Tone states pick tones from the
/// theme; the [PaintClass] decides how each tone lands, so the same state
/// looks right on chrome, on a surface, or as a tint without any per-widget
/// code. [WidgetState.hover] and [WidgetState.pressed] are not in that
/// matrix: they transform the patched result afterward, hover then pressed.
///
/// ```dart
/// final resolver = StyleResolver(theme);
/// final rowStyle = resolver.resolve(base, {WidgetState.selected});
/// final borderStyle = resolver.border({if (m.focused) WidgetState.focused});
/// ```
@immutable
class StyleResolver {
  /// The process-wide policy new resolvers adopt when none is passed.
  ///
  /// A `NO_COLOR` fact is set once, at startup, for the whole process, and the
  /// theme is app-owned — so widgets construct `StyleResolver(theme)` without
  /// threading a policy through. `Application` sets this from the terminal's
  /// color profile before the first frame; tests that need a specific policy
  /// pass [policy] explicitly or set this directly.
  static RenderPolicy defaultPolicy = RenderPolicy.color;

  /// The theme used for built-in state defaults.
  final Theme theme;

  /// How tones become paint — full color, the [RenderPolicy.noColor]
  /// modifier-only re-expression, or the [RenderPolicy.ansi16] named palette.
  final RenderPolicy policy;

  /// The tone set the state matrix actually reads from.
  ///
  /// [theme] itself under [RenderPolicy.color] and [RenderPolicy.noColor];
  /// under [RenderPolicy.ansi16] this is [Theme.tones16] if the theme
  /// hand-authored one, otherwise an [Ansi16Tones] table derived once and
  /// cached. Resolved a single time here, at construction, so the matrix
  /// below reads one shape and never branches per state on which kind of
  /// tone it is holding.
  final ToneSet tones;

  /// Creates a resolver backed by [theme].
  ///
  /// [policy] defaults to [defaultPolicy] (the process-wide value set by
  /// `Application` from the terminal profile), so a widget never has to know or
  /// pass it.
  StyleResolver(this.theme, {RenderPolicy? policy})
    : policy = policy ?? defaultPolicy,
      tones = _tonesFor(theme, policy ?? defaultPolicy);

  static ToneSet _tonesFor(Theme theme, RenderPolicy policy) =>
      policy == RenderPolicy.ansi16 ? (theme.tones16 ?? Ansi16Tones.derive(theme)) : theme;

  /// Resolves a [Style] by applying state styles on top of [base].
  ///
  /// 1. Starts with [base] (or an empty style if null).
  /// 2. Walks the tone states — every value but [WidgetState.hover] and
  ///    [WidgetState.pressed] — in priority order ([WidgetState.values]
  ///    declaration order). For each active one, uses the [overrides] entry
  ///    if present, else the built-in default for that state and [cls].
  ///    States whose row is empty for [cls] contribute nothing (unless
  ///    overridden). Patches each contribution via [Style.patch], so later
  ///    (higher-priority) states win.
  /// 3. If [WidgetState.hover] is active: patches its [overrides] entry if
  ///    present; otherwise, under [RenderPolicy.color], lifts a background by
  ///    [Theme.hoverLift] or, on a result with none, patches the hover wash.
  /// 4. If [WidgetState.pressed] is active: patches its [overrides] entry if
  ///    present; otherwise inverts the result, or, under
  ///    [RenderPolicy.noColor], flips the [Modifier.reversed] modifier.
  ///
  /// [cls] defaults to [PaintClass.fill] — the surface case most callers want.
  Style resolve(
    Style? base,
    Set<WidgetState> states, {
    PaintClass cls = PaintClass.fill,
    Map<WidgetState, Style>? overrides,
  }) {
    var result = base ?? const Style();
    if (states.isEmpty && (overrides == null || overrides.isEmpty)) return result;

    for (final state in WidgetState.values) {
      if (!states.contains(state)) continue;
      if (state == WidgetState.hover || state == WidgetState.pressed) continue;

      final Style? contribution;
      if (overrides != null && overrides.containsKey(state)) {
        contribution = overrides[state];
      } else {
        contribution = _cell(state, cls);
      }
      if (contribution != null) result = result.patch(contribution);
    }

    if (states.contains(WidgetState.hover)) {
      final hoverOverride = overrides?[WidgetState.hover];
      if (hoverOverride != null) {
        result = result.patch(hoverOverride);
      } else if (policy == RenderPolicy.color) {
        final bg = result.bg;
        result = bg != null && bg != Color.reset
            ? result.copyWith(bg: bg.lift(Theme.hoverLift))
            : result.patch(wash(theme.hover));
      }
    }

    if (states.contains(WidgetState.pressed)) {
      final pressedOverride = overrides?[WidgetState.pressed];
      if (pressedOverride != null) {
        result = result.patch(pressedOverride);
      } else {
        result = switch (policy) {
          RenderPolicy.color || RenderPolicy.ansi16 => result.inverted,
          RenderPolicy.noColor =>
            result.addModifier.has(Modifier.reversed)
                ? result.removeModifier(Modifier.reversed)
                : result.incModifier(Modifier.reversed),
        };
      }
    }

    return result;
  }

  /// Border style for a set of [states] — the fix for hand-rolled
  /// `focused ? theme.focus : theme.border` at every call site.
  ///
  /// Resolves over the resting border tone as [PaintClass.ink], so a state can
  /// tint the border foreground but never flood a background onto its glyphs.
  Style border(Set<WidgetState> states) => resolve(ink(tones.border), states, cls: PaintClass.ink);

  /// Projects a tone as foreground-only ink, or drops the color under
  /// [RenderPolicy.noColor] (modifiers added by the caller still ride on top).
  ///
  /// Read [tone] from [tones], not from the theme: the projection itself does
  /// nothing extra under [RenderPolicy.ansi16], so only a tone from the
  /// active set paints as its named-ANSI value. The raw `tone.ink` bypasses
  /// the policy entirely — use these projections for content that must
  /// degrade with the rest of the screen.
  Style ink(Tone tone) => policy == RenderPolicy.noColor ? const Style() : tone.ink;

  /// Projects a tone as a filled surface, or degrades it to [Modifier.reversed]
  /// under [RenderPolicy.noColor] so the surface stays distinguishable once its
  /// color is stripped.
  ///
  /// Read [tone] from [tones] — see [ink]. Only a [SurfaceTone] can fill: the
  /// compiler rejects a chrome tone here, since it has no `on` to paint.
  Style fill(SurfaceTone tone) =>
      policy == RenderPolicy.noColor ? const Style(addModifier: Modifier.reversed) : tone.fill;

  /// Projects a tone as a background wash, or drops it entirely under
  /// [RenderPolicy.noColor] or [RenderPolicy.ansi16] — a wash cannot exist
  /// without color, and the 16-name vocabulary has no subtle tint to spend on
  /// one either.
  Style wash(Tone tone) => policy == RenderPolicy.noColor || policy == RenderPolicy.ansi16 ? const Style() : tone.wash;

  /// Projects a tone as the ground of an area — the style its cells hold
  /// before content paints on them.
  ///
  /// Set this once per area, then paint content on top with a half-null
  /// [Style]; the unset half inherits the ground already in the cell, because
  /// [Cell.setCell] and [Cell.setStyle] patch a cell rather than replace it.
  /// Read [tone] from [tones] — see [ink]. Only a [SurfaceTone] can ground an
  /// area, for the same reason only one can fill.
  ///
  /// In full RGB this is the same style as [fill]. The two projections part
  /// ways only in how they degrade: under [RenderPolicy.ansi16] a ground
  /// keeps only its foreground, leaving the terminal's own background to show
  /// through; under [RenderPolicy.noColor] it carries no color at all.
  Style ground(SurfaceTone tone) => switch (policy) {
    RenderPolicy.color => Style(fg: tone.on, bg: tone.color),
    RenderPolicy.ansi16 => Style(fg: tone.on),
    RenderPolicy.noColor => const Style(),
  };

  /// The built-in state × class matrix.
  ///
  /// Returns the style a single [state] contributes for [cls], or `null` when
  /// that state does not affect that paint class. This table is the built-in
  /// look of kiko; modifiers ride on top of the projection.
  ///
  /// [resolve] never calls this with [WidgetState.hover] or
  /// [WidgetState.pressed]: it applies both as transforms after the matrix,
  /// not as matrix cells.
  Style? _cell(WidgetState state, PaintClass cls) {
    switch (state) {
      case WidgetState.hover:
      case WidgetState.pressed:
        return null;

      case WidgetState.selected:
        return switch (cls) {
          PaintClass.ink => ink(tones.selection),
          PaintClass.fill => fill(tones.selection),
          PaintClass.wash => wash(tones.selection),
        };

      case WidgetState.cursor:
        return switch (cls) {
          PaintClass.ink => null,
          PaintClass.fill => fill(tones.cursor).incModifier(Modifier.bold),
          PaintClass.wash => wash(tones.cursor),
        };

      case WidgetState.focused:
        return switch (cls) {
          PaintClass.ink => ink(tones.focus).incModifier(Modifier.bold),
          PaintClass.fill => fill(tones.focus).incModifier(Modifier.bold),
          PaintClass.wash => null,
        };

      case WidgetState.loading:
        return switch (cls) {
          PaintClass.ink || PaintClass.fill => ink(tones.warning).incModifier(Modifier.slowBlink),
          PaintClass.wash => null,
        };

      case WidgetState.error:
        return switch (cls) {
          PaintClass.ink => ink(tones.error),
          PaintClass.fill => fill(tones.error),
          PaintClass.wash => wash(tones.error),
        };

      case WidgetState.disabled:
        return switch (cls) {
          PaintClass.ink || PaintClass.fill => ink(tones.disabled).incModifier(Modifier.dim),
          PaintClass.wash => null,
        };
    }
  }
}
