// A widget built from scratch — the worked example from docs/building-widgets.md.
//
// `PaletteModel`/`Palette` is a small option picker written the way the shipped
// widgets are: a mutable model implementing `Component`, a stateless view that
// self-tags its subtree, pointer handling above the focus gate, a click that
// emits the same id-addressed command as Enter, and a wheel that scrolls the
// viewport through `ScrollableModel`. The doc walks through this file section
// by section; keep the two in sync.
//
// ↑/↓ moves · enter or a click chooses · the wheel scrolls · q quits

import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

// ═══════════════════════════════════════════════════════════
// COMMAND
// ═══════════════════════════════════════════════════════════

/// Emitted when an option is chosen — by Enter or by a click alike. It
/// addresses its owner by [id], so an app holding several palettes can route
/// it home.
class PaletteChooseCmd extends Cmd {
  /// Creates the command carrying the owner's [id] and the chosen [value].
  const PaletteChooseCmd(this.id, this.value);

  /// The id of the palette that emitted this.
  final String id;

  /// The option that was chosen.
  final String value;
}

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

/// The state half of the palette: options, cursor, hover, scroll, and the
/// `update` that consumes keyboard and pointer messages.
class PaletteModel with ScrollableModel implements Component {
  /// Creates a palette over [options], showing [viewportRows] rows at a time.
  PaletteModel({required this.id, required this.options, this.viewportRows = 5});

  @override
  final String id;

  /// The options to pick from.
  final List<String> options;

  /// How many rows the viewport shows. Fixed here to keep the example small;
  /// a production widget measures its viewport while it paints and pushes the
  /// count into the model (see ListView's source).
  final int viewportRows;

  /// The keyboard-current option.
  int cursor = 0;

  /// The row under the mouse, or null when the pointer is elsewhere.
  int? hoverRow;

  bool _focused = false;

  /// Whether the palette owns keyboard input.
  bool get focused => _focused;

  @override
  set focused(bool value) => _focused = value;

  int _scrollOffset = 0;

  @override
  int get scrollOffset => _scrollOffset;

  @override
  int get visibleCount => viewportRows;

  @override
  int scrollBy(int rows) {
    final maxOffset = (options.length - visibleCount).clamp(0, options.length);
    final before = _scrollOffset;
    _scrollOffset = (_scrollOffset + rows).clamp(0, maxOffset);
    return _scrollOffset - before;
  }

  @override
  int? localToRow(Position local) {
    if (local.y < 0 || local.y >= visibleCount) return null;
    final row = _scrollOffset + local.y;
    return row < options.length ? row : null;
  }

  /// Snaps the viewport so the cursor is visible — keyboard navigation always
  /// brings its row into view, even after the wheel scrolled elsewhere.
  void _snapToCursor() {
    if (cursor < _scrollOffset) _scrollOffset = cursor;
    if (cursor >= _scrollOffset + visibleCount) _scrollOffset = cursor - visibleCount + 1;
  }

  @override
  UpdateResult update(Msg msg) {
    // The pointer branch sits ABOVE the focus gate: a wheel scrolls, a click
    // chooses, and a hover highlights whether or not the palette is focused.
    if (msg case final PointerMsg pointer) {
      if (pointer.wheelDeltaY != 0) {
        final moved = scrollBy(wheelScrollLines * pointer.wheelDeltaY);
        // A notch that moved nothing (already at that edge) is declined so a
        // scrollable ancestor can take it; any notch that moved is consumed.
        return moved == 0 ? const Declined() : const Handled();
      }
      if (pointer.isWheel) return const Declined(); // a horizontal wheel is not ours

      final row = localToRow(pointer.local);
      if (pointer.isDown) {
        // A press below the last option is not ours; the app may bubble it.
        if (row == null) return const Declined();
        hoverRow = row;
        // A click is the keyboard's cursor-move + confirm collapsed into one
        // event: move to the row, then emit the same command Enter emits.
        cursor = row;
        return Handled(PaletteChooseCmd(id, options[row]));
      }
      // A move, drag, or the release half of a click only refreshes the hover.
      hoverRow = row;
      return const Handled();
    }
    if (msg is PointerLeaveMsg) {
      hoverRow = null;
      return const Handled();
    }
    // The palette holds no gesture state (nothing armed on a press), so a
    // torn-off gesture is not its business.
    if (msg is PointerCancelMsg) return const Declined();

    // Keyboard only below this line.
    if (!focused) return const Declined();

    switch (msg) {
      case KeyMsg(key: 'up'):
        if (cursor > 0) cursor--;
        _snapToCursor();
        return const Handled();
      case KeyMsg(key: 'down'):
        if (cursor < options.length - 1) cursor++;
        _snapToCursor();
        return const Handled();
      case KeyMsg(key: 'enter'):
        return Handled(PaletteChooseCmd(id, options[cursor]));
    }

    // Everything else was never ours — decline it, never swallow it.
    return const Declined();
  }
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════

/// The render half of the palette: stateless, rebuilt every frame from the
/// model, and stamped with the model's id so pointer events route back to it.
final class Palette implements View {
  /// Creates a palette view over [model], styled by [theme].
  const Palette({required this.model, required this.theme});

