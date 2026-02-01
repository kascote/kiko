// Paginated ListView with simulated API loading.
//
// Shows:
// - Custom ListDataSource for accumulating data
// - LoadMoreCmd handling for infinite scroll
// - Loading state indicator
// - Async data fetching with AsyncCmd

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

// ═══════════════════════════════════════════════════════════
// DATA SOURCE
// ═══════════════════════════════════════════════════════════

class User {
  final String id;
  final String name;
  final String role;

  const User(this.id, this.name, this.role);
}

/// Simulated API data source that loads pages of users.
class UserApiDataSource implements ListDataSource<User> {
  final List<User> _users = [];
  bool _hasMore = true;
  static const _pageSize = 10;
  static const _totalUsers = 50;

  @override
  int get length => _users.length;

  @override
  User itemAt(int index) => _users[index];

  @override
  bool get hasMore => _hasMore;

  /// Simulates API call with delay.
  Future<void> loadMore() async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final offset = _users.length;
    final remaining = _totalUsers - offset;
    final count = remaining.clamp(0, _pageSize);

    for (var i = 0; i < count; i++) {
      final n = offset + i + 1;
      _users.add(User('u$n', 'User $n', _roleFor(n)));
    }

    _hasMore = _users.length < _totalUsers;
  }

  String _roleFor(int n) {
    if (n % 10 == 1) return 'Admin';
    if (n % 5 == 0) return 'Manager';
    return 'Member';
  }
}

// ═══════════════════════════════════════════════════════════
// MESSAGES
// ═══════════════════════════════════════════════════════════

class UsersLoadedMsg extends Msg {}

class UsersLoadErrorMsg extends Msg {
  final Object error;
  UsersLoadErrorMsg(this.error);
}

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel {
  final dataSource = UserApiDataSource();
  late final list = ListViewModel<User, String>(
    dataSource: dataSource,
    itemKey: (u) => u.id,
    itemHeight: 2,
    focused: true,
  );

  String? error;
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  // Initial load on startup
  if (msg is InitMsg) {
    model.list.isLoading = true;
    return (
      model,
      Task(
        model.dataSource.loadMore,
        onSuccess: (_) => UsersLoadedMsg(),
        onError: UsersLoadErrorMsg.new,
      ),
    );
  }

  // Handle load completion
  if (msg is UsersLoadedMsg) {
    model
      ..list.isLoading = false
      ..error = null;
    return (model, null);
  }
  if (msg is UsersLoadErrorMsg) {
    model
      ..list.isLoading = false
      ..error = 'Failed to load: ${msg.error}';
    return (model, null);
  }

  // Route to list
  final cmd = model.list.update(msg);

  // Handle load more
  if (cmd case ListLoadMoreCmd(:final source)) {
    if (source == model.list && !model.list.isLoading) {
      model.list.isLoading = true;
      return (
        model,
        Task(
          model.dataSource.loadMore,
          onSuccess: (_) => UsersLoadedMsg(),
          onError: UsersLoadErrorMsg.new,
        ),
      );
    }
    return (model, null);
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
  // Status indicator
  final status = model.list.isLoading ? 'Loading...' : model.error ?? 'Loaded ${model.list.dataSource.length} users';

  final listWidget = Block(
    borders: Borders.all,
    borderStyle: const Style(fg: Color.green),
    child: ListView(
      model: model.list,
      itemBuilder: (user, index, state) {
        final nameStyle = Style(
          fg: state.focused ? Color.black : Color.white,
          bg: state.focused ? Color.green : null,
          addModifier: Modifier.bold,
        );

        final roleStyle = state.focused
            ? const Style(
                fg: Color.black,
                bg: Color.green,
              )
            : switch (user.role) {
                'Admin' => const Style(fg: Color.red, addModifier: Modifier.italic),
                'Manager' => const Style(fg: Color.yellow),
                'Member' => const Style(fg: Color.blue),
                _ => const Style(fg: Color.gray),
              };

        return Column(
          children: [
            Fixed(1, child: Line(' ${user.name}', style: nameStyle)),
            Fixed(1, child: Line('  ${user.role} (${user.id})', style: roleStyle)),
          ],
        );
      },
      separatorBuilder: () => Line.fromSpans([Span('─' * 30, style: const Style(fg: Color.darkGray))]),
      emptyPlaceholder: Text.raw(
        model.list.isLoading ? 'Loading...' : 'No users',
        style: const Style(fg: Color.darkGray),
      ),
    ),
  ).titleTop(Line('Users'));

  final statusBox = Fixed(
    3,
    child: Block(
      borders: Borders.all,
      borderStyle: model.error != null
          ? const Style(fg: Color.red)
          : model.list.isLoading
          ? const Style(fg: Color.yellow)
          : const Style(fg: Color.green),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text.raw(
        status,
        style: Style(
          fg: model.error != null
              ? Color.red
              : model.list.isLoading
              ? Color.yellow
              : Color.green,
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
    child: Text.raw(
      '↑↓/jk nav | PgUp/PgDn page | $scrollInfo | Esc quit',
      alignment: Alignment.center,
      style: const Style(fg: Color.darkGray),
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
  ).titleTop(Line('Paginated ListView Demo', style: const Style(fg: Color.darkGray)));

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
