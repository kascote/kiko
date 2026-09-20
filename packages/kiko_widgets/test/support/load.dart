import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// A request for ([id], [key]) that no model issued, ticketed by a throwaway
/// tracker.
///
/// For tests of the id and key guards, where a result must name a widget or
/// a load nothing is waiting for. A result a model should accept is built
/// from the request that model returned, never from this.
LoadRequest requestFor(String id, {Object? key}) =>
    LoadRequest(id, key: key, ticket: LoadTracker<Object?>().begin(key));

/// [request] re-addressed to [id], keeping its key and ticket: the scoped
/// path form a composite forwards to its part.
LoadRequest addressedTo(LoadRequest request, String id) => LoadRequest(id, key: request.key, ticket: request.ticket);

/// Matches a [LoadRequest] for ([id], [key]), whatever its ticket.
Matcher isRequestFor(String id, Object? key) =>
    isA<LoadRequest>().having((r) => r.id, 'id', id).having((r) => r.key, 'key', key);

/// The load requests [verdict] carries, in order; none for a decline.
List<LoadRequest> requestsOf(UpdateResult verdict) =>
    verdict is Handled ? verdict.events.whereType<LoadRequest>().toList() : const [];

/// The one load request among [events].
LoadRequest requestIn(List<WidgetEvent> events) => events.whereType<LoadRequest>().single;

/// Remembers the live request for every key a model asked for, so a test
/// answers by key the way the app answers by request.
///
/// Pass what the model returned to [note]: a request, a list of events, or
/// an update verdict. A later request for the same key replaces the earlier
/// one, as it does in the model.
class RequestLog {
  final _live = <Object?, LoadRequest>{};

  /// Records the requests [value] carries and returns [value].
  T note<T>(T value) {
    final requests = switch (value) {
      final LoadRequest request => [request],
      final List<Object?> list => list.whereType<LoadRequest>(),
      final UpdateResult verdict => requestsOf(verdict),
      _ => const <LoadRequest>[],
    };
    for (final request in requests) {
      _live[request.key] = request;
    }
    return value;
  }

  /// The live request for [key].
  LoadRequest operator [](Object? key) => _live[key] ?? (throw StateError('no request was noted for $key'));
}
