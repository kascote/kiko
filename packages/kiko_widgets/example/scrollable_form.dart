// A scrollable form built on ScrollView — the proof for spec 0166 / mikos 0177.
//
// Fields are composed inside a ScrollView exactly like any other content: no
// hand-maintained "how many rows does the chrome take" constants, no manual
// scroll clamp, no bubbling loop written by hand. The view measures its own
// content every frame and reports the geometry back through the model
// (`ScrollViewModel.setViewportMetrics`) — the same back-channel List/Table/
// Tree already use for `visibleCount`.
//
// Three things the ScrollView buys for free, each killing a bug the
// hand-rolled version had (see specs/scrollable-form-findings.md):
//
//   - Every field is always composed as a child; the Viewport windows and
//     clips them. A short terminal simply shows fewer whole fields — there is
//     no chrome/field-row arithmetic to get wrong, so the last field is
//     ALWAYS reachable by scrolling (finding B, dead by construction).
//   - The ScrollView tags its own content area — border-to-border, gaps
//     included — so a wheel over a gap between fields already resolves to it
//     directly (finding E's main case, dead for free).
//   - `ensureVisible(id)` is one call for ANY tagged descendant: the Tab walk
//     and the "scroll to the first invalid field" validation demo below are
//     the exact same line, just a different id.
//
// A wheel over a FIELD still can't be handled by the ScrollView directly —
// the field is the innermost target and the framework never bubbles. The
// field declines the wheel (nothing to scroll horizontally), and the
// FocusRouter hands it outward — the same `offerOutward` walk over
// `ctx.hits.hitPath` the app used to call by hand now runs inside the
// router's delegation.
//
// The bordered frame around the fields demonstrates the "E-split" recipe for
// user-composed chrome: the ScrollView only tags its OWN content area, so a
// border drawn around it needs its own `Tagged` — but that tag can point at
// the SAME ScrollViewModel via a router alias, so a wheel on the border
// scrolls the form exactly like a wheel over the content does. Two ids, one
// Component: legal, because the frame's `Container` doesn't self-tag (only
// wrapping an already self-tagging, model-backed widget would trip the
// self-tag assert).
//
// One policy stays deliberately app-owned: a press on the form's chrome
// focuses the nearest field. The router has no such heuristic and shouldn't —
// it declines what it doesn't own, and the app catches the Declined and
// applies its own policy (`focusFromChrome` below). That is the intended
// escape hatch: roll your own on top of Declined, not a router flag.
//
// tab/shift+tab move · type to edit · wheel scrolls · enter validates · esc quits

import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

const _labels = ['First name', 'Last name', 'Email', 'Phone', 'Company', 'Role', 'City', 'Country'];

/// The E-split recipe (see the header comment), applied per field: a field's
/// `TextInput` self-tags only its own 1-row content, never the bordered
/// `Container` drawn around it. Without this second tag, `ensureVisible` only
/// knows about that 1 row and scrolls the minimum to fit it — clipping the
/// container's own border on a short terminal. This tag gives the WHOLE field
/// container a name `ensureVisible` can target, and doubles as its chrome's
/// hit region (a border click resolves here, same as a click on the outer
/// frame or a gap).
String _fieldFrameId(String fieldId) => '$fieldId-frame';

class AppModel {
  AppModel() {
    // Realize the lazily-built FocusGroup now, so the first field is focused —
    // and drawn as such, with a cursor — on the very first frame (finding A).
    focus.setIndex(0);
  }

  /// One field per label. Their ids are the tags the router resolves a
  /// pointer to, and the keys of both [fields] and the [focus] group.
  late final List<TextInputModel> fieldList = [
    for (var i = 0; i < _labels.length; i++) TextInputModel(id: 'field-$i', placeholder: _labels[i]),
  ];

  late final Map<String, TextInputModel> fields = {for (final f in fieldList) f.id: f};

  /// Every field's frame tag (see [_fieldFrameId]) — a click landing on one
  /// is chrome, not content, so it routes through [focusFromChrome] exactly
  /// like a click on [frameId] or the scroll view's own content-area tag.
  late final Set<String> fieldFrameIds = {for (final f in fieldList) _fieldFrameId(f.id)};

