// Async TreeView example with lazy-loaded nodes.
//
// Shows:
// - Custom async TreeDataSource with simulated delays
// - Multiple depth levels loaded on-demand
// - Loading indicators while fetching
// - Styled labels with colors

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

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
        label: Line.fromSpans([Span(item.name, style: Style(fg: color))]),
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
    final items = _data[path] ?? [];
    return _buildNodes(path, items);
  }
}

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel {
  final tree = TreeViewModel<Category>(
    dataSource: AsyncCategorySource(),
    focused: true,
    showIcons: true,
    indicatorStyle: const Style(fg: Color.red),
    loadingIndicator: Line.fromSpans(const [
      Span(
        'Loading...',
        style: Style(fg: Color.darkGray, addModifier: Modifier.dim),
      ),
    ]),
  );

  String? selectedPath;
  int loadCount = 0;
  bool initialized = false;
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  // Initialize on first message
  if (msg is InitMsg && !model.initialized) {
    model.initialized = true;
    return (model, Task(() async => model.tree.loadRoots()));
  }

  final cmd = model.tree.update(msg);

  // Track expand events
  if (cmd is TreeExpandCmd) {
    model.loadCount++;
    return (model, null);
  }

  // Handle confirm
  if (cmd case TreeConfirmCmd(:final path)) {
    model.selectedPath = path;
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
  final loadingStatus = model.tree.isLoading
      ? 'Loading roots...'
      : model.tree.isLoaded
      ? '${model.tree.flatNodes.length} nodes'
      : 'Not loaded';

  final treeWidget =
      Block(
        borders: Borders.all,
        borderStyle: const Style(fg: Color.blue),
        padding: const EdgeInsets.all(1),
        child: TreeView(
          model: model.tree,
          focusedStyle: const Style(fg: Color.black, bg: Color.blue),
          emptyPlaceholder: Text.raw(
            'Loading categories...',
            style: const Style(fg: Color.darkGray, addModifier: Modifier.dim),
          ),
        ),
      ).titleTop(
        Line.fromSpans([
          const Span('Categories ', style: Style(fg: Color.blue)),
          Span('($loadingStatus)', style: const Style(fg: Color.darkGray)),
        ]),
      );

  final infoBox = Fixed(
    4,
    child: Block(
      borders: Borders.all,
      borderStyle: Style(
        fg: model.selectedPath != null ? Color.green : Color.darkGray,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Column(
        children: [
          Expanded(
            child: Span(
              model.selectedPath ?? 'Press Enter to select a category',
              style: Style(
                fg: model.selectedPath != null ? Color.white : Color.darkGray,
              ),
            ),
          ),
          Fixed(
            1,
            child: Span(
              'Expansions: ${model.loadCount}',
              style: const Style(fg: Color.darkGray),
            ),
          ),
        ],
      ),
    ).titleTop(Line('Selected')),
  );

  final help = Fixed(
    1,
    child: Line(
      '↑↓/jk nav | →/l expand | ←/h collapse | Enter select | Esc quit',
      alignment: Alignment.center,
      style: const Style(fg: Color.darkGray),
    ),
  );

  final ui =
      Block(
        child: Column(
          children: [
            Expanded(child: treeWidget),
            infoBox,
            help,
          ],
        ),
      ).titleTop(
        Line('Async TreeView Demo', style: const Style(fg: Color.darkGray)),
      );

  frame.renderWidget(ui, frame.area);
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
