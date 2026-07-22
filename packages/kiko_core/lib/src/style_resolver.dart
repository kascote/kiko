import 'package:meta/meta.dart';

import 'ansi16_tones.dart';
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
/// This is the single place the built-in look lives: for each active state, in
/// priority order, it patches the state's contribution for the requested paint
/// class onto a base style. States pick tones from the theme; the [PaintClass] decides
/// how each tone lands, so the same state looks right on chrome, on a surface,
/// or as a tint without any per-widget code.
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
  /// 2. Walks [WidgetState.values] (declaration = priority order).
  /// 3. For each active state, uses the [overrides] entry if present, else the
  ///    built-in default for that state and [cls]. States whose row is empty
  ///    for [cls] contribute nothing (unless overridden).
  /// 4. Patches each contribution via [Style.patch], so later (higher-priority)
  ///    states win.
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

      final Style? contribution;
      if (overrides != null && overrides.containsKey(state)) {
        contribution = overrides[state];
      } else {
        contribution = _cell(state, cls);
      }
      if (contribution != null) result = result.patch(contribution);
    }

    return result;
  }

  /// Border style for a set of [states] — the fix for hand-rolled
  /// `focused ? theme.focus : theme.border` at every call site.
  ///
  /// Resolves over the resting border tone as [PaintClass.ink], so a state can
  /// tint the border foreground but never flood a background onto its glyphs.
  Style border(Set<WidgetState> states) => resolve(_ink(tones.border), states, cls: PaintClass.ink);

  /// Projects a tone as foreground-only ink, or drops the color under
  /// [RenderPolicy.noColor] (modifiers added by the caller still ride on top).
  ///
  /// Under [RenderPolicy.ansi16] this is unchanged: [tone] already comes from
  /// [tones], the resolver's active (named-ANSI) tone set, so the projection
  /// itself has nothing extra to do.
  Style _ink(Tone tone) => policy == RenderPolicy.noColor ? const Style() : tone.ink;

  /// Projects a tone as a filled surface, or degrades it to [Modifier.reversed]
  /// under [RenderPolicy.noColor] so the surface stays distinguishable once its
  /// color is stripped.
  ///
  /// Under [RenderPolicy.ansi16] this is unchanged, for the same reason as
  /// [_ink]: [tone] is already the named-ANSI value.
  Style _fill(Tone tone) => policy == RenderPolicy.noColor ? const Style(addModifier: Modifier.reversed) : tone.fill;

  /// Projects a tone as a background wash, or drops it entirely under
  /// [RenderPolicy.noColor] or [RenderPolicy.ansi16] — a wash cannot exist
  /// without color, and the 16-name vocabulary has no subtle tint to spend on
  /// one either.
  Style _wash(Tone tone) => policy == RenderPolicy.noColor || policy == RenderPolicy.ansi16 ? const Style() : tone.wash;

  /// The built-in state × class matrix.
  ///
  /// Returns the style a single [state] contributes for [cls], or `null` when
  /// that state does not affect that paint class. This table is the built-in
  /// look of kiko; modifiers ride on top of the projection.
  Style? _cell(WidgetState state, PaintClass cls) {
    switch (state) {
      case WidgetState.hover:
        // hover has no ANSI-16 slot (Ansi16Tones carries no hover entry) —
        // harmless, because it only ever reaches _wash, and _wash drops the
        // tone before touching it under ansi16 (same as noColor).
        return cls == PaintClass.wash ? _wash(theme.hover) : null;

      case WidgetState.selected:
        return switch (cls) {
          PaintClass.ink => _ink(tones.selection),
          PaintClass.fill => _fill(tones.selection),
          PaintClass.wash => _wash(tones.selection),
        };

      case WidgetState.cursor:
        return switch (cls) {
          PaintClass.ink => null,
          PaintClass.fill => _fill(tones.cursor).incModifier(Modifier.bold),
          PaintClass.wash => _wash(tones.cursor),
        };

      case WidgetState.focused:
        return switch (cls) {
          PaintClass.ink => _ink(tones.focus).incModifier(Modifier.bold),
          PaintClass.fill => _fill(tones.focus).incModifier(Modifier.bold),
          PaintClass.wash => null,
        };

      case WidgetState.unfocused:
        return switch (cls) {
          PaintClass.ink => _ink(tones.muted),
          PaintClass.fill => _ink(tones.muted).patch(_wash(tones.surface)),
          PaintClass.wash => null,
        };

      case WidgetState.loading:
        return switch (cls) {
          PaintClass.ink || PaintClass.fill => _ink(tones.warning).incModifier(Modifier.slowBlink),
          PaintClass.wash => null,
        };

      case WidgetState.error:
        return switch (cls) {
          PaintClass.ink => _ink(tones.error),
          PaintClass.fill => _fill(tones.error),
          PaintClass.wash => _wash(tones.error),
        };

      case WidgetState.disabled:
        return switch (cls) {
          PaintClass.ink || PaintClass.fill => _ink(tones.disabled).incModifier(Modifier.dim),
          PaintClass.wash => null,
        };
    }
  }
}
