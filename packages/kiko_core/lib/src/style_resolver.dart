import 'package:meta/meta.dart';

import 'style.dart';
import 'theme.dart';
import 'widget_state.dart';

/// Resolves a [Style] from a [Theme], active [WidgetState]s, and optional
/// per-state overrides.
///
/// Centralizes the state→style mapping that every widget needs.
///
/// ```dart
/// final resolver = StyleResolver(theme);
/// final style = resolver.resolve(
///   baseStyle,
///   {WidgetState.focused, WidgetState.selected},
/// );
/// ```
@immutable
class StyleResolver {
  /// The theme used for built-in state defaults.
  final Theme theme;

  /// Creates a resolver backed by [theme].
  const StyleResolver(this.theme);

  /// Resolves a [Style] by applying state styles on top of [base].
  ///
  /// 1. Starts with [base] (or empty style if null).
  /// 2. Sorts active [states] by priority (enum index).
  /// 3. For each state: uses [overrides] entry if provided, else built-in
  ///    default from [theme].
  /// 4. Applies each via [Style.patch].
  ///
  /// Special rules:
  /// - `hover` is skipped when `focused` is also active.
  /// - `disabled` has highest priority and overrides all visual states.
  Style resolve(
    Style? base,
    Set<WidgetState> states, {
    Map<WidgetState, Style>? overrides,
  }) {
    if (states.isEmpty) return base ?? const Style();

    var result = base ?? const Style();

    final skipHover = states.contains(WidgetState.hover) && states.contains(WidgetState.focused);

    // Iterate enum declaration order (= priority order), no allocation.
    for (final state in WidgetState.values) {
      if (!states.contains(state)) continue;
      if (state == WidgetState.hover && skipHover) continue;

      final stateStyle = overrides != null && overrides.containsKey(state)
          ? overrides[state]!
          : _defaultStyle(state, result);

      result = result.patch(stateStyle);
    }

    return result;
  }

  /// Built-in default style for [state] derived from [theme].
  Style _defaultStyle(WidgetState state, Style current) {
    return switch (state) {
      WidgetState.hover => Style(bg: current.bg?.lighten(0.08)),
      WidgetState.focused => theme.focus,
      WidgetState.selected => theme.highlight,
      WidgetState.unfocused => Style(
        fg: theme.muted.fg,
        bg: theme.surface.bg,
      ),
      WidgetState.disabled => theme.disabled,
      WidgetState.loading => Style(
        fg: theme.warning.fg,
        addModifier: Modifier.slowBlink,
      ),
      WidgetState.error => Style(fg: theme.error.fg),
    };
  }
}
