import 'cmd.dart';

/// Something a widget produced for the app to interpret, addressed by [id].
///
/// A widget returns one from its `update`, carried in a `Handled` result's
/// `events` list, instead of performing the effect itself — a button press,
/// a row activation, a load request. The app reads it in its own `update`
/// and decides what it means; the widget itself has no opinion. Compare
/// [Cmd], which the runtime performs directly rather than the app.
abstract class WidgetEvent {
  /// Const constructor for subclasses.
  const WidgetEvent();

  /// The stable id of the widget that produced this event.
  String get id;

  /// Returns this event addressed under [scope], for a part inside a composite.
  ///
  /// An event whose reply comes back addressed to the widget overrides this
  /// to carry [scope] as a path prefix on its id. Every other event keeps
  /// this default, which returns the event unchanged.
  // ignore: avoid_returning_this
  WidgetEvent scopeUnder(String scope) => this;
}
