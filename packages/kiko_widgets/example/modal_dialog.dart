import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel {
  final int count;
  final Modal<void>? modal;
  final String lastAction;

  const AppModel({
    this.count = 0,
    this.modal,
    this.lastAction = '',
  });

  AppModel copyWith({
    int? count,
    Modal<void>? Function()? modal,
    String? lastAction,
  }) => AppModel(
    count: count ?? this.count,
    modal: modal != null ? modal() : this.modal,
    lastAction: lastAction ?? this.lastAction,
  );
}

// ═══════════════════════════════════════════════════════════
// DIALOG CONTENT
// ═══════════════════════════════════════════════════════════

class ConfirmDialog implements Widget {
  final String message;
  const ConfirmDialog(this.message);

  @override
  void render(Rect area, Frame frame) {
    final block = Block(
      borders: Borders.all,
      borderStyle: const Style(fg: Color.cyan),
      child: Column(
        children: [
          Expanded(child: Line(message, alignment: Alignment.center)),
          Fixed(
            1,
            child: Line(
              '[Enter] OK  [Esc] Cancel',
              alignment: Alignment.center,
              style: const Style(fg: Color.gray),
            ),
          ),
        ],
      ),
    ).titleTop(Line(' Confirm ', style: const Style(fg: Color.yellow)));

    frame.renderWidget(block, area);
  }
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  return switch (msg) {
    // Handle modal results
    ModalConfirm() => (
      model.copyWith(count: model.count + 10, lastAction: 'Confirmed! +10'),
      null,
    ),
    ModalCancel() => (model.copyWith(lastAction: 'Cancelled'), null),

    // App controls
    KeyMsg(key: 'q') => (model, const Quit()),
    KeyMsg(key: 'm') => (
      model.copyWith(
        modal: () => Modal.simple(
          width: const ConstraintPercent(50),
          height: const ConstraintLength(7),
          child: const ConfirmDialog('Increment counter by 10?'),
          confirmPayload: true,
        ),
      ),
      null,
    ),
    _ => (model, null),
  };
}

final Update<AppModel> update = withModalCapture<AppModel>(
  update: appUpdate,
  getModal: (m) => m.modal,
  setModal: (m, modal) => m.copyWith(modal: () => modal as Modal<void>?),
);

// ═══════════════════════════════════════════════════════════
// VIEW - Color Demo Panels
// ═══════════════════════════════════════════════════════════

/// Panel 1: RGB Colors
Widget rgbPanel() {
  return Block(
    borders: Borders.all,
    borderStyle: Style(fg: Color.fromRGB(0xFF6600)), // orange
    child: Column(
      children: [
        Fixed(
          1,
          child: Line('RGB Colors', style: Style(fg: Color.fromRGB(0xFFFFFF))),
        ),
        Fixed(
          1,
          child: Line('Red text', style: Style(fg: Color.fromRGB(0xFF0000))),
        ),
        Fixed(
          1,
          child: Line('Green text', style: Style(fg: Color.fromRGB(0x00FF00))),
        ),
        Fixed(
          1,
          child: Line('Blue text', style: Style(fg: Color.fromRGB(0x0000FF))),
        ),
        Fixed(
          1,
          child: Line('Yellow bg', style: Style(bg: Color.fromRGB(0xFFFF00))),
        ),
        Fixed(
          1,
          child: Line('Cyan bg', style: Style(bg: Color.fromRGB(0x00FFFF))),
        ),
        Expanded(
          child: Line('Magenta', style: Style(fg: Color.fromRGB(0xFF00FF))),
        ),
      ],
    ),
  ).titleTop(Line(' Panel 1: RGB '));
}

/// Panel 2: Basic ANSI Colors (0-7)
Widget ansiPanel() {
  return Block(
    borders: Borders.all,
    borderStyle: const Style(fg: Color.green),
    child: Column(
      children: [
        Fixed(
          1,
          child: Line('ANSI 0-7', style: const Style(fg: Color.white)),
        ),
        Fixed(
          1,
          child: Line(
            'Black on gray',
            style: const Style(fg: Color.black, bg: Color.gray),
          ),
        ),
        Fixed(
          1,
          child: Line('Red text', style: const Style(fg: Color.red)),
        ),
        Fixed(
          1,
          child: Line('Green text', style: const Style(fg: Color.green)),
        ),
        Fixed(
          1,
          child: Line('Yellow text', style: const Style(fg: Color.yellow)),
        ),
        Fixed(
          1,
          child: Line('Blue text', style: const Style(fg: Color.blue)),
        ),
        Fixed(
          1,
          child: Line('Magenta text', style: const Style(fg: Color.magenta)),
        ),
        Expanded(
          child: Line('Cyan text', style: const Style(fg: Color.cyan)),
        ),
      ],
    ),
  ).titleTop(Line(' Panel 2: ANSI '));
}

