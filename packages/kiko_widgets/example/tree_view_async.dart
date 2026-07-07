// Async TreeView example with lazy-loaded nodes.
//
// Shows:
// - Custom async TreeDataSource with simulated delays
// - Multiple depth levels loaded on-demand
// - Loading indicators while fetching
// - Error placeholder on a failed load (expand Electronics → Audio), with
//   collapse + expand to retry — instead of an endless spinner
// - Styled labels with colors

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// ═══════════════════════════════════════════════════════════
// ASYNC DATA SOURCE
// ═══════════════════════════════════════════════════════════

/// Category data record.
typedef Category = ({String name, String icon, bool hasChildren});

/// Simulates a remote API with delayed responses.
class AsyncCategorySource extends TreeDataSource<Category> {
  // Simulated data structure - in real app this would be API calls
  static final _data = <String, List<Category>>{
    // Root categories
    '': [
      (name: 'Electronics', icon: '🔌', hasChildren: true),
      (name: 'Clothing', icon: '👕', hasChildren: true),
      (name: 'Books', icon: '📚', hasChildren: true),
      (name: 'Sports', icon: '⚽', hasChildren: true),
    ],
    // Electronics subcategories
    '/Electronics': [
      (name: 'Computers', icon: '💻', hasChildren: true),
      (name: 'Phones', icon: '📱', hasChildren: true),
      (name: 'Audio', icon: '🎧', hasChildren: true),
    ],
    '/Electronics/Computers': [
      (name: 'Laptops', icon: '💻', hasChildren: true),
      (name: 'Desktops', icon: '🖥️', hasChildren: true),
      (name: 'Tablets', icon: '📱', hasChildren: false),
    ],
    '/Electronics/Computers/Laptops': [
      (name: 'Gaming Laptops', icon: '🎮', hasChildren: false),
      (name: 'Ultrabooks', icon: '✨', hasChildren: false),
      (name: 'Workstations', icon: '🔧', hasChildren: false),
    ],
    '/Electronics/Computers/Desktops': [
      (name: 'Gaming PCs', icon: '🎮', hasChildren: false),
      (name: 'Office PCs', icon: '📊', hasChildren: false),
      (name: 'Servers', icon: '🖥️', hasChildren: false),
    ],
    '/Electronics/Phones': [
      (name: 'Smartphones', icon: '📱', hasChildren: false),
      (name: 'Feature Phones', icon: '📞', hasChildren: false),
      (name: 'Accessories', icon: '🔋', hasChildren: false),
    ],
    '/Electronics/Audio': [
      (name: 'Headphones', icon: '🎧', hasChildren: false),
      (name: 'Speakers', icon: '🔊', hasChildren: false),
      (name: 'Microphones', icon: '🎤', hasChildren: false),
    ],
    // Clothing subcategories
    '/Clothing': [
      (name: 'Men', icon: '👔', hasChildren: true),
      (name: 'Women', icon: '👗', hasChildren: true),
      (name: 'Kids', icon: '🧒', hasChildren: true),
    ],
    '/Clothing/Men': [
      (name: 'Shirts', icon: '👕', hasChildren: false),
      (name: 'Pants', icon: '👖', hasChildren: false),
      (name: 'Shoes', icon: '👟', hasChildren: false),
    ],
    '/Clothing/Women': [
      (name: 'Dresses', icon: '👗', hasChildren: false),
      (name: 'Tops', icon: '👚', hasChildren: false),
      (name: 'Shoes', icon: '👠', hasChildren: false),
    ],
    '/Clothing/Kids': [
      (name: 'Boys', icon: '👦', hasChildren: false),
      (name: 'Girls', icon: '👧', hasChildren: false),
    ],
    // Books subcategories
    '/Books': [
      (name: 'Fiction', icon: '📖', hasChildren: true),
      (name: 'Non-Fiction', icon: '📘', hasChildren: true),
      (name: 'Comics', icon: '📕', hasChildren: false),
    ],
    '/Books/Fiction': [
      (name: 'Fantasy', icon: '🧙', hasChildren: false),
      (name: 'Sci-Fi', icon: '🚀', hasChildren: false),
      (name: 'Mystery', icon: '🔍', hasChildren: false),
      (name: 'Romance', icon: '💕', hasChildren: false),
    ],
    '/Books/Non-Fiction': [
      (name: 'Biography', icon: '👤', hasChildren: false),
      (name: 'Science', icon: '🔬', hasChildren: false),
      (name: 'History', icon: '📜', hasChildren: false),
    ],
    // Sports subcategories
    '/Sports': [
      (name: 'Team Sports', icon: '🏀', hasChildren: true),
      (name: 'Individual', icon: '🏃', hasChildren: true),
      (name: 'Outdoor', icon: '🏕️', hasChildren: false),
    ],
    '/Sports/Team Sports': [
      (name: 'Football', icon: '⚽', hasChildren: false),
      (name: 'Basketball', icon: '🏀', hasChildren: false),
      (name: 'Baseball', icon: '⚾', hasChildren: false),
    ],
    '/Sports/Individual': [
      (name: 'Tennis', icon: '🎾', hasChildren: false),
      (name: 'Golf', icon: '⛳', hasChildren: false),
      (name: 'Swimming', icon: '🏊', hasChildren: false),
    ],
  };

