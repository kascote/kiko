// Basic TreeView example with folder/file structure.
//
// Shows:
// - Tree setup with StaticTreeDataSource
// - Expand/collapse navigation (arrows, h/l)
// - Icons for folders and files
// - Confirm action (Enter)
// - Click a node to expand/select, wheel-scroll, per-node hover

import 'dart:io';

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

/// Translates one widget event: a load request becomes a fetch, and an
/// activation records the selected path.
Cmd? onEvent(AppModel model, WidgetEvent event) {
  switch (event) {
    case final LoadRequest req when req.id == model.tree.id:
      return fetchFor(model, req);
    case TreeActivateEvent(:final path):
      model.selectedPath = path;
    case _:
      break; // expand/collapse events need no app effect here
  }
  return null;
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext _) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // Kick off the root load once.
  if (msg is InitMsg && !model.initialized) {
    model.initialized = true;
    return (model, fetchFor(model, model.tree.loadRoots()));
  }

  // A pointer only reaches the tree when it's actually the target — a click
  // on unrelated chrome (the "Selected" box, the help row) has a different
  // target (or none) and must not be treated as a click on the tree.
  if (msg case Routed(:final targetId) when targetId != model.tree.id) {
    return (model, null);
  }

  // Widget update may return an expand event, a load request, or both in
  // its events. A LoadResult takes the same path: it carries the tree's id,
  // and the tree installs roots and children alike in this one call.
  switch (model.tree.update(msg)) {
    case Handled(:final events, :final cmd):
      return (model, Batch([cmd, for (final e in events) onEvent(model, e)]));
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
  final t = resolver.tones;
  frame.buffer.setStyle(frame.area, resolver.ground(resolver.tones.background));

  final treeWidget = Container(
    border: BorderType.plain,
    borderStyle: StyleResolver(theme).border(const {WidgetState.focused}),
    topTitles: [Line('File Browser', style: resolver.ink(t.focus))],
    child: TreeView(
      model: model.tree,
      theme: theme,
    ),
  );

  final infoBox = ConstrainedBox(
    additionalConstraints: const BoxConstraints(minH: 3, maxH: 3),
    child: Container(
      border: BorderType.plain,
      borderStyle: model.selectedPath != null ? resolver.ink(t.success) : resolver.ink(t.border),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      topTitles: [Line('Selected')],
      child: Line(
        model.selectedPath ?? 'Press Enter to select',
        style: model.selectedPath != null ? resolver.ink(t.success) : resolver.ink(t.muted),
      ),
    ),
  );

  final help = Row(
    children: [
      Expanded(
        child: Line(
          '↑↓/jk nav | →/l or click indicator expand | ←/h collapse | Enter/click select | wheel scroll | Esc quit',
          style: resolver.ink(t.muted),
        ),
      ),
      ConstrainedBox(
        additionalConstraints: const BoxConstraints(minW: 25, maxW: 25),
        child: Line('Theme: ${model.themeName} (F1/F2)', style: resolver.ink(t.muted)),
      ),
    ],
  );

  final ui = Container(
    topTitles: [Line('TreeView Demo', style: resolver.ink(t.muted))],
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

Future<void> main() async {
  exit(
    await Application(title: 'TreeView Demo', mouseEvents: true).run(
      init: AppModel(),
      update: appUpdate,
      view: appView,
    ),
  );
}
