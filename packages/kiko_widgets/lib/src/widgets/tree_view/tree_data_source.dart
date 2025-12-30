import 'tree_node.dart';

/// Data provider for TreeView.
///
/// Implement this to provide tree data, supporting lazy loading.
///
/// ```dart
/// class FileSystemSource extends TreeDataSource<FileInfo> {
///   @override
///   Future<List<TreeNode<FileInfo>>> getRoots() async {
///     return [TreeNode(path: '/home', label: Line('Home'), ...)];
///   }
///
///   @override
///   Future<List<TreeNode<FileInfo>>> getChildren(String path) async {
///     final files = await listDirectory(path);
///     return files.map((f) => TreeNode(...)).toList();
///   }
/// }
/// ```
abstract class TreeDataSource<T> {
  /// Get root-level nodes.
  Future<List<TreeNode<T>>> getRoots();

  /// Get children for a parent path.
  ///
  /// Called when a node is expanded. Return empty list if no children.
  Future<List<TreeNode<T>>> getChildren(String path);

  /// Whether more children can be loaded for this path (pagination).
  ///
  /// Return false for most cases. Return true if implementing
  /// progressive loading of large directories.
  bool hasMore(String path) => false;
}

/// Simple tree data source backed by a static list of nodes.
///
/// Children are derived from path hierarchy.
///
/// ```dart
/// final source = StaticTreeDataSource([
///   TreeNode(path: '/root', label: Line('Root')),
///   TreeNode(path: '/root/child1', label: Line('Child 1')),
///   TreeNode(path: '/root/child2', label: Line('Child 2')),
///   TreeNode(path: '/root/child1/grandchild', label: Line('Grandchild')),
/// ]);
/// ```
class StaticTreeDataSource<T> extends TreeDataSource<T> {
  final List<TreeNode<T>> _nodes;

  /// Creates a static data source from a flat list of nodes.
  StaticTreeDataSource(this._nodes);

  @override
  Future<List<TreeNode<T>>> getRoots() async {
    // Root nodes have no parent (single segment after leading slash)
    return _nodes.where((n) {
      final segments = n.path.split('/').where((s) => s.isNotEmpty).toList();
      return segments.length == 1;
    }).toList();
  }

  @override
  Future<List<TreeNode<T>>> getChildren(String path) async {
    // Children are nodes whose parent path matches
    final parentPrefix = path.endsWith('/') ? path : '$path/';
    return _nodes.where((n) {
      if (!n.path.startsWith(parentPrefix)) return false;
      // Direct children only (one more segment)
      final remainder = n.path.substring(parentPrefix.length);
      return remainder.isNotEmpty && !remainder.contains('/');
    }).toList();
  }
}