  /// Simulated network delay (varies by depth for realism).
  Future<void> _simulateDelay(String path) async {
    final depth = path.isEmpty ? 0 : path.split('/').where((s) => s.isNotEmpty).length;
    // Deeper = slightly faster (cached in real scenarios)
    final delay = 300 + (300 ~/ (depth + 1));
    await Future<void>.delayed(Duration(milliseconds: delay));
  }

  List<TreeNode<Category>> _buildNodes(
    String parentPath,
    List<Category> items,
  ) {
    return items.map((item) {
      final path = '$parentPath/${item.name}';

      // Color based on depth
      final depth = path.split('/').where((s) => s.isNotEmpty).length;
      final color = switch (depth) {
        1 => Color.cyan,
        2 => Color.green,
        3 => Color.yellow,
        _ => Color.white,
      };

      return TreeNode<Category>(
        path: path,
        label: Line.fromTexts([Text(item.name, style: Style(fg: color))]),
        icon: item.icon,
        isLeaf: !item.hasChildren,
        data: item,
      );
    }).toList();
  }

  @override
  Future<List<TreeNode<Category>>> getRoots() async {
    await _simulateDelay('');
    final items = _data[''] ?? [];
    return _buildNodes('', items);
  }

  @override
  Future<List<TreeNode<Category>>> getChildren(String path) async {
    await _simulateDelay(path);
    // Simulate a flaky endpoint to show the Phase 2 fix: a failed child load
    // renders an error placeholder, it does not spin forever. Collapse + expand
    // to retry.
    if (path == '/Electronics/Audio') {
      throw StateError('simulated network error for $path');
    }
    final items = _data[path] ?? [];
    return _buildNodes(path, items);
  }
}

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel with ThemeSwitcher {
  final treeData = AsyncCategorySource();
  final tree = TreeViewModel<Category>(
    focused: true,
    showIcons: true,
    indicatorStyle: const Style(fg: Color.red),
    loadingIndicator: Line.fromTexts(const [
      Text(
        'Loading...',
        style: Style(fg: Color.darkGray, addModifier: Modifier.dim),
      ),
    ]),
    errorIndicator: Line.fromTexts(const [
      Text(
        '⚠ Failed to load — collapse + expand to retry',
        style: Style(fg: Color.red, addModifier: Modifier.dim),
      ),
    ]),
  );

  String? selectedPath;
  int expandCount = 0;
  bool initialized = false;
}

// ═══════════════════════════════════════════════════════════
// LOAD PLUMBING (one shape for roots and children)
// ═══════════════════════════════════════════════════════════

