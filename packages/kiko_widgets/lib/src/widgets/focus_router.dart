import 'package:kiko/kiko.dart';

import 'offer_outward.dart';

/// Moves focus to the group member a press landed on.
///
/// A press ([PointerMsg] with [PointerMsg.isDown] true) whose [Routed.targetId]
/// names a member of [focus] moves focus to that member. [aliases] lets chrome
/// around a member stand in for it — a border or label tagged with its own id
/// that should still count as a press on the member it decorates; an alias
/// entry maps that chrome id to the member id it belongs to. Chrome ids are
/// never members and are never themselves focused.
///
/// Returns whether focus actually changed. A press on the already-focused
/// member, a non-press message, a background press (`targetId == null`), an
/// unknown id, or an alias naming a non-member all leave focus untouched and
/// return false. [FocusRouter] fires its focus-change callback off the
/// returned bool; an app that owns its own composition calls it directly the
/// same way.
///
/// This only moves focus — it never consumes [msg]. The press stays in
/// flight for the caller to route to its target afterwards.
bool focusOnPress(Msg msg, FocusGroup<Component> focus, {Map<String, String> aliases = const {}}) {
  if (msg is! PointerMsg || !msg.isDown || msg.targetId == null) return false;

  final targetId = msg.targetId!;
  var index = focus.children.indexWhere((c) => c.id == targetId);
  if (index == -1) {
    final memberId = aliases[targetId];
    if (memberId != null) index = focus.children.indexWhere((c) => c.id == memberId);
  }
  if (index == -1 || index == focus.index) return false;

  focus.setIndex(index);
  return true;
}

/// Dispatches a routed message to its addressed target, bubbling a declined
/// press outward.
///
/// [msg] must be [Routed] (a [PointerMsg], [PointerLeaveMsg] or
/// [PointerCancelMsg]) with a non-null [Routed.targetId] present in [targets];
/// anything else — a non-routed message, a background press, or an id absent
/// from [targets] — declines without touching any component. The absent-id
/// guard is deliberate: forwarding untargeted pointer traffic to some
/// component would route it by coordinate coincidence rather than by the
/// router's own resolution.
///
/// The addressed target's [Component.update] result is returned as-is, except
/// a [Declined] answer to a positional [PointerMsg] is re-offered outward via
/// [offerOutward], which walks the hit path from [ctx] and tries each
/// enclosing id present in [targets]. A declined [PointerLeaveMsg] or
/// [PointerCancelMsg] never bubbles — neither carries a position to walk from.
///
/// This is pure id dispatch with no focus semantics: it does not move focus
/// and does no alias resolution — a caller wanting alias-aware chrome routing
/// composes it with [focusOnPress] or the id remapping of its choice. Several
/// ids in [targets] may legitimately map to the same component (e.g. a chrome
/// id and a content id sharing one model). [FocusRouter] composes this with
/// focus handling; an app can call it directly to keep the same wiring while
/// owning its own composition.
UpdateResult routeToTarget(Msg msg, UpdateContext ctx, Map<String, Component> targets) {
  if (msg case Routed(:final targetId?)) {
    final target = targets[targetId];
    if (target == null) return const Declined();

    final result = target.update(msg);
    if (result is Declined && msg is PointerMsg) return offerOutward(msg, ctx, targets);
    return result;
  }
  return const Declined();
}

/// What a focus-traversal key does.
sealed class FocusAction {
  /// Const constructor for subclasses.
  const FocusAction();
}

/// Move focus to the next member, wrapping at the end.
class FocusNext extends FocusAction {
  /// Creates a next-focus action.
  const FocusNext();
}

/// Move focus to the previous member, wrapping at the start.
class FocusPrevious extends FocusAction {
  /// Creates a previous-focus action.
  const FocusPrevious();
}

/// Move focus to the member named [id].
///
/// Naming an id that is not a current member is a no-op: the key that
/// resolved to it is still consumed (so it never leaks to the focused widget
/// or an app's fallback keys), but focus does not move and no change callback
/// fires.
class FocusTo extends FocusAction {
  /// Creates a jump-to-member action.
  const FocusTo(this.id);

  /// The id of the member to focus.
  final String id;
}

/// Tab and Shift+Tab, bound to [FocusNext] and [FocusPrevious].
///
/// These are the only traversal keys every terminal delivers unmodified and
/// every terminal user already expects to move focus, so they are the
/// default and the only default. Returns a fresh, mutable instance on every
/// call — extend it with app-specific jumps before handing it to
/// [FocusRouter]:
///
/// ```dart
/// defaultFocusBindings()..map(['alt+1'], const FocusTo('sidebar'));
/// ```
KeyBinding<FocusAction> defaultFocusBindings() => KeyBinding<FocusAction>()
  ..map(['tab'], const FocusNext())
  ..map(['shift+tab'], const FocusPrevious());

