// Basic TreeView example with folder/file structure.
//
// Shows:
// - Tree setup with StaticTreeDataSource
// - Expand/collapse navigation (arrows, h/l)
// - Icons for folders and files
// - Confirm action (Enter)

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

// ═══════════════════════════════════════════════════════════
// DATA
// ═══════════════════════════════════════════════════════════

List<TreeNode<void>> buildFileTree() => [
  TreeNode(path: '/documents', label: Line('Documents')),
  TreeNode(path: '/documents/work', label: Line('Work')),
  TreeNode(path: '/documents/work/report.pdf', label: Line('report.pdf'), isLeaf: true),
  TreeNode(path: '/documents/work/presentation.pptx', label: Line('presentation.pptx'), isLeaf: true),
  TreeNode(path: '/documents/personal', label: Line('Personal')),
  TreeNode(path: '/documents/personal/notes.txt', label: Line('notes.txt'), isLeaf: true),
  TreeNode(path: '/documents/personal/todo.md', label: Line('todo.md'), isLeaf: true),
  TreeNode(path: '/downloads', label: Line('Downloads')),
  TreeNode(path: '/downloads/image.png', label: Line('image.png'), isLeaf: true),
  TreeNode(path: '/downloads/archive.zip', label: Line('archive.zip'), isLeaf: true),
  TreeNode(path: '/music', label: Line('Music')),
  TreeNode(path: '/music/song1.mp3', label: Line('song1.mp3'), isLeaf: true),
  TreeNode(path: '/music/song2.mp3', label: Line('song2.mp3'), isLeaf: true),
];

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel {
  final tree = TreeViewModel<void>(
    dataSource: StaticTreeDataSource(buildFileTree()),
    focused: true,
  );

  String? selectedPath;
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
  final treeWidget = Block(
    borders: Borders.all,
    borderStyle: const Style(fg: Color.green),
    padding: const EdgeInsets.all(1),
    child: TreeView(
      model: model.tree,
      focusedStyle: const Style(fg: Color.black, bg: Color.green),
    ),
  ).titleTop(Line('File Browser'));

  final infoBox = Fixed(
    3,
    child: Block(
      borders: Borders.all,
      borderStyle: model.selectedPath != null ? const Style(fg: Color.green) : const Style(fg: Color.darkGray),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text.raw(
        model.selectedPath ?? 'Press Enter to select',
        style: Style(
          fg: model.selectedPath != null ? Color.white : Color.darkGray,
        ),
      ),
    ).titleTop(Line('Selected')),
  );

  final help = Fixed(
    1,
    child: Text.raw(
      '↑↓/jk nav | →/l expand | ←/h collapse | Enter select | Esc quit',
      alignment: Alignment.center,
      style: const Style(fg: Color.darkGray),
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
  ).titleTop(Line('TreeView Demo', style: const Style(fg: Color.darkGray)));

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
