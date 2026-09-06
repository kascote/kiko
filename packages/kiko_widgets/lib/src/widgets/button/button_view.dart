import 'package:kiko/kiko.dart';

import 'button_model.dart';
import 'types.dart';

/// A button as a view — the plume-native view for [ButtonModel].
///
/// A button is a single filled row: the resolved style paints the whole width,
/// the label sits inside a symmetric horizontal [ButtonModel.padding], and the
/// built subtree is stamped with the model's id so a click resolves back to it
/// through [HitMap.hitId]. Styles come from the [theme], [style], and the
/// model's state (hover / focused / disabled / loading / pressed) through the
/// built-in matrix. A per-instance state look is a theme variant passed to
/// [theme].
///
/// The content area is sized to the larger of [ButtonModel.label] and
/// [ButtonModel.loadingText]: both are laid out every frame, but only the
/// active one paints — the other sits offstage, still voting on the size. The
/// button's width is therefore fixed from the first frame and never changes
/// when loading toggles, and neither piece of content is ever truncated to fit
/// the other's width.
///
/// The resting face is [ButtonStyle.face]. A null face derives
/// `resolver.fill(primary)` — a button is a primary action by default. Its
/// states then ride the built-in state × class matrix (via [StyleResolver]):
/// focused → `resolver.fill(focus)` + bold, loading → warning ink + slow
/// blink, disabled → dim. The face paints as the row's ground, so
/// [ButtonModel.label] and [ButtonModel.loadingText] paint over it: a label
/// with its own foreground keeps it on the face, in any state.
final class Button implements View {
  /// Creates a button over [model], styled by [theme].
  const Button({required this.model, required this.theme, this.style = const ButtonStyle()});

  /// The model whose label, state, and padding this view renders.
  final ButtonModel model;

  /// The theme that resolves the button's styles.
  final Theme theme;

  /// Per-part style overrides. See [ButtonStyle].
  final ButtonStyle style;

  @override
  Node build() {
    final resolvedStyle = _resolveStyle(model, theme, style);
    final label = model.label;
    final loadingText = model.loadingText;
    // Both are laid out every frame, so the stack always sizes to the larger
    // of the two; only the active one paints, the other sits offstage. The
    // stack's default top-left alignment is what start-aligns the shorter
    // content, matching how the label used to sit against the padding.
    final content = Stack(
      children: [
        if (model.loading) Offstage(child: label) else label,
        if (model.loading) loadingText else Offstage(child: loadingText),
      ],
    );

    return Container(
      ground: resolvedStyle,
      padding: EdgeInsets.symmetric(horizontal: model.padding),
      child: content,
    ).build()..tag = IdTag(model.id);
  }
}

/// Resolves the button style from the theme, [style]'s face, and the model's
/// active states: [ButtonStyle.face] is the resting face,
/// `resolver.fill(primary)` when null, with the state contributions coming
/// straight from the built-in matrix, so a focused button lights up in the
/// focus tone and a loading one blinks over any face.
Style _resolveStyle(ButtonModel model, Theme theme, ButtonStyle style) {
  final resolver = StyleResolver(theme);
  final states = <WidgetState>{
    if (model.hovered) WidgetState.hover,
    if (model.focused) WidgetState.focused,
    if (model.disabled) WidgetState.disabled,
    if (model.loading) WidgetState.loading,
    if (model.pressed) WidgetState.pressed,
  };
  final face = style.face ?? resolver.fill(resolver.tones.primary);
  return resolver.resolve(face, states, cls: PaintClass.fill);
}
