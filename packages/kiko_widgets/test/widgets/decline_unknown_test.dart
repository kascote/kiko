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
  // already declines.) Each probe builds a fresh instance per call, so one
  // message case never leaks state into the next.
  final probes = <String, UpdateResult Function(Msg msg)>{
    'TextInputModel': (msg) => TextInputModel(focused: true).update(msg),
    'TextAreaModel': (msg) => TextAreaModel(id: 'ta', focused: true).update(msg),
    'ButtonModel': (msg) => ButtonModel(id: 'b', label: Line('OK'), focused: true).update(msg),
    'ButtonGroupModel': (msg) => ButtonGroupModel(
      buttons: [ButtonModel(id: 'b', label: Line('OK'))],
      focused: true,
    ).update(msg),
    'ModalModel': (msg) => ModalModel().update(msg),
    'ScrollViewModel': (msg) => ScrollViewModel(focused: true).update(msg),
    'ListViewModel': (msg) => ListViewModel<String, String>(dataView: DataBuffer(['a']), focused: true).update(msg),
    'TableViewModel': (msg) => TableViewModel(
      dataSource: TableDataSource.fromList(rows),
      keyField: 'id',
      columns: [TableColumn(field: 'id', label: Line('ID'), width: 2)],
      focused: true,
    ).update(msg),
    'TreeViewModel': (msg) => TreeViewModel<String>(focused: true).update(msg),
    'FocusSlot': (msg) => FocusSlot().update(msg),
  };

  // Every message class no widget owns: an unknown message type, plus the
  // two key-adjacent siblings a plain terminal never sends but a
  // kitty-enhanced one does. Neither KeyReleaseMsg nor ModifierKeyMsg is a
  // KeyMsg (see the Msg docs), so nothing that pattern-matches `KeyMsg` or
  // resolves through a `KeyBinding` can mistake them for a keystroke — every
  // model must decline them exactly like any other message it doesn't
  // understand. This is the regression pin for the doubled-character bug: a
  // model that (incorrectly) treated a release as a fresh keystroke would
  // insert or act on it a second time.
  final unknownMessages = <String, Msg>{
    'an unknown message class': const _UnknownMsg(),
    'a key release': const KeyReleaseMsg('a'),
    'a bare modifier key going down': const ModifierKeyMsg(ModifierKey.shift, ModifierSide.left, down: true),
  };

  group('unknown-message decline discipline', () {
    for (final probe in probes.entries) {
      for (final message in unknownMessages.entries) {
        test('${probe.key} declines ${message.key}', () {
          expect(probe.value(message.value), isA<Declined>());
        });
      }
    }
  });
}
