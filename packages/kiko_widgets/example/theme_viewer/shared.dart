import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

// Data and small paint helpers shared by every theme viewer page: the
// gallery's seed data, the table's row source, and the swatch, label, and
// title-ink helpers the tone tables and the gallery both reach for.

/// The combobox's option list: five roles a user account might hold.
const roles = ['Admin', 'Editor', 'Viewer', 'Guest', 'Owner'];

/// The chores the gallery's list view shows.
const chores = [
  'Water the plants',
  'Answer support mail',
  'Rotate the logs',
  'Review the queue',
  'Update dependencies',
  'Back up the database',
  'Close stale tickets',
  'Refresh the certs',
  'Sweep the cache',
  'Tag the release',
  'Write the changelog',
  'Plan the sprint',
];

/// Rows the list paints as disabled, so the disabled tone shows inside data.
const disabledChores = {2, 7};

/// The text the gallery's editor starts with.
const editorSeed =
    'Every styled cell is a tone.\n'
    'Ink tints the glyphs.\n'
    'Fill paints on over color.\n'
    'Wash tints the ground.';

/// The length of [editorSeed]'s last line — the span the editor pre-selects.
const seedSelection = 22;

/// The file tree the gallery's tree view browses.
List<TreeNode<void>> fileTree() => [
  TreeNode(path: '/documents', label: Line('Documents')),
  TreeNode(path: '/documents/report.pdf', label: Line('report.pdf'), isLeaf: true),
  TreeNode(path: '/documents/notes.txt', label: Line('notes.txt'), isLeaf: true),
  TreeNode(path: '/downloads', label: Line('Downloads')),
  TreeNode(path: '/downloads/image.png', label: Line('image.png'), isLeaf: true),
  TreeNode(path: '/downloads/archive.zip', label: Line('archive.zip'), isLeaf: true),
  TreeNode(path: '/music', label: Line('Music')),
  TreeNode(path: '/music/one.mp3', label: Line('one.mp3'), isLeaf: true),
  TreeNode(path: '/music/two.mp3', label: Line('two.mp3'), isLeaf: true),
];

/// Total row count behind the gallery's table.
const tableTotal = 120;

/// Builds one page of the table's rows, synchronously.
///
/// [readRows] wraps this behind a delay for every page after the first; the
/// table's own constructor calls it directly, so its first page — and the
/// row under the cursor — exist before the table's first frame paints.
List<Map<String, Object?>> tableRows(int offset, int limit) {
  if (offset >= tableTotal) return [];
  final count = (offset + limit > tableTotal) ? tableTotal - offset : limit;
  return List.generate(count, (i) {
    final n = offset + i + 1;
    return <String, Object?>{
      'id': 'R${n.toString().padLeft(3, '0')}',
      'name': 'Sample row $n',
      'price': 9.99 + (n % 40) * 2.5,
    };
  });
}

/// A slow offset read, so scrolling the table past its first page shows its
/// loading rows.
Future<List<Map<String, Object?>>> readRows(int offset, int limit) async {
  await Future<void>.delayed(const Duration(milliseconds: 400));
  return tableRows(offset, limit);
}

/// Pins [child] to an exact [width], one visual row tall.
View col(int width, View child) => ConstrainedBox(
  additionalConstraints: BoxConstraints(minW: width, maxW: width),
  child: child,
);

/// A projection swatch: `Ab` painted in [style], padded to [width] cells.
View swatch(int width, Style style) => ConstrainedBox(
  additionalConstraints: BoxConstraints(minW: width, maxW: width),
  child: Container(
    ground: style,
    child: Line(' Ab ', style: style),
  ),
);

/// Short names for the sixteen ANSI slots; a `+` marks a bright variant.
const ansiNames = [
  'black',
  'red',
  'green',
  'yellow',
  'blue',
  'magenta',
  'cyan',
  'gray',
  'darkGray',
  'red+',
  'green+',
  'yellow+',
  'blue+',
  'magenta+',
  'cyan+',
  'white',
];

/// A tone half as text: an ANSI-16 name, hex for RGB, an em dash when unset.
String colorLabel(Color? color) {
  if (color == null) return '—';
  if (color == Color.reset) return 'reset';
  if (color.kind == ColorKind.ansi) return ansiNames[color.value];

  final rgb = color.toRgb();
  return '#${rgb.value.toRadixString(16).padLeft(6, '0')}';
}

/// Title ink for a section: resting muted ink, with the matrix's state
/// contributions (error, focus, disabled) patched over it.
Style titleInk(StyleResolver resolver, Set<WidgetState> states) =>
    resolver.resolve(resolver.ink(resolver.tones.muted), states, cls: PaintClass.ink);
