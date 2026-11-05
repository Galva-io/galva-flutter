part of '../galva_configuration.dart';

extension GalvaConfigurationJSONBuilder on GalvaConfiguration {
  Map<String, dynamic> get jsonValue => {
        _Keys.apiKey: apiKey,
        _Keys.environment: environment.jsonValue,
        _Keys.logLevel: logLevel.jsonValue,
        _Keys.inAppMessages: inAppMessages.name,
        _Keys.autoTrackSessions: autoTrackSessions,
        _Keys.iosAppleSearchAds: iosAppleSearchAds,
        _Keys.wrapper: {'name': 'flutter', 'version': galvaFlutterVersion},
      };
}

class _Keys {
  static const apiKey = 'api_key';
  static const environment = 'environment';
  static const logLevel = 'log_level';
  static const inAppMessages = 'in_app_messages';
  static const autoTrackSessions = 'auto_track_sessions';
  static const iosAppleSearchAds = 'ios_apple_search_ads';
  static const wrapper = 'wrapper';
}
