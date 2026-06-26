// Paginated ListView with simulated API loading.
//
// Shows:
// - A widget-owned DataBuffer the model appends pages into
// - LoadRequest / LoadResult handling for infinite scroll
// - Loading + error state via the LoadTracker (no app-managed flag)
// - The app owns the fetcher closure; the widget never awaits

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

/// Simulated API — a pure fetcher the app owns. It returns one page at a given
/// offset; it holds no list state (the widget's buffer does that now).
class UserApi {
  static const pageSize = 10;
  static const _totalUsers = 50;

  /// Simulates an API call with a delay, returning the page at [offset].
  Future<List<User>> fetchPage(int offset) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final remaining = _totalUsers - offset;
    final count = remaining.clamp(0, pageSize);
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
  late final list = ListViewModel<User, String>(
    dataView: DataBuffer<User>(),
    itemKey: (u) => u.id,
    itemHeight: 2,
    pageSize: UserApi.pageSize,
    focused: true,
  );

  String? error;
  bool initialized = false;
}

// ═══════════════════════════════════════════════════════════
// LOAD PLUMBING (one shape for the first page and each near-edge page)
// ═══════════════════════════════════════════════════════════

/// Turns a list [LoadRequest] into the page fetch that resolves it, routing the
/// outcome home as a [LoadResult] (users on success, error on failure). The next
/// page starts where the buffer currently ends.
Cmd fetchUsers(AppModel model, LoadRequest req) {
  final offset = model.list.dataView.length ?? 0;
  return Task<List<User>>(
    () => model.api.fetchPage(offset),
    onSuccess: (users) => LoadResult<List<User>>(req.id, key: req.key, data: users),
    onError: (e) => LoadResult<List<User>>(req.id, key: req.key, error: e),
  );
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // Page results route home by id, then install generically — applyLoad appends
  // the page and clears the slot on success, or records the error on failure.
  if (msg case final LoadResult<Object?> r) {
    if (r.id == model.list.id) {
      model.list.applyLoad(r);
      model.error = r.ok ? null : 'Failed to load: ${r.error}';
    }
    return (model, null);
  }

  // Kick off the first page once.
  if (msg is InitMsg && !model.initialized) {
    model.initialized = true;
    return (model, fetchUsers(model, model.list.loadFirstPage()));
  }

  // A near-edge navigation may request the next page.
  final cmd = model.list.update(msg);
  if (cmd case final LoadRequest r when r.id == model.list.id) {
    return (model, fetchUsers(model, r));
  }

  if (cmd is! Unhandled) return (model, cmd);

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
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.bg));

  final loading = model.list.isLoading();

  // Status indicator
  final status = loading ? 'Loading...' : model.error ?? 'Loaded ${model.list.dataView.length} users';

  final listWidget = Block(
    borders: Borders.all,
    borderStyle: theme.focus,
    child: ListView(
      model: model.list,
      theme: theme,
      itemBuilder: (user, index, state) {
        final roleStyle = switch (user.role) {
          'Admin' => Style(fg: theme.error.fg, addModifier: Modifier.italic),
          'Manager' => Style(fg: theme.warning.fg),
          'Member' => Style(fg: theme.accent.fg),
          _ => theme.muted,
        };

        return Column(
          children: [
            Fixed(
              1,
              child: Line(' ${user.name}', style: const Style(addModifier: Modifier.bold)),
            ),
            Fixed(1, child: Line('  ${user.role} (${user.id})', style: roleStyle)),
          ],
        );
      },
      separatorBuilder: () => Line.fromSpans([Span('─' * 30, style: theme.border)]),
      emptyPlaceholder: Text.raw(
        loading ? 'Loading...' : 'No users',
        style: theme.muted,
      ),
    ),
  ).titleTop(Line('Users', style: theme.focus));

  final statusBox = Fixed(
    3,
    child: Block(
      borders: Borders.all,
      borderStyle: model.error != null
          ? theme.error
          : loading
          ? theme.warning
          : theme.success,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text.raw(
        status,
        style: Style(
          fg: model.error != null
              ? theme.error.fg
              : loading
              ? theme.warning.fg
              : theme.success.fg,
        ),
      ),
    ).titleTop(Line('Status')),
  );

  // Scroll position
  final scroll = model.list.getScrollState();
  final scrollInfo = scroll.total != null
      ? 'Scroll: ${scroll.offset + 1}-${(scroll.offset + scroll.visible).clamp(0, scroll.total!)}/${scroll.total}'
      : '';

  final help = Fixed(
    1,
    child: Row(
      children: [
        Expanded(
          child: Text.raw(
            '↑↓/jk nav | PgUp/PgDn page | $scrollInfo | Esc quit',
            style: theme.muted,
          ),
        ),
        Fixed(25, child: themeIndicator(model)),
      ],
    ),
  );

  final ui = Block(
    child: Column(
      children: [
        Expanded(child: listWidget),
        statusBox,
        help,
      ],
    ),
  ).titleTop(Line('Paginated ListView Demo', style: theme.muted));

  frame.renderWidget(ui, frame.area);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

void main() async {
  await Application(title: 'Paginated ListView Demo').run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
