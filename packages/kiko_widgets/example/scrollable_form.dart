// A scrollable form built on ScrollView.
//
// Fields are composed inside a ScrollView like any other content. There is
// no hand-maintained "how many rows does the chrome take" constant. There is
// no manual scroll clamp, and no hand-rolled bubbling loop. The view
// measures its own content every frame, and reports the geometry back
// through the model (`ScrollViewModel.setViewportMetrics`) — the same
// back-channel List/Table/Tree use for `visibleCount`.
//
// Every field is always composed as a child; the Viewport windows and clips
// them. A short terminal shows fewer whole fields, never a partial one. The
// last field is always reachable by scrolling.
//
// The ScrollView tags only its own content area, border to border, gaps
// included. A wheel between fields already resolves to it directly.
//
// `ensureVisible(id)` scrolls any tagged descendant into view. The Tab walk
// below and the "scroll to the first invalid field" demo call the same
// method, with a different id each time.
//
// A wheel over a field still cannot scroll the form itself. The field is
// the innermost target, and the framework never bubbles. The field declines
// the wheel — nothing to scroll horizontally — and `FocusRouter` offers it
// outward along the hit path until the ScrollView picks it up.
//
// Each field's bordered `Container` is a scope named after the field's own
// id (`Tagged.scope(input.id, ...)`). The `TextInput` inside keeps
// self-tagging its own id, so its full path becomes `field-N/field-N`. A
// press on the field's border resolves to the bare scope path `field-N`.
// That is the same id the field itself answers to, so the router's
// click-to-focus moves focus there, exactly as a press on the input would.
// The border press carries no target rect, so the field consumes it without
// moving its caret. `ensureVisible('field-N')` brings the whole bordered
// frame into view; `ensureVisible('field-N/field-N')` would bring only the
// 1-row content leaf.
//
// The bordered frame drawn around the whole ScrollView is the one
// exception. A scope named after the scroll model would prefix — and so
// swallow — every field's own path underneath it. The frame keeps a plain id
// instead (`AppModel.frameId`). The app forwards its pointer traffic to
// `model.scroll` by hand, in the `Declined` branch of `update` below.
//
// One policy stays app-owned: a press that names no field — the outer
// frame, or a gap between fields — focuses the nearest field. `FocusRouter`
// declines what it does not own; `focusFromChrome` below applies this
// policy on top of that decline.
//
// tab/shift+tab move · type to edit · wheel scrolls · enter validates · esc quits

import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

const _labels = ['First name', 'Last name', 'Email', 'Phone', 'Company', 'Role', 'City', 'Country'];

class AppModel {
  AppModel() {
    // Realize the lazily-built FocusGroup now, so the first field is focused —
    // and drawn as such, with a cursor — on the very first frame.
    focus.setIndex(0);
  }

  /// One field per label. Their ids are the tags the router resolves a
  /// pointer to, and the keys of both [fields] and the [focus] group.
  late final List<TextInputModel> fieldList = [
    for (var i = 0; i < _labels.length; i++) TextInputModel(id: 'field-$i', placeholder: _labels[i]),
  ];

  late final Map<String, TextInputModel> fields = {for (final f in fieldList) f.id: f};

  late final FocusGroup<Component> focus = FocusGroup(fieldList);

  /// Scrolls the field column. No app-owned offset, no clamp, no viewport
  /// arithmetic — the view measures its own content and pushes the geometry
  /// back in every frame.
  final ScrollViewModel scroll = ScrollViewModel(id: 'scroll');

  /// Tags the bordered frame drawn around the scroll view. This id names no
  /// field, so a scope here would prefix — and swallow — every field's own
  /// path underneath it. It stays a plain id instead; the app forwards its
  /// pointer traffic to [scroll] by hand, in `update`'s `Declined` branch.
  final String frameId = 'form-frame';

  /// Routes keys and pointers among the fields and the scroll surface. The
  /// fields are the focusable members; [scroll] rides along as an extra —
  /// pointer-reachable, never focused, skipped by Tab. A press on a field,
  /// its border included, moves focus there directly: both resolve to the
  /// field's own id. A wheel a field declines bubbles outward to whatever
  /// scrollable ancestor sits behind it. Every focus change the router makes
  /// — Tab, Shift+Tab, a click on a field — scrolls the newly focused
  /// field's whole frame into view.
  late final FocusRouter router = FocusRouter(
    focus,
    extras: [scroll],
    onFocusChange: (focused) => scroll.ensureVisible(focused.id),
  );

  /// Non-null while the last [validate] attempt failed on this field's id;
  /// cleared once the field is no longer empty. Purely a display + scroll-to-
  /// error demo — nothing here is required for ScrollView itself to work.
  String? errorId;

  void focusOn(String id) {
    final i = fieldList.indexWhere((f) => f.id == id);
    if (i >= 0) focus.setIndex(i);
  }

  /// Focuses the field a press on the form's chrome landed on: the outer
  /// frame, or a gap between fields. Neither names a field directly, so the
  /// router left the press unhandled. Match the click's row against where
  /// each field is currently drawn, read from the live hit map rather than
  /// recomputed. [HitTag.join] reaches the field's content leaf, because the
  /// field's own scope path carries no rect.
  void focusFromChrome(int globalY, HitMap hits) {
    for (final f in fieldList) {
      final rect = hits.rectOf(HitTag.join(f.id, f.id));
      if (rect != null && (globalY - rect.y).abs() <= 1) {
        focusOn(f.id);
        return;
      }
    }
  }

