import 'dart:math';

import 'package:kiko/kiko.dart';
import 'package:termparser/termparser_events.dart' as evt;

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════
class AppModel {
  final String status;
  final int? result;
  final String? error;
  final bool loading;

  const AppModel({
    this.status = 'Press ENTER to fetch random number',
    this.result,
    this.error,
    this.loading = false,
  });

  AppModel copyWith({String? status, int? result, String? error, bool? loading}) => AppModel(
    status: status ?? this.status,
    result: result ?? this.result,
    error: error,
    loading: loading ?? this.loading,
  );
}

// ═══════════════════════════════════════════════════════════
// MESSAGES
// ═══════════════════════════════════════════════════════════
// ignore: unreachable_from_main
class FetchRequested extends Msg {}

class FetchSuccess extends Msg {
  final int value;
  FetchSuccess(this.value);
}

class FetchError extends Msg {
  final String message;
  FetchError(this.message);
}

// ═══════════════════════════════════════════════════════════
// ASYNC OPERATIONS
// ═══════════════════════════════════════════════════════════
Future<int> fetchRandomNumber() async {
  // Simulate network delay
  await Future<void>.delayed(const Duration(seconds: 2));

  // Randomly succeed or fail
  final random = Random();
  if (random.nextBool()) {
    return random.nextInt(100);
  } else {
    throw Exception('Network error');
  }
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════
(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  return switch (msg) {
    // Quit on 'q'
    KeyMsg(key: evt.KeyEvent(code: evt.KeyCode(char: 'q'))) => (model, const Quit()),

    // Enter triggers fetch
    KeyMsg(key: evt.KeyEvent(code: evt.KeyCode(name: evt.KeyCodeName.enter))) when !model.loading => (
      model.copyWith(status: 'Fetching...', loading: true),
      Task(
        fetchRandomNumber,
        onSuccess: FetchSuccess.new,
        onError: (e) => FetchError(e.toString()),
      ),
    ),

    // Also handle FetchRequested message
    FetchRequested() when !model.loading => (
      model.copyWith(status: 'Fetching...', loading: true),
      Task(
        fetchRandomNumber,
        onSuccess: FetchSuccess.new,
        onError: (e) => FetchError(e.toString()),
      ),
    ),

    // Handle success
    FetchSuccess(:final value) => (
      model.copyWith(
        status: 'Success! Got: $value',
        result: value,
        loading: false,
      ),
      null,
    ),

    // Handle error
    FetchError(:final message) => (
      model.copyWith(
        status: 'Error: $message',
        error: message,
        loading: false,
      ),
      null,
    ),

    _ => (model, null),
  };
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════
void appView(AppModel model, Frame frame) {
  final statusColor = model.error != null
      ? Color.red
      : model.loading
      ? Color.yellow
      : Color.green;

  final resultText = model.result != null ? 'Last result: ${model.result}' : 'No result yet';

  final ui = Block(
    borders: Borders.all,
    child: Column(
      children: [
        Expanded(
          child: Text.raw(
            model.status,
            alignment: Alignment.center,
            style: Style(fg: statusColor),
          ),
        ),
        Fixed(
          1,
          child: Text.raw(resultText, alignment: Alignment.center),
        ),
        Fixed(
          1,
          child: Text.raw(
            model.loading ? '⏳ Loading...' : '(q=quit, enter=fetch)',
            alignment: Alignment.center,
            style: const Style(fg: Color.darkGray),
          ),
        ),
      ],
    ),
  ).titleTop(Line('Async Task Demo'));

  frame.renderWidget(ui, frame.area);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════
void main() async {
  await Application(title: 'Async example').run(
    init: const AppModel(),
    update: appUpdate,
    view: appView,
  );
}
