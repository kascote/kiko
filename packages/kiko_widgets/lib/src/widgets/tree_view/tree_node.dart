import 'package:kiko/kiko.dart';

import '../../load/load.dart';

/// A node in a tree structure.
///
/// Each node has a unique [path] (e.g., '/root/child/grandchild'),
/// a styled [label] for display, optional [icon], and optional typed [data].
///
/// ```dart
/// TreeNode<FileInfo>(
///   path: '/documents/report.txt',
///   label: Line('report.txt'),
///   icon: '📄',
///   isLeaf: true,
///   data: FileInfo(size: 1024),
/// )
/// ```
class TreeNode<T> {
  /// Unique path identifier (e.g., '/root/child').
  final String path;

  /// Styled text label for display.
  final Line label;

  /// Optional icon (emoji/char) shown before label.
  final String? icon;

  /// Whether this node is a leaf (cannot have children).
  final bool isLeaf;

  /// Optional typed user data payload.
  final T? data;

  /// The status this node stands in for, or `null` for a real node.
  ///
  /// A non-null value marks a synthetic row the tree model inserts beneath
  /// an expanded branch while its children are missing: [SliceStatus.filling]
  /// in flight, [SliceStatus.failed] after an error, [SliceStatus.stalled]
  /// after a refusal. The view paints this row itself, from its own label
  /// parameters, and never calls a custom `nodeBuilder` for it.
  final SliceStatus? placeholder;

  /// Creates a TreeNode.
  const TreeNode({
    required this.path,
    required this.label,
    this.icon,
    this.isLeaf = false,
    this.data,
    this.placeholder,
  });

  /// Depth of this node (number of path segments - 1).
  ///
  /// Root nodes have depth 0.
  int get depth {
    if (path.isEmpty || path == '/') return 0;
    // Count segments: '/a/b/c' -> ['', 'a', 'b', 'c'] -> 3 segments after root
    return path.split('/').where((s) => s.isNotEmpty).length - 1;
  }

  /// Parent path, or null if this is a root node.
  String? get parentPath {
    if (path.isEmpty || path == '/') return null;
    final lastSlash = path.lastIndexOf('/');
    if (lastSlash <= 0) return null;
    return path.substring(0, lastSlash);
  }

  @override
  String toString() => 'TreeNode($path)';
}
