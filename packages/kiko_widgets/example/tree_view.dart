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
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel with ThemeSwitcher {
  final StaticTreeDataSource<void> treeData = StaticTreeDataSource(buildFileTree());
  final tree = TreeViewModel<void>(focused: true);

  String? selectedPath;
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
  return Task<List<TreeNode<void>>>(
    () => switch (key) {
      RootsKey() => model.treeData.getRoots(),
      PathKey(:final path) => model.treeData.getChildren(path),
      _ => Future.value(<TreeNode<void>>[]),
    },
    onSuccess: (data) => LoadResult<List<TreeNode<void>>>(req.id, key: key, data: data),
    onError: (e) => LoadResult<List<TreeNode<void>>>(req.id, key: key, error: e),
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
      case final LoadRequest r when r.id == model.tree.id:
        effect = fetchFor(model, r);
      case TreeActionCmd(:final path):
        model.selectedPath = path;
      case _:
        break; // expand/collapse events need no app effect here
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
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.bg));

  final treeWidget = Box(
    border: BorderType.plain,
    borderStyle: theme.focus,
    topTitles: [Line('File Browser', style: theme.focus)],
    child: TreeView(
      model: model.tree,
      theme: theme,
    ),
  );

  final infoBox = ConstrainedBox(
    additionalConstraints: const BoxConstraints(minH: 3, maxH: 3),
    child: Box(
      border: BorderType.plain,
      borderStyle: model.selectedPath != null ? theme.success : theme.border,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      topTitles: [Line('Selected')],
      child: Line(
        model.selectedPath ?? 'Press Enter to select',
        style: model.selectedPath != null ? Style(fg: theme.success.fg) : theme.muted,
      ),
    ),
  );

  final help = Row(
    children: [
      Expanded(
        child: Line(
          '↑↓/jk nav | →/l expand | ←/h collapse | Enter select | Esc quit',
          style: theme.muted,
        ),
      ),
      ConstrainedBox(
        additionalConstraints: const BoxConstraints(minW: 25, maxW: 25),
        child: Line('Theme: ${model.themeName} (F1/F2)', style: theme.muted),
      ),
    ],
  );

  final ui = Box(
    topTitles: [Line('TreeView Demo', style: theme.muted)],
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
  await Application(title: 'TreeView Demo').run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
