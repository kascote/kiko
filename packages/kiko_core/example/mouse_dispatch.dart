import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:termparser/termparser_events.dart' as evt;

// ═══════════════════════════════════════════════════════════
// Pointer dispatch, hand-rolled — the primitive `FocusRouter` packages.
//
// Two menus, each a `Component` with its own `update(Msg)`. The app holds them
// in a `Map<String, Component>` keyed by the very id they tag their region
// with, and forwards every routed message home in a single generic line.
//
// This is the dispatch doctrine at its floor: the runtime resolves a pointer to
// an id and stops there; the app owns the id→Component hop, click-to-focus, and
// the fallback for anything unaddressed. kiko_widgets' `FocusRouter` packages
// this exact pattern — the targetId guard, pointer→targeted, everything
// non-positional→focused, press-moves-focus, declined-pointer bubbling —
// behind a single `route()` call, and most apps should reach for it.
// `FocusRouter` lives a layer up, in kiko_widgets; this example stays
// hand-rolled on purpose, because it *is* the
// primitive the router is built from. Read it to see what `route()` does
// underneath, or as the seam to drop to when you outgrow the packaged glue.
//
// The three things worth reading for:
//
//   1. Dispatch is `component.update(msg)` — the same entry point keyboard
//      already uses. Keyboard picks its target by focus, so it needs one
//      pointer: `focus.focused`. The mouse picks its target by geometry, so it
//      needs N: a map. Same method, different selection rule, and the data
//      structure differs exactly as the target count does.
//
//   2. Clicking a row emits `MenuActivated` — the same widget→app event that
//      pressing Enter on it emits, addressed by the menu's stable id, handled
//      by the app in one place. Nothing about the app's event handling knows
//      whether a mouse or a keyboard produced it.
//
//   3. The runtime never sees the map. The router deals in ids alone; the
//      id→Component hop is the app's, on purpose, and the same bookkeeping the
//      load doctrine's `Map<String, Loadable>` already carries.
//
// tab cycles focus · ↑/↓ or the wheel moves the cursor · enter or a click
// activates · right-click resets a menu · click "clear" to empty the log · q quits
// ═══════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════
// A COMPONENT
// ═══════════════════════════════════════════════════════════

/// Widget→app event: a row was activated. Addressed by the menu's id, whether a
/// click or an Enter key produced it.
class MenuActivated extends Cmd {
  final String id;
  final int index;

  const MenuActivated(this.id, this.index);
}

/// A menu of rows, driven by key or by pointer, ignorant of both the app and
/// its sibling.
class MenuModel implements Component {
  @override
  final String id;

  final List<String> items;

  /// The selected row.
  int cursor = 0;

  /// The row under the pointer, or null. The router knows a menu was hit; only
  /// the menu knows which of its rows, because only it knows how it is laid
  /// out. That is why hover state lives here and not in the framework.
  int? hoverRow;

  bool _focused = false;

  MenuModel(this.id, this.items);

  bool get focused => _focused;

  @override
  set focused(bool value) => _focused = value;

  @override
  UpdateResult update(Msg msg) => switch (msg) {
    KeyMsg(key: 'up') => Handled(_moveBy(-1)),
    KeyMsg(key: 'down') => Handled(_moveBy(1)),
    KeyMsg(key: 'enter') => Handled(MenuActivated(id, cursor)),

    // The pointer has gone somewhere else and no event will address this menu
    // again, so nothing else in the app has to notice that hover ended.
    PointerLeaveMsg() => Handled(_hoverOn(null)),

    // A press selects the row it landed on and activates it — emitting exactly
    // what Enter emits, so the app grew no second case for the mouse.
    PointerMsg(isDown: true, inside: true, :final local) => Handled(_activate(local.y)),

    PointerMsg(isMove: true, inside: true, :final local) => Handled(_hoverOn(local.y)),

    // The wheel carries a direction, not a position: `wheelDeltaY` is `PointerMsg`'s
    // own signed notch, `-1`/`1`, so no case here reads the terminal event's enum.
    PointerMsg(wheelDeltaY: -1) => Handled(_moveBy(-1)),
    PointerMsg(wheelDeltaY: 1) => Handled(_moveBy(1)),

    // Everything else is declined, and the app may try something else with it.
    _ => const Declined(),
  };

  Cmd? _moveBy(int delta) {
    cursor = (cursor + delta).clamp(0, items.length - 1);
    return null;
  }

  /// The tag sits on the rows, so `local.y` is a row index with nothing to
  /// subtract — but the rows do not fill the pane, and a click below the last
  /// one still lands inside the tagged region.
  Cmd? _activate(int row) {
    if (row >= items.length) return null;
    cursor = row;
    return MenuActivated(id, row);
  }