  /// Focuses and scrolls to the first empty field. The scroll-to-error call
  /// is `ensureVisible` — the exact one the Tab walk below uses — only the id
  /// differs, because it works for any tagged descendant, not just the
  /// focused one.
  void validate() {
    for (final f in fieldList) {
      if (f.value.trim().isEmpty) {
        errorId = f.id;
        focusOn(f.id);
        scroll.ensureVisible(f.id);
        return;
      }
    }
    errorId = null;
  }
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) update(AppModel model, Msg msg, UpdateContext ctx) {
  // The one routing line: keys to the focused field (tab/shift+tab reserved
  // for traversal, with ensureVisible riding on the router's focus-change
  // callback), a press to the field it landed on — focusing it first — and a
  // wheel to whatever is under it, bubbling outward from a declining field
  // to the scroll surface behind it.
  final result = model.router.route(msg, ctx);

  // Fixing the errored field's text clears its error mark — checked after
  // the focused field has seen the key.
  if (msg is KeyMsg &&
      model.errorId == model.focus.focused.id &&
      model.fields[model.focus.focused.id]!.value.trim().isNotEmpty) {
    model.errorId = null;
  }

  switch (result) {
    case Handled(:final cmd):
      return (model, cmd);
    case Declined():
      break; // not interaction traffic the router owns — fall through
  }

  // The outer frame names no member the router knows, so its pointer
  // traffic always declines above. Forward it to the scroll model by hand —
  // a wheel on the border scrolls the form exactly like one over the
  // content — and let anything the scroll model also declines, a press
  // included, fall through to the chrome policy below.
  if (msg case Routed(targetId: final target?) when target == model.frameId) {
    switch (model.scroll.update(msg)) {
      case Handled(:final cmd):
        return (model, cmd);
      case Declined():
        break;
    }
  }

  // The roll-your-own layer on top of the router's Declined. A press that
  // names no field — the outer frame, or a gap between fields — reaches
  // here unhandled. The app applies its own policy instead: focus the field
  // nearest the click's row. A policy like this stays app code by design;
  // the router only ever declines what it doesn't own.
  if (msg case final PointerMsg p when p.isDown) {
    if (p.targetId == model.frameId || p.targetId == model.scroll.id) {
      model.focusFromChrome(p.global.y, ctx.hits);
      return (model, null);
    }
  }

  // Fallback keys — only input nothing consumed lands here.
  switch (msg) {
    case KeyMsg(key: 'escape'):
      return (model, const Quit());
    case KeyMsg(key: 'enter'):
      model.validate();
      return (model, null);
    default:
      return (model, null);
  }
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════

const Theme _theme = Theme.dark;

void view(AppModel model, Frame frame) {
  final resolver = StyleResolver(_theme);
  frame.buffer.setStyle(frame.area, Style(bg: _theme.background.color));

  final fieldColumn = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < model.fieldList.length; i++) ...[
        if (i > 0) const SizedBox(height: 1),
        _field(model.fieldList[i], i, model, resolver),
      ],
    ],
  );

  final statusLine = model.errorId == null
      ? ' tab/shift+tab move · type to edit · wheel scrolls · enter validates · esc quits'
      : ' ${_labels[model.fieldList.indexWhere((f) => f.id == model.errorId)]} is required — enter validates';

  final ui = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Center(child: Line('Scrollable form — wheel over a field scrolls the form behind it', style: _theme.muted.ink)),
      const SizedBox(height: 1),
      // The frame's own plain id (see the header comment) — the one
      // exception to scoping in this example. `update` forwards its pointer
      // traffic to `model.scroll` by hand, so a wheel on the border scrolls
      // the form exactly like one over the content.
      Expanded(
        child: Tagged(
          model.frameId,
          Container(
            border: BorderType.plain,
            borderStyle: resolver.border(const {}),
            topTitles: [Line(' Profile ', style: _theme.muted.ink)],
            bottomTitles: [
              Line(' field ${model.focus.index + 1} of ${model.fieldList.length} ', style: _theme.muted.ink),
            ],
            child: ScrollView(model: model.scroll, child: fieldColumn),
          ),
        ),
      ),
      Line(statusLine, style: model.errorId == null ? _theme.muted.ink : _theme.error.ink),
    ],
  );

  frame.render(ui);
}

View _field(TextInputModel input, int index, AppModel model, StyleResolver resolver) => Tagged.scope(
  // Names the whole bordered container, borders included, so `ensureVisible`
  // can bring it fully into view. Legal to wrap in `Tagged.scope` here —
  // unlike the TextInput below — because `Container` itself never self-tags;
  // only the TextInput inside it does.
  input.id,
  Container(
    border: BorderType.plain,
    borderStyle: resolver.border({
      if (input.focused) WidgetState.focused,
      if (input.id == model.errorId) WidgetState.error,
    }),
    padding: const EdgeInsets.symmetric(horizontal: 1),
    topTitles: [Line(' ${_labels[index]} ', style: input.focused ? _theme.focus.ink : _theme.muted.ink)],
    // The TextInput tags its own content with its model id — no `Tagged`
    // wrapper needed. That self-tag nests inside the scope above, so a
    // click on the input reports the path `field-N/field-N`.
    child: ConstrainedBox(
      additionalConstraints: const BoxConstraints(minH: 1, maxH: 1),
      child: TextInput(model: input, theme: _theme),
    ),
  ),
);

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

Future<void> main() async {
  exit(
    await Application(title: 'Scrollable form', mouseEvents: true).run(
      init: AppModel(),
      update: update,
      view: view,
    ),
  );
}
