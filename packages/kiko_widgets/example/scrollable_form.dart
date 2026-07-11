// A scrollable form, and the wheel that bubbles out of a TextInput.
//
// The framework delivers a pointer event to the INNERMOST widget under it and
// stops — kiko never bubbles. When you wheel over one of these text fields, the
// event is addressed to that FIELD, not to the form scrolling behind it. A text
// input has nothing to scroll vertically, so it DECLINES the wheel (returns
// `Declined()`), leaving the message in flight.
//
// Bubbling is then the app's to build, from two primitives it already has:
//
//   1. The `Declined()` result — the field saying "not mine."
//   2. `ctx.hits.hitPath(x, y)` — the tagged widgets stacked under that cell,
//      outermost first. The last is the field that just declined; the ones
//      before it are its enclosing regions.
//
// So on a decline the app walks the hit path from the inside out and offers the
// wheel to the first enclosing id that answers. Here that is the form, which
// scrolls. This is the whole propagation story: deliver to the innermost, and
// on a decline try the next id out. No frame is stashed, nothing re-hit-tests —
// the router already resolved every id, and the app only chooses how far out to
// carry a message its target refused.
//
// Clicking a field still works (the input consumes the press to place its
// caret, and the app focuses it); only the wheel, which the field cannot use,
// bubbles to the form.
//
// tab / shift+tab move between fields · type to edit · wheel scrolls the form · esc quits

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:termparser/termparser_events.dart' as evt;

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

const _labels = ['First name', 'Last name', 'Email', 'Phone', 'Company', 'Role', 'City', 'Country'];

class AppModel {
  /// One field per label. Their ids are the tags the router resolves a pointer
  /// to, and the keys of both the routing map and the FocusGroup.
  late final List<TextInputModel> fieldList = [
    for (var i = 0; i < _labels.length; i++) TextInputModel(id: 'field-$i', placeholder: _labels[i]),
  ];

  late final Map<String, TextInputModel> fields = {for (final f in fieldList) f.id: f};

  late final FocusGroup<TextInputModel> focus = FocusGroup(fieldList);

  /// The id the whole scrollable region tags itself with — the ancestor a
  /// declined wheel bubbles to.
  final String formId = 'form';

  /// How many fields fit in the viewport, and the first one shown. The wheel
  /// moves the window; it is the app's state, because the form is the app's.
  final int visibleCount = 4;
  int scrollOffset = 0;

  int get maxOffset => (fieldList.length - visibleCount).clamp(0, fieldList.length);

  void scrollBy(int rows) => scrollOffset = (scrollOffset + rows).clamp(0, maxOffset);

  /// Keep the focused field on screen when Tab walks off the visible window.
  void scrollToFocused() {
    if (focus.index < scrollOffset) scrollOffset = focus.index;
    if (focus.index >= scrollOffset + visibleCount) scrollOffset = focus.index - visibleCount + 1;
  }

  void focusOn(String id) {
    final i = fieldList.indexWhere((f) => f.id == id);
    if (i >= 0) focus.setIndex(i);
  }
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) update(AppModel model, Msg msg, UpdateContext ctx) {
  // A press focuses the field it landed on. The input consumes the press itself
  // to place its caret; moving focus is the app's separate, one-line job.
  if (msg case PointerMsg(targetId: final id?, isDown: true)) model.focusOn(id);

  switch (msg) {
    case KeyMsg(key: 'escape'):
      return (model, const Quit());
    case KeyMsg(key: 'tab'):
      model.focus.cycle(1);
      model.scrollToFocused();
      return (model, null);
    case KeyMsg(key: 'shift+tab'):
      model.focus.cycle(-1);
      model.scrollToFocused();
      return (model, null);

    // Keyboard drives the focused field.
    case final KeyMsg key:
      return switch (model.focus.focused.update(key)) {
        Handled(:final cmd) => (model, cmd),
        Declined() => (model, null),
      };

    // Pointer: offer it to the field under the cursor first.
    case Routed(targetId: final id?) when model.fields.containsKey(id):
      switch (model.fields[id]!.update(msg)) {
        case Handled(:final cmd):
          return (model, cmd);
        case Declined():
          // The field refused it — a wheel it cannot use. Bubble it outward.
          return _bubble(model, msg, ctx);
      }

    default:
      return (model, null);
  }
}

/// Offers a declined pointer to the enclosing regions, inside out.
///
/// `hitPath` is outermost-first, so its last entry is the field that just
/// declined; `.reversed.skip(1)` walks its ancestors from the inside out. The
/// first one the app answers for — the form — consumes the wheel and scrolls.
(AppModel, Cmd?) _bubble(AppModel model, Msg msg, UpdateContext ctx) {
  if (msg case final PointerMsg p when p.isWheel) {
    final dir = p.action == evt.MouseButtonAction.wheelUp ? -1 : 1;
    for (final hit in ctx.hits.hitPath(p.global.x, p.global.y).reversed.skip(1)) {
      if (hit.id == model.formId) {
        model.scrollBy(dir);
        return (model, null);
      }
    }
  }
  return (model, null);
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════

const Theme _theme = Theme.dark;

void view(AppModel model, Frame frame) {
  final resolver = StyleResolver(_theme);
  frame.buffer.setStyle(frame.area, Style(bg: _theme.background.color));

  final rows = <View>[
    for (var i = model.scrollOffset; i < model.scrollOffset + model.visibleCount && i < model.fieldList.length; i++)
      _field(model.fieldList[i], i, resolver),
  ];

  final last = model.scrollOffset + model.visibleCount;
  final ui = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Center(child: Line('Scrollable form — wheel over a field scrolls the form behind it', style: _theme.muted.ink)),
      const SizedBox(height: 1),
      Expanded(
        child: Box(
          border: BorderType.plain,
          borderStyle: resolver.border(const {}),
          topTitles: [Line(' Profile ', style: _theme.muted.ink)],
          bottomTitles: [
            Line(
              ' ${model.scrollOffset + 1}–${last.clamp(0, model.fieldList.length)} of ${model.fieldList.length} ',
              style: _theme.muted.ink,
            ),
          ],
          // The scroll container: the id a declined wheel bubbles to. It wraps
          // every field tag, so `hitPath` reports it just outside the field.
          child: Tagged(
            model.formId,
            Column(crossAxis: CrossAxisAlignment.stretch, children: rows),
          ),
        ),
      ),
      Line(' tab/shift+tab move · type to edit · wheel scrolls · esc quits', style: _theme.muted.ink),
    ],
  );

  frame.render(ui);
}

View _field(TextInputModel input, int index, StyleResolver resolver) => Box(
  border: BorderType.plain,
  borderStyle: resolver.border({if (input.focused) WidgetState.focused}),
  padding: const EdgeInsets.symmetric(horizontal: 1),
  topTitles: [Line(' ${_labels[index]} ', style: input.focused ? _theme.focus.ink : _theme.muted.ink)],
  // The TextInput tags its own content with its model id, so it needs no
  // `Tagged` wrapper — that self-tag nests inside the form's tag, so `hitPath`
  // over a field reports the form just outside it.
  child: ConstrainedBox(
    additionalConstraints: const BoxConstraints(minH: 1, maxH: 1),
    child: TextInput(model: input, theme: _theme),
  ),
);

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

void main() async {
  await Application(title: 'Scrollable form', mouseEvents: true).run(
    init: AppModel(),
    update: update,
    view: view,
  );
}
