import 'package:meta/meta.dart';

import 'style.dart';
import 'theme.dart';
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
  /// The theme used for built-in state defaults.
  final Theme theme;

  /// Creates a resolver backed by [theme].
  const StyleResolver(this.theme);

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
  Style border(Set<WidgetState> states) => resolve(theme.border.ink, states, cls: PaintClass.ink);

  /// The built-in state × class matrix.
  ///
  /// Returns the style a single [state] contributes for [cls], or `null` when
  /// that state does not affect that paint class. This table is the built-in
  /// look of kiko; modifiers ride on top of the projection.
  Style? _cell(WidgetState state, PaintClass cls) {
    switch (state) {
      case WidgetState.hover:
        return cls == PaintClass.wash ? theme.hover.wash : null;

      case WidgetState.selected:
        return switch (cls) {
          PaintClass.ink => theme.selection.ink,
          PaintClass.fill => theme.selection.fill,
          PaintClass.wash => theme.selection.wash,
        };

      case WidgetState.cursor:
        return switch (cls) {
          PaintClass.ink => null,
          PaintClass.fill => theme.cursor.fill.incModifier(Modifier.bold),
          PaintClass.wash => theme.cursor.wash,
        };

      case WidgetState.focused:
        return switch (cls) {
          PaintClass.ink => theme.focus.ink.incModifier(Modifier.bold),
          PaintClass.fill => theme.focus.fill.incModifier(Modifier.bold),
          PaintClass.wash => null,
        };

      case WidgetState.unfocused:
        return switch (cls) {
          PaintClass.ink => theme.muted.ink,
          PaintClass.fill => theme.muted.ink.patch(theme.surface.wash),
          PaintClass.wash => null,
        };

      case WidgetState.loading:
        return switch (cls) {
          PaintClass.ink || PaintClass.fill => theme.warning.ink.incModifier(Modifier.slowBlink),
          PaintClass.wash => null,
        };

      case WidgetState.error:
        return switch (cls) {
          PaintClass.ink => theme.error.ink,
          PaintClass.fill => theme.error.fill,
          PaintClass.wash => theme.error.wash,
        };

      case WidgetState.disabled:
        return switch (cls) {
          PaintClass.ink || PaintClass.fill => theme.disabled.ink.incModifier(Modifier.dim),
          PaintClass.wash => null,
        };
    }
  }
}
