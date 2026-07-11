import 'package:kiko/kiko.dart';

/// Offers a pointer message a widget declined to whatever encloses its
/// target, inside out.
///
/// The framework never bubbles a pointer event — [Component.update] resolves
/// only the innermost tagged widget under the cursor, and a [Declined] result
/// leaves the message in flight for the app to route onward if it chooses.
/// This is that routing, built once instead of once per app: walk
/// `ctx.hits.hitPath(msg.global.x, msg.global.y)` from the inside out,
/// excluding the widget that just declined, and offer the message to the
/// first enclosing id present in [targets] — the same map the app's own
/// pointer-routing line already reads. The first [Handled] wins and is
/// returned as-is, so the result chains exactly where the decliner's own
/// [Declined] would have; if nobody along the walk answers, this itself
/// declines.
///
/// App-invoked, never framework-invoked — a [Declined] carries no payload
/// (0142) and a widget cannot see its own siblings, so only the app, which
/// owns both the hit path and the targets map, can walk it. Resolves purely
/// by [PointerMsg.global], so it only makes sense for a positional event; a
/// wheel declined at a scroll limit — so a nesting ancestor gets the notch —
/// is the canonical caller. Never call this for a [PointerLeaveMsg] or
/// [PointerCancelMsg]: neither carries a position to walk from, and a
/// captured gesture already addresses its captor directly, so the wheel's
/// canonical case never needs re-offering under capture either.
///
/// An enclosing region the app handles directly, with no [Component] behind
/// it, is not reachable through [targets] — walk [UpdateContext.hits] inline
/// for that case instead.
UpdateResult offerOutward(PointerMsg msg, UpdateContext ctx, Map<String, Component> targets) {
  final path = ctx.hits.hitPath(msg.global.x, msg.global.y);
  for (final hit in path.reversed.skip(1)) {
    final target = targets[hit.id];
    if (target == null) continue;
    final result = target.update(msg);
    if (result is Handled) return result;
  }
  return const Declined();
}
