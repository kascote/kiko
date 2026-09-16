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
/// This is the single place the built-in look lives. [WidgetState.selected],
/// [WidgetState.loading] and [WidgetState.error] patch one matrix cell each,
/// in priority order, onto a base style; the [PaintClass] decides how each
/// tone lands, so the same state looks right on chrome, on a surface, or as a
/// tint without any per-widget code. [WidgetState.cursor],
/// [WidgetState.focused] and [WidgetState.disabled] are not in that matrix:
/// they transform the patched result afterward, in that order, so a state
/// that lands on a colored base lifts or blends it instead of replacing it.
/// [WidgetState.hover] and [WidgetState.pressed] transform last, and do
/// nothing once [WidgetState.disabled] is active. A theme picks the colors
/// every step reads; the resolver itself picks every modifier, including
/// [Theme.hoverLift].
///
/// A `slots` argument on [resolve] lets a widget hand in an authored style
/// for one state — a widget's own cursor-row slot, say —
/// which replaces the theme's own contribution for that state without
/// touching any other.
///
/// ```dart
/// final resolver = StyleResolver(theme);
/// final rowStyle = resolver.resolve(base, {WidgetState.selected}, cls: PaintClass.fill);
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
  /// 2. Walks [WidgetState.selected], [WidgetState.loading] and
  ///    [WidgetState.error] in declaration order. For each active one,
  ///    patches [slots] for that state, or the built-in matrix cell for that
  ///    state and [cls] when there is no slot. States whose cell is empty for
  ///    [cls] contribute nothing.
  /// 3. If [WidgetState.cursor] is active: lifts a colored result or patches
  ///    [slots] for [WidgetState.cursor] (or the built-in cursor fallback) on
  ///    a bare one — see [_liftOrFallback]. Adds bold in [PaintClass.fill].
  /// 4. If [WidgetState.focused] is active: the same lift-or-fallback in
  ///    [PaintClass.fill], with bold. In [PaintClass.ink] the focus ink plus
  ///    bold patches in step 2 instead, at the state's declaration position,
  ///    so an error ink still wins over it on chrome.
  /// 5. If [WidgetState.disabled] is active: blends a filled result toward
  ///    the ground and adds dim, or swaps in the disabled ink on a bare one.
  ///    Ends the chain: steps 6 and 7 are skipped.
  /// 6. Otherwise, if [WidgetState.hover] is active: lifts a background by
  ///    [Theme.hoverLift] or, on a result with none, patches the hover wash.
  /// 7. Otherwise, if [WidgetState.pressed] is active: inverts the result, or,
  ///    under [RenderPolicy.noColor], flips the [Modifier.reversed] modifier.
  ///
  /// [cls] names the paint class the call site paints — the part picks the
  /// projection, so there is no default. [slots] carries per-state authored
  /// styles: a widget's own row/item/cell style for a state, keyed by that
  /// state. A slot for [WidgetState.selected], [WidgetState.loading] or
  /// [WidgetState.error] replaces its matrix cell; a slot for
  /// [WidgetState.cursor] or [WidgetState.focused] replaces the fallback used
  /// on a bare base and is ignored on a colored one. Slots for any other
  /// state are ignored.
  Style resolve(
    Style? base,
    Set<WidgetState> states, {
    required PaintClass cls,
    Map<WidgetState, Style> slots = const {},
  }) {
    var result = base ?? const Style();
    if (states.isEmpty) return result;

    result = _applyMatrix(result, states, cls, slots);
    if (states.contains(WidgetState.cursor)) {
      result = _applyCursor(result, cls, slots[WidgetState.cursor]);
    }
    if (states.contains(WidgetState.focused)) {
      result = _applyFocus(result, cls, slots[WidgetState.focused]);
    }
    if (states.contains(WidgetState.disabled)) return _applyDisabled(result, cls);
    if (states.contains(WidgetState.hover)) result = _applyHover(result);
    if (states.contains(WidgetState.pressed)) result = _applyPressed(result);
    return result;
  }

  /// Walks the matrix cells of [states] in declaration order and patches each
  /// contribution — a slot or the [_cell] — onto [base].
  ///
  /// In the ink class, focused stays a matrix cell at its declaration
  /// position: chrome keeps error ink over focus ink, as an ink has no
  /// background to lift.
  Style _applyMatrix(Style base, Set<WidgetState> states, PaintClass cls, Map<WidgetState, Style> slots) {
    var result = base;
    for (final state in WidgetState.values) {
      if (!states.contains(state)) continue;
      if (state == WidgetState.focused && cls == PaintClass.ink) {
        result = result.patch(slots[state] ?? ink(tones.focus)).incModifier(Modifier.bold);
        continue;
      }
      if (!_matrixStates.contains(state)) continue;

      final contribution = slots[state] ?? _cell(state, cls);
      if (contribution != null) result = result.patch(contribution);
    }
    return result;
  }

  /// The [WidgetState.cursor] transform for [cls]: a lift on a colored
  /// [result], or [slot] (else the cursor tone) on a bare one.
  ///
  /// A fill also gains bold. An ink has no cursor contribution.
  Style _applyCursor(Style result, PaintClass cls, Style? slot) => switch (cls) {
    PaintClass.fill => _liftOrFallback(result, slot ?? fill(tones.cursor)).incModifier(Modifier.bold),
    PaintClass.wash => _liftOrFallback(result, slot ?? wash(tones.cursor)),
    PaintClass.ink => result,
  };

  /// The [WidgetState.focused] transform for [cls]: a lift on a colored fill,
  /// or [slot] (else the focus tone) plus bold on a bare one.
  ///
  /// An ink resolved focus as a matrix cell in [_applyMatrix]; a wash has no
  /// focus contribution.
  Style _applyFocus(Style result, PaintClass cls, Style? slot) => switch (cls) {
    PaintClass.fill => _liftOrFallback(result, slot ?? fill(tones.focus)).incModifier(Modifier.bold),
    PaintClass.ink || PaintClass.wash => result,
  };

  /// The [WidgetState.pressed] transform: inverts [result], or, under
  /// [RenderPolicy.noColor], flips the [Modifier.reversed] modifier.
  Style _applyPressed(Style result) => switch (policy) {
    RenderPolicy.color || RenderPolicy.ansi16 => result.inverted,
    RenderPolicy.noColor =>
      result.addModifier.has(Modifier.reversed)
          ? result.removeModifier(Modifier.reversed)
          : result.incModifier(Modifier.reversed),
  };

  /// The states [resolve] still walks as matrix cells, in priority order.
  static const Set<WidgetState> _matrixStates = {
    WidgetState.selected,
    WidgetState.loading,
    WidgetState.error,
  };

  /// Lifts [color] toward the ground, or brightens it under [RenderPolicy.ansi16].
  ///
  /// Under [RenderPolicy.ansi16] a lift always brightens: darkening an ANSI
  /// slot can leave it unchanged, which would hide the step. Under
  /// [RenderPolicy.color] the ground decides direction — `tones.background`'s
  /// color lightens when dark (or absent) and darkens when light — so a
  /// second lift continues the first instead of reversing it. Never called
  /// under [RenderPolicy.noColor].
  Color _lift(Color color, double amount) {
    if (policy == RenderPolicy.ansi16) return color.lighten(amount);
    final ground = tones.background.color;
    final dark = ground == null || ground.luminance < 0.5;
    return dark ? color.lighten(amount) : color.darken(amount);
  }

  /// Lifts a colored [result] by [Theme.stateLift], or patches [fallback] onto a
  /// bare one.
  ///
  /// [result] is bare when its `bg` is null or [Color.reset]. A bare result
  /// patches [fallback] and keeps whatever modifiers [result] already
  /// carries — including a [RenderPolicy.noColor] reversed fill. A result
  /// with a background lifts it through [_lift] and keeps `fg`, except under
  /// [RenderPolicy.noColor], where nothing can lift without color and
  /// [result] is returned unchanged.
  Style _liftOrFallback(Style result, Style fallback) {
    final bg = result.bg;
    if (bg == null || bg == Color.reset) return result.patch(fallback);
    if (policy == RenderPolicy.noColor) return result;
    return result.copyWith(bg: _lift(bg, Theme.stateLift));
  }

  /// The [WidgetState.disabled] transform for [cls].
  ///
  /// A wash is left as it is — disabled has no wash contribution. An ink
  /// keeps today's swap to the disabled tone plus dim, whatever [result]
  /// carries. A fill on a bare [result] does the same swap plus dim; a fill
  /// on a colored one blends `fg` and `bg` toward the ground by
  /// [Theme.disabledMix] under [RenderPolicy.color] with a ground color, or adds
  /// dim alone otherwise (ansi16, noColor, or a themeless ground).
  Style _applyDisabled(Style result, PaintClass cls) {
    switch (cls) {
      case PaintClass.wash:
        return result;

      case PaintClass.ink:
        return result.patch(ink(tones.disabled)).incModifier(Modifier.dim);

      case PaintClass.fill:
        final bg = result.bg;
        if (bg == null || bg == Color.reset) {
          return result.patch(ink(tones.disabled)).incModifier(Modifier.dim);
        }

        final ground = tones.background.color;
        if (policy == RenderPolicy.color && ground != null) {
          final fg = result.fg;
          return result
              .copyWith(fg: fg?.mix(ground, Theme.disabledMix), bg: bg.mix(ground, Theme.disabledMix))
              .incModifier(Modifier.dim);
        }
        return result.incModifier(Modifier.dim);
    }
  }

  /// The [WidgetState.hover] transform, shared across every [PaintClass].
  ///
  /// A colored [result] lifts its background by [Theme.hoverLift] through
  /// [_lift] under [RenderPolicy.color] and [RenderPolicy.ansi16]; under
  /// [RenderPolicy.noColor] it is left unchanged. A bare [result] patches the
  /// hover wash, which already drops under [RenderPolicy.ansi16] and
  /// [RenderPolicy.noColor].
  Style _applyHover(Style result) {
    final bg = result.bg;
    if (bg != null && bg != Color.reset) {
      return policy == RenderPolicy.noColor ? result : result.copyWith(bg: _lift(bg, Theme.hoverLift));
    }
    return result.patch(wash(theme.hover));
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
  /// [resolve] only calls this with [_matrixStates]: [WidgetState.cursor],
  /// [WidgetState.focused], [WidgetState.disabled], [WidgetState.hover] and
  /// [WidgetState.pressed] are transforms over the patched result instead,
  /// not matrix cells, so they always return `null` here.
  Style? _cell(WidgetState state, PaintClass cls) {
    switch (state) {
      case WidgetState.hover:
      case WidgetState.cursor:
      case WidgetState.focused:
      case WidgetState.pressed:
      case WidgetState.disabled:
        return null;

      case WidgetState.selected:
        return switch (cls) {
          PaintClass.ink => ink(tones.selection),
          PaintClass.fill => fill(tones.selection),
          PaintClass.wash => wash(tones.selection),
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
    }
  }
}
