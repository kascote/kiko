import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// Simple test widget that fills area with a character.
class FillWidget implements Widget {
  final String char;
  const FillWidget([this.char = 'X']);

  @override
  void render(Rect area, Frame frame) {
    for (var y = area.top; y < area.bottom; y++) {
      for (var x = area.left; x < area.right; x++) {
        frame.buffer[(x: x, y: y)] = Cell(char: char);
      }
    }
  }
}

/// Test model with modal field.
class TestModel {
  final int value;
  final Modal<dynamic>? modal;

  const TestModel({this.value = 0, this.modal});

  TestModel copyWith({int? value, Modal<dynamic>? Function()? modal}) =>
      TestModel(
        value: value ?? this.value,
        modal: modal != null ? modal() : this.modal,
      );
}

void main() {
  group('Modal', () {
    test('simple modal has default config', () {
      final modal = Modal.simple(
        child: const FillWidget(),
        width: const ConstraintLength(10),
        height: const ConstraintLength(5),
      );

      expect(modal.dimBackdrop, isTrue);
      expect(modal.dimFactor, equals(0.3));
    });

    test('custom modal with MVU', () {
      final modal = Modal<int>(
        init: 0,
        update: (m, msg) => (m + 1, null),
        view: (m, area, frame) {},
        width: const ConstraintLength(10),
        height: const ConstraintLength(5),
      );

      expect(modal.model, equals(0));
      expect(modal.dimBackdrop, isTrue);
    });

    test('renders centered with fixed size', () {
      final modal = Modal.simple(
        child: const FillWidget('M'),
        width: const ConstraintLength(4),
        height: const ConstraintLength(2),
        dimBackdrop: false, // disable for test
      );

      // 10x5 screen, 4x2 modal -> centered at x=3, y=1
      final result = capture(
        modal,
        width: 10,
        height: 5,
        showEmptyCells: true,
        stripBlankLines: false,
      );

      expect(
        result,
        equals(
          '··········\n'
          '···MMMM···\n'
          '···MMMM···\n'
          '··········\n'
          '··········',
        ),
      );
    });

    test('renders centered with percentage width', () {
      final modal = Modal.simple(
        child: const FillWidget('P'),
        width: const ConstraintPercent(50), // 50% of 20 = 10
        height: const ConstraintLength(1),
        dimBackdrop: false,
      );

      // 20x3 screen, 10x1 modal -> centered at x=5, y=1
      final result = capture(
        modal,
        width: 20,
        height: 3,
        showEmptyCells: true,
        stripBlankLines: false,
      );

      expect(
        result,
        equals(
          '····················\n'
          '·····PPPPPPPPPP·····\n'
          '····················',
        ),
      );
    });

    test('renders centered with percentage height', () {
      final modal = Modal.simple(
        child: const FillWidget('H'),
        width: const ConstraintLength(2),
        height: const ConstraintPercent(50), // 50% of 10 = 5
        dimBackdrop: false,
      );

      // 6x10 screen, 2x5 modal -> centered at x=2, y=2
      final result = capture(
        modal,
        width: 6,
        height: 10,
        showEmptyCells: true,
        stripBlankLines: false,
      );

      expect(
        result,
        equals(
          '······\n'
          '······\n'
          '··HH··\n'
          '··HH··\n'
          '··HH··\n'
          '··HH··\n'
          '··HH··\n'
          '······\n'
          '······\n'
          '······',
        ),
      );
    });

    test('clamps to available space', () {
      final modal = Modal.simple(
        child: const FillWidget('C'),
        width: const ConstraintLength(100), // larger than screen
        height: const ConstraintLength(100),
        dimBackdrop: false,
      );

      // Should clamp to 5x3
      final result = capture(
        modal,
        width: 5,
        height: 3,
        showEmptyCells: true,
      );

      expect(
        result,
        equals(
          'CCCCC\n'
          'CCCCC\n'
          'CCCCC',
        ),
      );
    });

    test('processMsg updates inner model', () {
      final modal = Modal<int>(
        init: 0,
        update: (m, msg) => (m + 1, null),
        view: (m, area, frame) {},
        width: const ConstraintLength(10),
        height: const ConstraintLength(5),
      );

      final (newModal, cmd) = modal.processMsg(const NoneMsg());

      expect(newModal.model, equals(1));
      expect(cmd, isNull);
    });

    test('processMsg returns command from inner update', () {
      final modal = Modal<int>(
        init: 0,
        update: (m, msg) => (m, Emit(ModalConfirm(42))),
        view: (m, area, frame) {},
        width: const ConstraintLength(10),
        height: const ConstraintLength(5),
      );

      final (_, cmd) = modal.processMsg(const NoneMsg());

      expect(cmd, isA<Emit>());
      expect((cmd! as Emit).msg, isA<ModalConfirm<int>>());
    });
  });

  group('Modal.simple', () {
    test('Enter emits ModalConfirm with payload', () {
      final modal = Modal.simple(
        child: const FillWidget(),
        width: const ConstraintLength(10),
        height: const ConstraintLength(5),
        confirmPayload: 'test-data',
      );

      final (_, cmd) = modal.processMsg(const KeyMsg('enter'));

      expect(cmd, isA<Emit>());
      final emit = cmd! as Emit;
      expect(emit.msg, isA<ModalConfirm<Object?>>());
      expect((emit.msg as ModalConfirm<Object?>).payload, equals('test-data'));
    });

    test('ESC emits ModalCancel', () {
      final modal = Modal.simple(
        child: const FillWidget(),
        width: const ConstraintLength(10),
        height: const ConstraintLength(5),
      );

      final (_, cmd) = modal.processMsg(const KeyMsg('escape'));

      expect(cmd, isA<Emit>());
      final emit = cmd! as Emit;
      expect(emit.msg, isA<ModalCancel>());
    });

    test('other keys are swallowed', () {
      final modal = Modal.simple(
        child: const FillWidget(),
        width: const ConstraintLength(10),
        height: const ConstraintLength(5),
      );

      final (_, cmd) = modal.processMsg(const KeyMsg('a'));

      expect(cmd, isNull);
    });
  });

  group('ModalConfirm / ModalCancel', () {
    test('ModalConfirm is a Msg with payload', () {
      final msg = ModalConfirm(42);
      expect(msg, isA<Msg>());
      expect(msg.payload, equals(42));
    });

    test('ModalConfirm with no payload', () {
      final msg = ModalConfirm<Object?>();
      expect(msg.payload, isNull);
    });

    test('ModalCancel is a Msg', () {
      const msg = ModalCancel();
      expect(msg, isA<Msg>());
    });
  });

  group('withModalCapture', () {
    test('routes to main update when no modal', () {
      var mainCalled = false;

      final update = withModalCapture<TestModel>(
        update: (model, msg) {
          mainCalled = true;
          return (model.copyWith(value: model.value + 1), null);
        },
        getModal: (m) => m.modal,
        setModal: (m, modal) => m.copyWith(modal: () => modal),
      );

      final (newModel, cmd) = update(const TestModel(), const NoneMsg());

      expect(mainCalled, isTrue);
      expect(newModel.value, equals(1));
      expect(cmd, isNull);
    });

    test('routes to modal update when modal present', () {
      var mainCalled = false;

      final modal = Modal<int>(
        init: 0,
        update: (m, msg) => (m + 1, null),
        view: (m, area, frame) {},
        width: const ConstraintLength(10),
        height: const ConstraintLength(5),
      );

      final update = withModalCapture<TestModel>(
        update: (model, msg) {
          mainCalled = true;
          return (model, null);
        },
        getModal: (m) => m.modal,
        setModal: (m, modal) => m.copyWith(modal: () => modal),
      );

      final (newModel, _) = update(
        TestModel(modal: modal),
        const NoneMsg(),
      );

      expect(mainCalled, isFalse);
      // Modal's inner model should have been updated
      expect((newModel.modal! as Modal<int>).model, equals(1));
    });

    test('auto-dismisses on ModalConfirm and forwards to parent', () {
      var parentReceivedConfirm = false;
      Object? receivedPayload;

      final modal = Modal<int>(
        init: 0,
        update: (m, msg) => (m, Emit(ModalConfirm('payload-data'))),
        view: (m, area, frame) {},
        width: const ConstraintLength(10),
        height: const ConstraintLength(5),
      );

      final update = withModalCapture<TestModel>(
        update: (model, msg) {
          if (msg is ModalConfirm) {
            parentReceivedConfirm = true;
            receivedPayload = msg.payload;
          }
          return (model, null);
        },
        getModal: (m) => m.modal,
        setModal: (m, modal) => m.copyWith(modal: () => modal),
      );

      final (newModel, _) = update(
        TestModel(modal: modal),
        const NoneMsg(),
      );

      expect(parentReceivedConfirm, isTrue);
      expect(receivedPayload, equals('payload-data'));
      expect(newModel.modal, isNull); // auto-dismissed
    });

    test('auto-dismisses on ModalCancel and forwards to parent', () {
      var parentReceivedCancel = false;

      final modal = Modal<int>(
        init: 0,
        update: (m, msg) => (m, const Emit(ModalCancel())),
        view: (m, area, frame) {},
        width: const ConstraintLength(10),
        height: const ConstraintLength(5),
      );

      final update = withModalCapture<TestModel>(
        update: (model, msg) {
          if (msg is ModalCancel) {
            parentReceivedCancel = true;
          }
          return (model, null);
        },
        getModal: (m) => m.modal,
        setModal: (m, modal) => m.copyWith(modal: () => modal),
      );

      final (newModel, _) = update(
        TestModel(modal: modal),
        const NoneMsg(),
      );

      expect(parentReceivedCancel, isTrue);
      expect(newModel.modal, isNull); // auto-dismissed
    });

    test('passes through other commands from modal', () {
      final modal = Modal<int>(
        init: 0,
        update: (m, msg) => (m, const Quit()),
        view: (m, area, frame) {},
        width: const ConstraintLength(10),
        height: const ConstraintLength(5),
      );

      final update = withModalCapture<TestModel>(
        update: (model, msg) => (model, null),
        getModal: (m) => m.modal,
        setModal: (m, modal) => m.copyWith(modal: () => modal),
      );

      final (newModel, cmd) = update(
        TestModel(modal: modal),
        const NoneMsg(),
      );

      expect(cmd, isA<Quit>());
      expect(newModel.modal, isNotNull); // not dismissed
    });
  });

  group('dimBackdrop', () {
    test('dims RGB colors', () {
      final area = Rect.create(x: 0, y: 0, width: 2, height: 1);
      final buffer = Buffer.empty(area);

      // Set cells with RGB colors
      buffer[(x: 0, y: 0)] = Cell(
        char: 'A',
        fg: Color.fromRGB(0xFF0000), // red
        bg: Color.fromRGB(0x00FF00), // green
      );
      buffer[(x: 1, y: 0)] = Cell(
        char: 'B',
        fg: Color.fromRGB(0x0000FF), // blue
        bg: Color.fromRGB(0xFFFFFF), // white
      );

      Frame(area, buffer, 0).dimBackdrop(factor: 0.5);

      // Check dimmed values (50%)
      final cell0 = buffer[(x: 0, y: 0)];
      expect(cell0.fg, equals(Color.fromRGB(0x800000))); // dimmed red
      expect(cell0.bg, equals(Color.fromRGB(0x008000))); // dimmed green

      final cell1 = buffer[(x: 1, y: 0)];
      expect(cell1.fg, equals(Color.fromRGB(0x000080))); // dimmed blue
      expect(cell1.bg, equals(Color.fromRGB(0x808080))); // dimmed white -> gray
    });

    test('dims with custom factor', () {
      final area = Rect.create(x: 0, y: 0, width: 1, height: 1);
      final buffer = Buffer.empty(area);

      buffer[(x: 0, y: 0)] = Cell(
        char: 'X',
        fg: Color.fromRGB(0xFF0000),
      );

      Frame(area, buffer, 0).dimBackdrop(factor: 0.25); // 25% brightness

      final cell = buffer[(x: 0, y: 0)];
      expect(cell.fg, equals(Color.fromRGB(0x400000))); // 25% of 255 = 64 = 0x40
    });

    test('converts ANSI to RGB and dims', () {
      final area = Rect.create(x: 0, y: 0, width: 1, height: 1);
      final buffer = Buffer.empty(area);

      buffer[(x: 0, y: 0)] = const Cell(
        char: 'X',
        fg: Color.white, // bright white (15) = 0xFFFFFF
        bg: Color.brightRed, // bright red (9) = 0xFF0000
      );

      Frame(area, buffer, 0).dimBackdrop(factor: 0.5);

      final cell = buffer[(x: 0, y: 0)];
      // ANSI colors converted to RGB then dimmed
      expect(cell.fg, equals(Color.fromRGB(0x808080))); // white -> gray
      expect(cell.bg, equals(Color.fromRGB(0x800000))); // brightRed -> dark red
    });

    test('dims reset fg as gray, reset bg as black', () {
      final area = Rect.create(x: 0, y: 0, width: 1, height: 1);
      final buffer = Buffer.empty(area);

      // fg and bg default to Color.reset
      buffer[(x: 0, y: 0)] = const Cell(char: 'X');

      Frame(area, buffer, 0).dimBackdrop(factor: 0.5);

      final cell = buffer[(x: 0, y: 0)];
      // fg reset (0xc0c0c0) dimmed by 0.5 = 0x606060
      expect(cell.fg, equals(Color.fromRGB(0x606060)));
      // bg reset (0x000000) dimmed stays black
      expect(cell.bg, equals(Color.fromRGB(0x000000)));
    });
  });
}
