/// How much the SDK logs, from least to most.
///
/// On iOS, `verbose` logs as much as `debug`, and `warn` maps to the iOS SDK's `warning`.
enum GalvaLogLevel {
  none,
  error,
  warn,
  info,
  debug,
  verbose;

  String get jsonValue => name;
}
