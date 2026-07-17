import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// A message no widget has ever heard of.
///
/// The FocusRouter forwards every non-pointer, non-traversal message to the
/// focused widget and trusts its verdict, so the whole routing contract rests
/// on one discipline: a widget consumes only what it understands and declines
/// everything else. A catch-all `Handled` tail turns a widget into a black
/// hole for messages that were never its business.
class _UnknownMsg extends Msg {
  const _UnknownMsg();
}

void main() {
  final rows = <Map<String, Object?>>[
    <String, Object?>{'id': '1', 'name': 'Al'},
  ];

  // Each model is built focused — the state in which a catch-all tail would
  // consume the message. (Unfocused models sit behind the focus gate, which
  // already declines.)
  final probes = <String, UpdateResult Function()>{
    'TextInputModel': () => TextInputModel(focused: true).update(const _UnknownMsg()),
    'TextAreaModel': () => TextAreaModel(id: 'ta', focused: true).update(const _UnknownMsg()),
    'ButtonModel': () => ButtonModel(id: 'b', label: Line('OK'), focused: true).update(const _UnknownMsg()),
    'ButtonGroupModel': () => ButtonGroupModel(
      buttons: [ButtonModel(id: 'b', label: Line('OK'))],
      focused: true,
    ).update(const _UnknownMsg()),
    'ModalModel': () => ModalModel().update(const _UnknownMsg()),
    'ScrollViewModel': () => ScrollViewModel(focused: true).update(const _UnknownMsg()),
    'ListViewModel': () =>
        ListViewModel<String, String>(dataView: DataBuffer(['a']), focused: true).update(const _UnknownMsg()),
    'TableViewModel': () => TableViewModel(
      dataSource: TableDataSource.fromList(rows),
      keyField: 'id',
      columns: [TableColumn(field: 'id', label: Line('ID'), width: 2)],
      focused: true,
    ).update(const _UnknownMsg()),
    'TreeViewModel': () => TreeViewModel<String>(focused: true).update(const _UnknownMsg()),
    'FocusSlot': () => FocusSlot().update(const _UnknownMsg()),
  };

  group('unknown-message decline discipline', () {
    for (final probe in probes.entries) {
      test('${probe.key} declines a message it does not know', () {
        expect(probe.value(), isA<Declined>());
      });
    }
  });
}