  late final FocusGroup<Component> focus = FocusGroup(fieldList);

  /// Scrolls the field column. No app-owned offset, no clamp, no viewport
  /// arithmetic — the view measures its own content and pushes the geometry
  /// back in every frame.
  final ScrollViewModel scroll = ScrollViewModel(id: 'scroll');

  /// Tags the bordered frame drawn AROUND the scroll view — see the header
  /// comment's "E-split recipe." Resolves to the same model as [scroll]'s own
  /// content-area tag, via the router's aliases.
  final String frameId = 'form-frame';

  /// Routes keys and pointers among the fields and the scroll surface. The
  /// fields are the focusable members; [scroll] rides along as an extra —
  /// pointer-reachable, never focused, skipped by Tab. Every chrome tag (the
  /// outer frame, each field's frame) is an alias for [scroll]: the E-split
  /// recipe's two-ids-one-Component, so a wheel on any border scrolls the
  /// form exactly like one over the content. A wheel a field declines bubbles
  /// outward inside the router. Every focus change the router makes — Tab,
  /// Shift+Tab, a click on a field — scrolls the newly focused field's whole
  /// frame into view.
  late final FocusRouter router = FocusRouter(
    focus,
    extras: [scroll],
    aliases: {frameId: scroll.id, for (final id in fieldFrameIds) id: scroll.id},
    onFocusChange: (focused) => scroll.ensureVisible(_fieldFrameId(focused.id)),
  );

  /// Non-null while the last [validate] attempt failed on this field's id;
  /// cleared once the field is no longer empty. Purely a display + scroll-to-
  /// error demo — nothing here is required for ScrollView itself to work.
  String? errorId;

  void focusOn(String id) {
    final i = fieldList.indexWhere((f) => f.id == id);
    if (i >= 0) focus.setIndex(i);
  }

  /// Focus the field a press on the form's chrome landed on (finding F): a
  /// press on a field's own border resolves to its frame tag, and a press on
  /// a gap or the outer frame resolves to the scroll view or the frame — none
  /// of those name a field directly. Match the click's row against where each
  /// field is currently drawn, read from the live hit map rather than
  /// recomputed.
  void focusFromChrome(int globalY, HitMap hits) {
    for (final f in fieldList) {
      final rect = hits.rectOf(f.id);
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
        scroll.ensureVisible(_fieldFrameId(f.id));
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
  // wheel to whatever is under it, bubbling outward from a field that
  // declines it to the scroll view behind, content or chrome alike.
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

  // The roll-your-own layer on top of the router's Declined. A press on the
  // form's CHROME — the outer frame, a field's border, a gap — names no
  // field, so the router moved no focus and nothing consumed the press. The
  // app applies its own policy instead: focus the field nearest the click's
  // row. A policy like this stays app code by design; the router only ever
  // declines what it doesn't own.
  if (msg case final PointerMsg p when p.isDown) {
    if (p.targetId == model.frameId || p.targetId == model.scroll.id || model.fieldFrameIds.contains(p.targetId)) {
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
      // The frame's OWN tag (see the header comment's E-split recipe) — a
      // second id routed to the same ScrollViewModel as the content area's
      // self-tag, so a wheel on the border scrolls the form too.
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

View _field(TextInputModel input, int index, AppModel model, StyleResolver resolver) => Tagged(
  // The frame tag: names the WHOLE container (borders included) so
  // `ensureVisible` can bring it fully into view — see `_fieldFrameId`'s doc
  // comment. Legal to wrap in `Tagged` here (unlike the TextInput below)
  // because `Container` itself never self-tags; only the TextInput inside it
  // does.
  _fieldFrameId(input.id),
  Container(
    border: BorderType.plain,
    borderStyle: resolver.border({
      if (input.focused) WidgetState.focused,
      if (input.id == model.errorId) WidgetState.error,
    }),
    padding: const EdgeInsets.symmetric(horizontal: 1),
    topTitles: [Line(' ${_labels[index]} ', style: input.focused ? _theme.focus.ink : _theme.muted.ink)],
    // The TextInput tags its own content with its model id — no `Tagged`
    // wrapper needed; that self-tag nests inside the frame tag above, so
    // `hitPath` over a field's content reports the frame, then the scroll
    // view, just outside it.
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