  /// The model whose options, cursor, and hover this view renders.
  final PaletteModel model;

  /// The theme that resolves row styles.
  final Theme theme;

  @override
  Node build() {
    final resolver = StyleResolver(theme);
    final m = model;
    final end = (m.scrollOffset + m.visibleCount).clamp(0, m.options.length);

    return Container(
      height: m.viewportRows,
      child: Column(
        crossAxis: CrossAxisAlignment.stretch,
        children: [for (var i = m.scrollOffset; i < end; i++) _row(m, resolver, i)],
      ),
    ).build()..tag = m.id;
  }

  View _row(PaletteModel m, StyleResolver resolver, int i) {
    // Row paint layers the way the shipped widgets do it: the hover wash first
    // (weakest, background-only, so the row's own foreground survives), then
    // the cursor fill over it. `focused` is never a row state — it means "the
    // widget owns input" and belongs to the chrome around the widget, not to
    // every row inside it.
    var style = const Style();
    if (i == m.hoverRow) {
      style = style.patch(resolver.resolve(null, const {WidgetState.hover}, cls: PaintClass.wash));
    }
    if (i == m.cursor) {
      style = style.patch(resolver.resolve(null, const {WidgetState.cursor}));
    }
    return Container(
      background: style,
      child: Line(' ${m.options[i]}', style: style),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// APP
// ═══════════════════════════════════════════════════════════

class AppModel {
  final palette = PaletteModel(
    id: 'palette',
    options: ['red', 'orange', 'yellow', 'green', 'cyan', 'blue', 'violet', 'magenta'],
  );

  late final router = FocusRouter(FocusGroup<Component>([palette]));

  String? chosen;
}

(AppModel, Cmd?) update(AppModel model, Msg msg, UpdateContext ctx) {
  // Widget→app commands first: intercept the palette's choice by id.
  switch (model.router.route(msg, ctx)) {
    case Handled(cmd: PaletteChooseCmd(:final value)):
      model.chosen = value;
      return (model, null);
    case Handled(:final cmd):
      return (model, cmd);
    case Declined():
      break; // nothing consumed it — fall through to the app's own keys
  }

  if (msg case KeyMsg(key: 'q')) return (model, const Quit());
  return (model, null);
}

const Theme _theme = Theme.dark;

void view(AppModel model, Frame frame) {
  final resolver = StyleResolver(_theme);
  frame.buffer.setStyle(frame.area, Style(bg: _theme.background.color));

  final ui = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Center(child: Line('A widget from scratch — ↑/↓ · wheel · enter or click · q quits', style: _theme.muted.ink)),
      const SizedBox(height: 1),
      Center(
        // The border belongs to the app, not the palette: the tag rides the
        // palette's own subtree, so `local` still counts from the first row.
        child: Container(
          border: BorderType.plain,
          // Focus lives on the chrome: the border lights up when the palette
          // owns the keyboard; the rows inside only ever show cursor + hover.
          borderStyle: resolver.border({if (model.palette.focused) WidgetState.focused}),
          topTitles: [Line(' pick a color ', style: _theme.muted.ink)],
          child: Palette(model: model.palette, theme: _theme),
        ),
      ),
      const SizedBox(height: 1),
      Center(
        child: model.chosen == null
            ? Line('nothing chosen yet', style: _theme.muted.ink)
            : Line('chosen: ${model.chosen}', style: Style(fg: _theme.background.on)),
      ),
    ],
  );

  frame.render(ui);
}

Future<void> main() async {
  exit(
    await Application(title: 'Custom widget', mouseEvents: true).run(
      init: AppModel(),
      update: update,
      view: view,
    ),
  );
}