  Cmd? _hoverOn(int? row) {
    hoverRow = row != null && row < items.length ? row : null;
    return null;
  }
}

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel {
  final MenuModel colors = MenuModel('colors', ['red', 'green', 'blue', 'magenta']);
  final MenuModel shapes = MenuModel('shapes', ['circle', 'square', 'triangle']);

  late final FocusGroup<MenuModel> focus = FocusGroup([colors, shapes]);

  /// Every addressable component, keyed by the id it tags its region with.
  /// App-side by design: the framework routes ids, and stops there.
  late final Map<String, Component> targets = {colors.id: colors, shapes.id: shapes};

  final List<String> log = [];

  MenuModel menu(String id) => targets[id]! as MenuModel;

  void focusOn(String id) {
    final index = focus.children.indexWhere((m) => m.id == id);
    if (index >= 0) focus.setIndex(index);
  }

  void note(String line) {
    log.insert(0, line);
    if (log.length > 5) log.removeLast();
  }
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) update(AppModel model, Msg msg, UpdateContext _) {
  // A press moves focus before the menu under it sees anything. Focus is the
  // app's to arbitrate — a menu cannot see its sibling — and the router only
  // says which id the press landed on.
  if (msg case PointerMsg(targetId: final id?, isDown: true)) model.focusOn(id);

  switch (msg) {
    case KeyMsg(key: 'q'):
      return (model, const Quit());
    case KeyMsg(key: 'tab'):
      model.focus.cycle(1);
      return (model, null);

    // Keyboard addresses the focused component: one target, one pointer to it.
    case final KeyMsg key:
      return _handle(model, model.focus.focused.update(key));

    // A domain case, layered over the generic line rather than replacing it: a
    // right-click resets a menu, and the menu never learns it happened.
    case PointerMsg(targetId: final id?, isDown: true, :final button)
        when button.button == evt.MouseButtonKind.right && model.targets.containsKey(id):
      model.menu(id).cursor = 0;
      model.note('$id reset');
      return (model, null);

    // A region the app answers for itself. `clear` is `Tagged`, so it routes,
    // but it is no component and holds no map entry.
    case PointerMsg(targetId: 'clear', isDown: true):
      model.log.clear();
      return (model, null);

    // The one generic line. Every routed message — pointer, leave, cancel, and
    // whatever routed kind is added next — reaches the component answering to
    // its id. `Routed` means *this was routed*, not *this has a target*, so a
    // null targetId declines the pattern and falls through to the background.
    case Routed(targetId: final id?) when model.targets.containsKey(id):
      return _handle(model, model.targets[id]!.update(msg));

    // Nothing addressable under the pointer.
    case final PointerMsg p:
      if (p.isDown) model.note('background · press at (${p.global.x}, ${p.global.y})');
      return (model, null);

    default:
      return (model, null);
  }
}

/// Receives what a component returned, wherever it came from.
///
/// [MenuActivated] carries its owner's id, so one case serves both menus and
/// both input devices. [Declined] is the component declining; here that ends
/// the message, but it is also what an app walking `ctx.hits.hitPath` would use
/// to try the next id out.
(AppModel, Cmd?) _handle(AppModel model, UpdateResult result) {
  switch (result) {
    case Handled(cmd: MenuActivated(:final id, :final index)):
      model.note('$id · activated "${model.menu(id).items[index]}"');
      return (model, null);
    case Handled(:final cmd):
      return (model, cmd);
    case Declined():
      return (model, null);
  }
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════

void view(AppModel model, Frame frame) {
  final ui = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: Line(
          'Pointer dispatch — tab · ↑/↓ · wheel · enter · click · right-click · q quits',
          style: const Style(fg: Color.darkGray),
        ),
      ),
      const SizedBox(height: 1),
      Expanded(
        child: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _menu(model.colors)),
            Expanded(child: _menu(model.shapes)),
          ],
        ),
      ),
      _clearButton(),
      _log(model),
    ],
  );

  frame.render(ui);
}

/// The tag goes on the rows, not on the box around them.
///
/// Where the tag sits decides what a routed event's `local` means: tagging the
/// rows makes `local.y` a row index, where tagging the box would make it a row
/// index off by the border. Neither is more correct; nothing downstream
/// compensates.
View _menu(MenuModel model) => Container(
  border: BorderType.plain,
  borderStyle: Style(fg: model.focused ? Color.cyan : Color.darkGray),
  topTitles: [Line(' ${model.id} ', style: Style(fg: model.focused ? Color.cyan : Color.darkGray))],
  child: Tagged(
    model.id,
    Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < model.items.length; i++) _row(model, i),
        const Expanded(child: SizedBox()),
      ],
    ),
  ),
);

View _row(MenuModel model, int index) {
  final selected = model.cursor == index;
  final hovered = model.hoverRow == index;
  final bg = selected ? Color.cyan : (hovered ? Color.darkGray : null);
  return Container(
    background: Style(bg: bg),
    child: Line(
      ' ${model.items[index]}',
      style: Style(fg: selected ? Color.black : null),
    ),
  );
}

View _clearButton() => Center(
  child: Tagged(
    'clear',
    Container(
      border: BorderType.plain,
      child: Line(' clear log ', style: const Style(fg: Color.yellow)),
    ),
  ),
);

View _log(AppModel model) => Container(
  border: BorderType.plain,
  topTitles: [Line('events')],
  child: Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      if (model.log.isEmpty)
        Line('—', style: const Style(fg: Color.darkGray))
      else
        for (final line in model.log) Line(line),
    ],
  ),
);

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

Future<void> main() async {
  exit(
    await Application(title: 'Pointer dispatch', mouseEvents: true).run(
      init: AppModel(),
      update: update,
      view: view,
    ),
  );
}