/// Flattens a possible [Batch] of widget commands into a list.
List<Cmd> flattenCmd(Cmd? cmd) => switch (cmd) {
  null => const [],
  Batch(:final cmds) => cmds,
  _ => [cmd],
};

/// Turns a [LoadRequest] into the fetch that resolves it, routing the outcome
/// home as a [LoadResult] (data on success, error on failure).
Cmd fetchFor(AppModel model, LoadRequest req) {
  final key = req.key;
  return Task<List<TreeNode<Category>>>(
    () => switch (key) {
      RootsKey() => model.treeData.getRoots(),
      PathKey(:final path) => model.treeData.getChildren(path),
      _ => Future.value(<TreeNode<Category>>[]),
    },
    onSuccess: (data) => LoadResult<List<TreeNode<Category>>>(req.id, key: key, data: data),
    onError: (e) => LoadResult<List<TreeNode<Category>>>(req.id, key: key, error: e),
  );
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // Load results route home by id, then install generically — one line for
  // roots and children alike.
  if (msg case final LoadResult<Object?> r) {
    if (r.id == model.tree.id) model.tree.applyLoad(r);
    return (model, null);
  }

  // Kick off the root load once.
  if (msg is InitMsg && !model.initialized) {
    model.initialized = true;
    return (model, fetchFor(model, model.tree.loadRoots()));
  }

  // Widget update may return an expand event, a load request, or both (Batch).
  final cmd = model.tree.update(msg);
  Cmd? effect;
  for (final c in flattenCmd(cmd)) {
    switch (c) {
      case TreeExpandCmd(:final id) when id == model.tree.id:
        model.expandCount++; // honest: counts every expansion, cached or not
      case TreeActionCmd(:final path):
        model.selectedPath = path;
      case final LoadRequest r when r.id == model.tree.id:
        effect = fetchFor(model, r);
      case _:
        break; // collapse and other events need no app effect
    }
  }
  if (effect != null) return (model, effect);
  if (cmd is! Unhandled) return (model, null);

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
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.color));

  final loadingStatus = model.tree.isLoading(const RootsKey())
      ? 'Loading roots...'
      : model.tree.isLoaded
      ? '${model.tree.flatNodes.length} nodes'
      : 'Not loaded';

  final treeWidget = Box(
    border: BorderType.plain,
    borderStyle: theme.focus.ink,
    topTitles: [
      Line.fromTexts([
        Text('Categories ', style: theme.focus.ink),
        Text('($loadingStatus)', style: theme.muted.ink),
      ]),
    ],
    child: TreeView(
      model: model.tree,
      theme: theme,
      emptyPlaceholder: Line('Loading categories...', style: theme.muted.ink),
    ),
  );

  final infoBox = ConstrainedBox(
    additionalConstraints: const BoxConstraints(minH: 4, maxH: 4),
    child: Box(
      border: BorderType.plain,
      borderStyle: model.selectedPath != null ? theme.success.ink : theme.border.ink,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      topTitles: [Line('Selected')],
      child: Column(
        crossAxis: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Line(
              model.selectedPath ?? 'Press Enter to select a category',
              style: model.selectedPath != null ? Style(fg: theme.success.color) : theme.muted.ink,
            ),
          ),
          Line('Expansions: ${model.expandCount}', style: theme.muted.ink),
        ],
      ),
    ),
  );

  final help = Row(
    children: [
      Expanded(
        child: Line(
          '↑↓/jk nav | →/l expand | ←/h collapse | Enter select | Esc quit',
          style: theme.muted.ink,
        ),
      ),
      ConstrainedBox(
        additionalConstraints: const BoxConstraints(minW: 25, maxW: 25),
        child: Line('Theme: ${model.themeName} (F1/F2)', style: theme.muted.ink),
      ),
    ],
  );

  final ui = Box(
    topTitles: [Line('Async TreeView Demo', style: theme.muted.ink)],
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: treeWidget),
        infoBox,
        help,
      ],
    ),
  );

  frame.render(ui);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

void main() async {
  await Application(title: 'Async TreeView Demo').run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
