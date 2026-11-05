import 'package:meta/meta.dart' show immutable;

/// The Galva backend the SDK talks to. An App ID works only in the environment that issued it.
@immutable
sealed class GalvaEnvironment {
  const GalvaEnvironment();

  /// Galva's production environment. The default.
  static const GalvaEnvironment production = _NamedEnvironment('production');

  /// Galva's development environment. Works only with an App ID issued for it.
  static const GalvaEnvironment development = _NamedEnvironment('development');

  /// Your own API and in-app message page URLs, for proxy setups. [webviewUrl] must end with `/`.
  const factory GalvaEnvironment.custom({required String apiUrl, required String webviewUrl}) = _CustomEnvironment;

  Map<String, dynamic> get jsonValue;
}

final class _NamedEnvironment extends GalvaEnvironment {
  final String type;

  const _NamedEnvironment(this.type);

  @override
  Map<String, dynamic> get jsonValue => {'type': type};

  @override
  String toString() => type;
}

final class _CustomEnvironment extends GalvaEnvironment {
  final String apiUrl;
  final String webviewUrl;

  const _CustomEnvironment({required this.apiUrl, required this.webviewUrl});

  @override
  Map<String, dynamic> get jsonValue => {'type': 'custom', 'api_url': apiUrl, 'webview_url': webviewUrl};

  @override
  String toString() => 'custom($apiUrl, $webviewUrl)';
}
