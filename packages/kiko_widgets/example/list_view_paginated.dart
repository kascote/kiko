// Paginated ListView with simulated API loading.
//
// Shows:
// - A PageSource over a simulated offset API, with fetchInto as the ferry glue
// - LoadRequest / LoadResult handling, keyed by page number
// - A demand pass that may ask for several pages at once (flattened by the app)
// - The frame-tick arm that pumps demand after a resize
// - Sliding window (keeps the pages around the viewport, plus keepPages more)
// - Placeholder items while a page is on its way
// - Click-to-select, wheel-scroll, per-row hover; scrolling near the edge
//   pages the next/previous batch in, same as cursor nav

import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// ═══════════════════════════════════════════════════════════
// DATA
// ═══════════════════════════════════════════════════════════

class User {
  final String id;
  final String name;
  final String role;

  const User(this.id, this.name, this.role);
}

/// A simulated user API: an offset-and-limit endpoint with a slow round trip.
///
/// This is app code — the shape a real REST or SQL backend has. Kiko only sees
/// it through the [PageSource] adapter below.
class UserApi {
  static const _totalUsers = 50;

  /// The users at `[offset, offset + limit)`, after a simulated network delay.
  Future<List<User>> read(int offset, int limit) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (offset >= _totalUsers) return [];
    final count = (offset + limit > _totalUsers) ? _totalUsers - offset : limit;
    return [
      for (var i = 0; i < count; i++) User('u${offset + i + 1}', 'User ${offset + i + 1}', _roleFor(offset + i + 1)),
    ];
  }

  String _roleFor(int n) {
    if (n % 10 == 1) return 'Admin';
    if (n % 5 == 0) return 'Manager';
    return 'Member';
  }
}

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel with ThemeSwitcher {
  final api = UserApi();

  /// The one page size in the app: the list windows over what the source ships.
  late final PageSource<User> source = PageSource.offset<User>(pageSize: 10, read: api.read);

  late final list = ListViewModel<User, String>(
    itemKey: (u) => u.id,
    itemHeight: 2,
    pageSize: source.pageSize,
    focused: true,
  );

  String? error;
  bool initialized = false;
}

// ═══════════════════════════════════════════════════════════
// LOAD PLUMBING (one shape for the first page and each demanded page)
// ═══════════════════════════════════════════════════════════

/// One request, one fetch — explicit cases, read top to bottom.
///
/// [fetchInto] threads the request's id and key into the result, so a page can
/// only ever land on the widget that asked for it, and turns a read that throws
/// into a failed load rather than a page stuck loading forever.
Cmd fetchFor(AppModel model, LoadRequest req) {
  if (req.id == model.list.id) return fetchInto(req, model.source);
  // Nothing is wired to answer this one, which is a bug rather than a policy:
  // it resolves as a failure, so the widget shows it instead of a placeholder
  // nobody will ever fill.
  return declineLoad(req, error: 'no source wired for ${req.id}');
}

/// One demand pass can ask for several pages at once, so the app flattens
/// whatever the list returned and fetches each request.
Cmd? fetchAll(AppModel model, Cmd? cmd) {
  final requests = switch (cmd) {
    final LoadRequest r => [r],
    Batch(:final cmds) => cmds.whereType<LoadRequest>().toList(),
    _ => const <LoadRequest>[],
  };
  if (requests.isEmpty) return cmd;
  return Batch([for (final r in requests) fetchFor(model, r)]);
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext _) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // Page results route home by id, then install generically — applyLoad clears
  // the slot on success or records the error on failure.
  if (msg case final LoadResult<Object?> r) {
    if (r.id == model.list.id) {
      model.list.applyLoad(r);
      // `ok` is false for a refusal as well as a failure, so check `cancelled`
      // first: a refused page did not fail, and reporting it as an error would
      // be a lie the user has to dismiss.
      if (!r.cancelled) model.error = r.ok ? null : 'Failed to load: ${r.error}';
    }
    return (model, null);
  }

  // Kick off the first page once.
  if (msg is InitMsg && !model.initialized) {
    model.initialized = true;
    return (model, fetchFor(model, model.list.loadFirstPage()));
  }

  // A pointer only reaches the list when it's actually the target — a click
  // on unrelated chrome (the status box, the help row) has a different
  // target (or none) and must not be treated as a click on the list.
  if (msg case Routed(:final targetId) when targetId != model.list.id) {
    return (model, null);
  }

  // A resize reveals items through the paint path, where the list cannot
  // return a command, and a page landing can free a slot the in-flight cap
  // truncated. One arm on the frame tick covers both.
  if (msg is FrameTickMsg) {
    return (model, fetchAll(model, model.list.demandIfDirty()));
  }

  // Navigation runs a demand pass, which may ask for one page or several.
  final result = model.list.update(msg);

  switch (result) {
    case Handled(:final cmd):
      return (model, fetchAll(model, cmd));
    case Declined():
      break;
  }

  // Quit
  if (msg case KeyMsg(:final key)) {
    if (key == 'escape' || key == 'ctrl+q') {
      return (model, const Quit());
    }
  }

  return (model, null);
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════

