import 'dart:math';

import 'package:kiko/kiko.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════
//
// NOTE: Kiko models are mutable by default (Bubble Tea style). Immutable + `copyWith`
// is fine for a standalone value model like this — and it stops there. The moment your
// model holds widget models (TextInput, Table, …), those are mutable and you address
// their events by stable reference, so the app model goes mutable too. Don't read this
// as "immutable scales to a real UI" — it doesn't.
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
    KeyMsg(key: 'q') => (model, const Quit()),

    // Enter triggers fetch
    KeyMsg(key: 'enter') when !model.loading => (
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

  final ui = Box(
    border: BorderType.plain,
    topTitles: [Line('Async Task Demo')],
    child: Column(
      children: [
        Expanded(
          child: Center(
            child: Line(
              model.status,
              style: Style(fg: statusColor),
            ),
          ),
        ),
        Center(child: Line(resultText)),
        Center(
          child: Line(
            model.loading ? '⏳ Loading...' : '(q=quit, enter=fetch)',
            style: const Style(fg: Color.darkGray),
          ),
        ),
      ],
    ),
  );

  frame.render(ui);
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
