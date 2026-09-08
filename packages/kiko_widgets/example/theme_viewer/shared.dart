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

// ── the state strip ──

/// One column of the state strip: a chip label and the states it resolves.
///
/// The third field forces a paint class for that one column, regardless of
/// the row it sits in; every other column resolves in the row's own class.
typedef _StripColumn = (String label, Set<WidgetState> states, PaintClass? forceCls);

/// The state strip's columns, in the doc matrix's own order. `cur wash`
/// always resolves in [PaintClass.wash] — see [_stripChip].
const _stripColumns = <_StripColumn>[
  ('rest', {}, null),
  ('sel', {WidgetState.selected}, null),
  ('cur', {WidgetState.cursor}, null),
  ('sel+cur', {WidgetState.selected, WidgetState.cursor}, null),
  ('cur wash', {WidgetState.cursor}, PaintClass.wash),
  ('hover', {WidgetState.hover}, null),
  ('dis', {WidgetState.disabled}, null),
  ('sel+dis', {WidgetState.selected, WidgetState.disabled}, null),
  ('cur+dis', {WidgetState.cursor, WidgetState.disabled}, null),
  ('focus', {WidgetState.focused}, null),
  ('error', {WidgetState.error}, null),
  ('load', {WidgetState.loading}, null),
];

/// Whether every state in [states] affects [cls] in the resolver's matrix.
///
/// The doc matrix (docs/theming.md, "The state × class matrix") marks some
/// state × class pairs with an em dash: `cursor` does not affect `ink`, and
/// `focused`, `loading`, and `disabled` do not affect `wash`. A chip whose
/// states include one of those pairs would just echo its base back
/// unchanged, so the strip leaves it blank instead.
bool _applies(Set<WidgetState> states, PaintClass cls) {
  const noInk = {WidgetState.cursor};
  const noWash = {WidgetState.focused, WidgetState.loading, WidgetState.disabled};
  return switch (cls) {
    PaintClass.ink => !states.any(noInk.contains),
    PaintClass.wash => !states.any(noWash.contains),
    PaintClass.fill => true,
  };
}

/// One chip of the state strip: a label painted by a single `resolve` call
/// over [base], or a blank cell of the same width when [column]'s states do
/// not apply to [rowCls] (see [_applies]).
///
/// Tags a non-blank chip with its label, spaces replaced by `-`. The
/// enclosing ground and row scopes ([_stripGroup], [_stripRow]) turn that
/// into the full hit path `strip/<ground>/<class>/<label>` a test reads.
View _stripChip(StyleResolver resolver, PaintClass rowCls, Style? base, _StripColumn column) {
  final (label, states, forceCls) = column;
  final width = label.length + 2;
  if (forceCls == null && !_applies(states, rowCls)) return col(width, Line(''));

  final style = resolver.resolve(base, states, cls: forceCls ?? rowCls);
  return Tagged(label.replaceAll(' ', '-'), col(width, Line(' $label ', style: style)));
}

/// One row of the state strip: every column resolved in [cls] over [base],
/// with [groupLabel] and the class name as its two leading columns.
///
/// Scopes every chip's tag under [cls]'s name, so a chip's hit path reads
/// `<ground scope>/<class>/<label>`.
View _stripRow(StyleResolver resolver, String groupLabel, PaintClass cls, Style? base) {
  final label = resolver.ink(resolver.tones.muted);
  final chips = [for (final column in _stripColumns) _stripChip(resolver, cls, base, column)];
  return Tagged.scope(
    cls.name,
    Row(
      children: [
        col(13, Line(groupLabel, style: label)),
        const SizedBox(width: 1),
        col(4, Line(cls.name, style: label)),
        const SizedBox(width: 1),
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 1),
          chips[i],
        ],
      ],
    ),
  );
}

/// One ground group of the state strip: the fill, wash, and ink rows,
/// painted over [ground] — [groupLabel] names the group on the first row.
///
/// The fill and wash rows resolve over a bare base, the way a widget row
/// does; the ink row resolves over [borderInk], the resting border tone.
/// Scopes the group under [groundTag] (`bg` or `sf`).
View _stripGroup(StyleResolver resolver, String groundTag, String groupLabel, Style ground, Style borderInk) =>
    Tagged.scope(
      groundTag,
      Container(
        ground: ground,
        child: Column(
          children: [
            _stripRow(resolver, groupLabel, PaintClass.fill, null),
            _stripRow(resolver, '', PaintClass.wash, null),
            _stripRow(resolver, '', PaintClass.ink, borderInk),
          ],
        ),
      ),
    );

/// The state strip: the resolver's state × class matrix made visible, one
/// chip per state combination.
///
/// Page 1 places it as the last section of the reference page; page 2 places
/// it as a band above the live gallery. Every chip is exactly one `resolve`
/// call painted over its row's ground — the strip adds no color of its own.
View stateStrip(StyleResolver resolver) {
  final t = resolver.tones;
  final borderInk = resolver.ink(t.border);
  return Tagged.scope(
    'strip',
    Container(
      border: BorderType.plain,
      borderStyle: resolver.border(const {}),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      topTitles: [Line(' States — one resolve() per chip, over both grounds ', style: resolver.ink(t.secondary))],
      child: Column(
        children: [
          _stripGroup(resolver, 'bg', 'on background', resolver.ground(t.background), borderInk),
          _stripGroup(resolver, 'sf', 'on surface', resolver.ground(t.surface), borderInk),
          Line(
            'sel selected · cur cursor · dis disabled · load loading · cur wash: cursor in the wash class',
            style: resolver.ink(t.muted),
          ),
        ],
      ),
    ),
  );
}