void appView(AppModel model, Frame frame) {
  final theme = model.theme;
  final resolver = StyleResolver(theme);
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.color));

  final loading = model.list.isLoading();

  // Status indicator
  final countStr = model.list.knownItemCount?.toString() ?? '?';
  final status = loading ? 'Loading...' : model.error ?? 'Loaded pages ${model.list.cachedPages} of $countStr users';

  // Scroll position
  final scroll = model.list.getScrollState();
  final scrollInfo = scroll.total != null
      ? 'Scroll: ${scroll.offset + 1}-${(scroll.offset + scroll.visible).clamp(0, scroll.total!)}/${scroll.total}'
      : '';

  final statusBorder = resolver.resolve(
    theme.success.ink,
    {
      if (loading) WidgetState.loading,
      if (model.error != null) WidgetState.error,
    },
    cls: PaintClass.ink,
  );
  final statusFg = model.error != null
      ? theme.error.color
      : loading
      ? theme.warning.color
      : theme.success.color;

  final ui = Container(
    topTitles: [Line('Paginated ListView Demo', style: theme.muted.ink)],
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            border: BorderType.plain,
            borderStyle: resolver.border(const {WidgetState.focused}),
            topTitles: [Line('Users', style: theme.focus.ink)],
            child: ListView(
              model: model.list,
              theme: theme,
              itemBuilder: (user, index, state) {
                final roleStyle = switch (user.role) {
                  'Admin' => Style(fg: theme.error.color, addModifier: Modifier.italic),
                  'Manager' => Style(fg: theme.warning.color),
                  'Member' => Style(fg: theme.accent.color),
                  _ => theme.muted.ink,
                };
                return [
                  Line(' ${user.name}', style: const Style(addModifier: Modifier.bold)),
                  Line('  ${user.role} (${user.id})', style: roleStyle),
                ];
              },
              separatorBuilder: () => Line.fromTexts([Text('─' * 30, style: theme.border.ink)]),
              // Shows only when the data itself is empty. A page on its way
              // makes its rows addressable, so a loading list paints skeleton
              // rows instead of ever reaching this line.
              emptyPlaceholder: Line('No users', style: theme.muted.ink),
            ),
          ),
        ),
        ConstrainedBox(
          additionalConstraints: const BoxConstraints(minH: 3, maxH: 3),
          child: Container(
            border: BorderType.plain,
            borderStyle: statusBorder,
            padding: const EdgeInsets.symmetric(horizontal: 1),
            topTitles: [Line('Status')],
            child: Line(status, style: Style(fg: statusFg)),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Line('↑↓/jk/click nav | PgUp/PgDn/wheel page | $scrollInfo | Esc quit', style: theme.muted.ink),
            ),
            ConstrainedBox(
              additionalConstraints: const BoxConstraints(minW: 25, maxW: 25),
              child: Line('Theme: ${model.themeName} (F1/F2)', style: theme.muted.ink),
            ),
          ],
        ),
      ],
    ),
  );

  frame.render(ui);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

Future<void> main() async {
  exit(
    await Application(title: 'Paginated ListView Demo', mouseEvents: true).run(
      init: AppModel(),
      update: appUpdate,
      view: appView,
    ),
  );
}