/// Panel 3: Bright ANSI Colors (8-15)
Widget brightAnsiPanel() {
  return Block(
    borders: Borders.all,
    borderStyle: const Style(fg: Color.brightCyan),
    child: Column(
      children: [
        Fixed(
          1,
          child: Line('ANSI 8-15 (bright)', style: const Style(fg: Color.white)),
        ),
        Fixed(
          1,
          child: Line('Dark gray', style: const Style(fg: Color.darkGray)),
        ),
        Fixed(
          1,
          child: Line('Bright red', style: const Style(fg: Color.brightRed)),
        ),
        Fixed(
          1,
          child: Line('Bright green', style: const Style(fg: Color.brightGreen)),
        ),
        Fixed(
          1,
          child: Line('Bright yellow', style: const Style(fg: Color.brightYellow)),
        ),
        Fixed(
          1,
          child: Line('Bright blue', style: const Style(fg: Color.brightBlue)),
        ),
        Fixed(
          1,
          child: Line('Bright magenta', style: const Style(fg: Color.brightMagenta)),
        ),
        Expanded(
          child: Line('White (bright)', style: const Style(fg: Color.white)),
        ),
      ],
    ),
  ).titleTop(Line(' Panel 3: Bright ANSI '));
}

/// Panel 4: Indexed Colors (256 palette)
Widget indexedPanel() {
  return Block(
    borders: Borders.all,
    borderStyle: Style(fg: Color.indexed(208)), // orange
    child: Column(
      children: [
        Fixed(
          1,
          child: Line('Indexed 0-255', style: Style(fg: Color.indexed(255))),
        ),
        Fixed(
          1,
          child: Line('Index 196 (red)', style: Style(fg: Color.indexed(196))),
        ),
        Fixed(
          1,
          child: Line('Index 46 (green)', style: Style(fg: Color.indexed(46))),
        ),
        Fixed(
          1,
          child: Line('Index 21 (blue)', style: Style(fg: Color.indexed(21))),
        ),
        Fixed(
          1,
          child: Line('Index 226 (yellow)', style: Style(fg: Color.indexed(226))),
        ),
        Fixed(
          1,
          child: Line('Index 201 (magenta)', style: Style(fg: Color.indexed(201))),
        ),
        Fixed(
          1,
          child: Line('Grayscale 240', style: Style(fg: Color.indexed(240))),
        ),
        Expanded(
          child: Line('Grayscale 250', style: Style(fg: Color.indexed(250))),
        ),
      ],
    ),
  ).titleTop(Line(' Panel 4: Indexed '));
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════

void appView(AppModel model, Frame frame) {
  // Main layout: 2x2 grid of panels + status bar
  final mainBlock = Block(
    borders: Borders.all,
    child: Column(
      children: [
        // Top row: RGB and ANSI panels
        Expanded(
          child: Row(
            children: [
              Expanded(child: rgbPanel()),
              Expanded(child: ansiPanel()),
            ],
          ),
        ),
        // Bottom row: Bright ANSI and Indexed panels
        Expanded(
          child: Row(
            children: [
              Expanded(child: brightAnsiPanel()),
              Expanded(child: indexedPanel()),
            ],
          ),
        ),
        // Status bar
        Fixed(
          1,
          child: Text.raw(
            'Count: ${model.count} | ${model.lastAction.isEmpty ? "[m] Open dialog  [q] Quit" : "Last: ${model.lastAction}"}',
            alignment: Alignment.center,
            style: const Style(fg: Color.brightYellow, bg: Color.darkGray),
          ),
        ),
      ],
    ),
  ).titleTop(Line(' Modal + Dim Demo - Press [m] to see dim effect '));

  frame.renderWidget(mainBlock, frame.area);

  // Modal handles backdrop dimming internally
  model.modal?.render(frame.area, frame);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

void main() async {
  await Application(title: 'Modal Dialog Example').run(
    init: const AppModel(),
    update: update,
    view: appView,
  );
}
