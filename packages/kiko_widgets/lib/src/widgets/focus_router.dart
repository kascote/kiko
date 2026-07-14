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
/// return false. A router built on this fragment fires its focus-change
/// callback off the returned bool; an app that owns its own composition
/// calls it directly the same way.
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
/// id and a content id sharing one model). An assembled router composes this
/// with focus handling; an app can call it directly to keep the same wiring
/// while owning its own composition.
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