/// Routes keyboard and pointer traffic among a [FocusGroup] and its chrome.
///
/// A router owns none of the widgets it routes to — [focus], [extras] and
/// [aliases] are all held by reference and re-read on every [route] call, so
/// swapping a member, growing the extras list, or editing an alias needs no
/// notice to the router. There is no registration step.
///
/// [extras] are components reachable by pointer but never by focus — a
/// wheel-only scroll surface, a status strip — routed by id like any member
/// but skipped by Tab and by click-to-focus. [aliases] lets chrome around a
/// member (a border, a title row) stand in for it: an alias entry maps the
/// chrome's own tagged id to the member id it decorates.
///
/// An app calls [route] as one arm of its own `update`, after any message it
/// wants to intercept first and ahead of its fallback keys — fallback keys
/// run only for input every widget declined, so a quit key can never fire
/// while someone is typing into a focused editor:
///
/// ```dart
/// update: (model, msg, ctx) {
///   switch (model.router.route(msg, ctx)) {
///     case Handled(:final cmd):
///       return (model, cmd);
///     case Declined():
///       break; // nothing consumed it — the app's turn
///   }
///   if (msg case KeyMsg(key: 'q')) return (model, const Quit());
///   return (model, null);
/// }
/// ```
class FocusRouter {
  /// Creates a router over [focus].
  ///
  /// [bindings] defaults to a fresh [defaultFocusBindings]. [clickToFocus]
  /// governs whether a press on a member (direct or via [aliases]) moves
  /// focus to it before the press is delivered; [onFocusChange] fires with
  /// the newly focused component whenever focus actually changes, from
  /// traversal keys or from a click.
  FocusRouter(
    this.focus, {
    this.extras = const [],
    this.aliases = const {},
    KeyBinding<FocusAction>? bindings,
    this.clickToFocus = true,
    this.onFocusChange,
  }) : bindings = bindings ?? defaultFocusBindings();

  /// The group whose members receive keyboard focus.
  final FocusGroup<Component> focus;

  /// Components reachable by pointer but never focused.
  final List<Component> extras;

  /// Chrome id → member id, for chrome that should route and click-to-focus
  /// like the member it decorates.
  final Map<String, String> aliases;

  /// The key-to-[FocusAction] bindings consulted before a [KeyMsg] reaches
  /// the focused member.
  final KeyBinding<FocusAction> bindings;

  /// Whether a press on a member moves focus to it.
  final bool clickToFocus;

  /// Called with the newly focused component whenever focus changes.
  final void Function(Component current)? onFocusChange;

  /// Routes one message: a traversal key to a focus change, pointer traffic
  /// to its addressed target, and every other message to the focused member.
  ///
  /// The router routes by address, never by message class — it never decides
  /// for a widget which messages it can handle. A [KeyMsg] bound to a
  /// [FocusAction] never reaches the focused member — the traversal channel
  /// is reserved, which is what keeps a consume-everything widget escapable.
  /// Everything else that is not pointer traffic — an unbound key, a
  /// [PasteMsg], a message the router has never heard of — goes to the
  /// focused member and is handled or declined exactly as that member
  /// decides. Commands the member produces pass through untouched, and a
  /// [Declined] verdict means no widget consumed the message, so it is still
  /// the app's to act on.
  ///
  /// Pointer traffic ([Routed]) is the exception to focus addressing because
  /// it carries its own address: a resolvable target id (via [aliases] if
  /// need be) dispatches to that member; a background press or an unknown id
  /// declines — positional traffic is never re-aimed at the focused member.
  UpdateResult route(Msg msg, UpdateContext ctx) {
    if (msg is KeyMsg) {
      final action = bindings.resolve(msg);
      if (action == null) return focus.focused.update(msg);
      _apply(action);
      return const Handled();
    }

    if (msg case Routed(:final targetId?)) {
      final targets = _targets();
      var memberId = targetId;
      var viaAlias = false;
      if (!targets.containsKey(memberId)) {
        final aliased = aliases[targetId];
        if (aliased == null || !targets.containsKey(aliased)) return const Declined();
        memberId = aliased;
        viaAlias = true;
      }

      if (clickToFocus && focusOnPress(msg, focus, aliases: aliases)) {
        onFocusChange?.call(focus.focused);
      }

      var routed = msg;
      if (viaAlias && msg is PointerMsg) {
        final rect = ctx.hits.rectOf(memberId);
        if (rect == null) return const Declined();
        // Re-resolve the region against the member's own parts at the pointer:
        // the incoming region was scoped to the chrome, so retarget takes a
        // fresh one rather than carrying the chrome's over.
        final region = ctx.hits.regionAt(memberId, msg.global.x, msg.global.y);
        routed = msg.retarget(targetId: memberId, targetRect: rect, region: region);
      }

      // A leave or cancel reached via alias keeps the chrome id — it has no
      // position to rebuild from — so the delivery map must resolve that id
      // too, or the lookup below would miss the member it decorates.
      final delivery = viaAlias ? {...targets, targetId: targets[memberId]!} : targets;
      return routeToTarget(routed, ctx, delivery);
    }

    // Positional traffic that carries no target — a background press. Never
    // re-aim it at the focused member: it would deliver a pointer to a widget
    // the cursor was never over.
    if (msg is Routed) return const Declined();

    return focus.focused.update(msg);
  }

  Map<String, Component> _targets() {
    final targets = <String, Component>{};
    for (final member in focus.children) {
      targets[member.id] = member;
    }
    for (final extra in extras) {
      targets[extra.id] = extra;
    }
    return targets;
  }

  void _apply(FocusAction action) {
    switch (action) {
      case FocusNext():
        _cycle(1);
      case FocusPrevious():
        _cycle(-1);
      case FocusTo(:final id):
        _focusTo(id);
    }
  }

  void _cycle(int delta) {
    final before = focus.focused;
    focus.cycle(delta);
    if (!identical(focus.focused, before)) onFocusChange?.call(focus.focused);
  }

  void _focusTo(String id) {
    final index = focus.children.indexWhere((c) => c.id == id);
    if (index == -1 || index == focus.index) return;
    focus.setIndex(index);
    onFocusChange?.call(focus.focused);
  }
}
