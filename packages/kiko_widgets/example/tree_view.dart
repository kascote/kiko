// Basic TreeView example with folder/file structure.
//
// Shows:
// - Tree setup with StaticTreeDataSource
// - Expand/collapse navigation (arrows, h/l)
// - Icons for folders and files
// - Confirm action (Enter)

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// ═══════════════════════════════════════════════════════════
// DATA
// ═══════════════════════════════════════════════════════════

List<TreeNode<void>> buildFileTree() => [
  TreeNode(
    path: '/documents',
    label: Line('Documents', style: const Style(fg: .blue)),
  ),
  TreeNode(path: '/documents/work', label: Line('Work')),
  TreeNode(path: '/documents/work/report.pdf', label: Line('report.pdf'), isLeaf: true),
  TreeNode(path: '/documents/work/presentation.pptx', label: Line('presentation.pptx'), isLeaf: true),
  TreeNode(path: '/documents/personal', label: Line('Personal')),
  TreeNode(path: '/documents/personal/notes.txt', label: Line('notes.txt'), isLeaf: true),
  TreeNode(path: '/documents/personal/todo.md', label: Line('todo.md'), isLeaf: true),
  TreeNode(
    path: '/downloads',
    label: Line('Downloads', style: const Style(fg: .yellow)),
  ),
  TreeNode(path: '/downloads/image.png', label: Line('image.png'), isLeaf: true),
  TreeNode(path: '/downloads/archive.zip', label: Line('archive.zip'), isLeaf: true),
  TreeNode(
    path: '/music',
    label: Line('Music', style: const Style(fg: .magenta)),
  ),
  TreeNode(path: '/music/song1.mp3', label: Line('song1.mp3'), isLeaf: true),
  TreeNode(path: '/music/song2.mp3', label: Line('song2.mp3'), isLeaf: true),
];

// ═══════════════════════════════════════════════════════════
// MESSAGES
// ═══════════════════════════════════════════════════════════

// Async fetch results carry the owning tree's id so the app routes each result
// back to the right instance (§3.4 of a2.1-id-addressing). The app owns the
// data source and drives every fetch — the widget never performs I/O.
class TreeRootsLoadedMsg extends Msg {
  final String id;
  final List<TreeNode<void>> roots;
  TreeRootsLoadedMsg(this.id, this.roots);
}

class TreeChildrenLoadedMsg extends Msg {
  final String id;
  final String path;
  final List<TreeNode<void>> children;
  TreeChildrenLoadedMsg(this.id, this.path, this.children);
}

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel with ThemeSwitcher {
  final StaticTreeDataSource<void> treeData = StaticTreeDataSource(buildFileTree());
  final tree = TreeViewModel<void>(focused: true);

  String? selectedPath;
  bool initialized = false;
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // Initialize on first message — the app drives the root fetch.
  if (msg is InitMsg && !model.initialized) {
    model.initialized = true;
    model.tree.isLoading = true;
    return (
      model,
      Task(
        model.treeData.getRoots,
        onSuccess: (roots) => TreeRootsLoadedMsg(model.tree.id, roots),
      ),
    );
  }

  // Fetch results resolve home by id (single instance: a guard).
  if (msg case TreeRootsLoadedMsg(:final id, :final roots)) {
    if (id == model.tree.id) model.tree.applyRoots(roots);
    return (model, null);
  }
  if (msg case TreeChildrenLoadedMsg(:final id, :final path, :final children)) {
    if (id == model.tree.id) model.tree.applyChildren(path, children);
    return (model, null);
  }

  final cmd = model.tree.update(msg);

  // Expand load request → app drives the children fetch.
  if (cmd case TreeExpandCmd(:final id, :final path)) {
    if (id != model.tree.id) return (model, null);
    return (
      model,
      Task(
        () => model.treeData.getChildren(path),
        onSuccess: (children) => TreeChildrenLoadedMsg(id, path, children),
      ),
    );
  }

  // Handle confirm
  if (cmd case TreeActionCmd(:final path)) {
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
  final theme = model.theme;
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.bg));

  final treeWidget = Block(
    borders: Borders.all,
    borderStyle: theme.focus,
    padding: const EdgeInsets.all(1),
    child: TreeView(
      model: model.tree,
      theme: theme,
    ),
  ).titleTop(Line('File Browser', style: theme.focus));

  final infoBox = Fixed(
    3,
    child: Block(
      borders: Borders.all,
      borderStyle: model.selectedPath != null ? theme.success : theme.border,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text.raw(
        model.selectedPath ?? 'Press Enter to select',
        style: model.selectedPath != null ? Style(fg: theme.success.fg) : theme.muted,
      ),
    ).titleTop(Line('Selected')),
  );

  final help = Fixed(
    1,
    child: Row(
      children: [
        Expanded(
          child: Text.raw(
            '↑↓/jk nav | →/l expand | ←/h collapse | Enter select | Esc quit',
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
        Expanded(child: treeWidget),
        infoBox,
        help,
      ],
    ),
  ).titleTop(Line('TreeView Demo', style: theme.muted));

  frame.renderWidget(ui, frame.area);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

void main() async {
  await Application(title: 'TreeView Demo').run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
