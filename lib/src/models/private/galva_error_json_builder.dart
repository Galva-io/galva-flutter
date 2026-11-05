part of '../galva_error.dart';

extension GalvaErrorJSONBuilder on GalvaError {
  static GalvaError fromJsonValue(Map<String, dynamic> json) {
    return GalvaError(
      json.string(_Keys.message),
      json.integer(_Keys.code),
      json.stringIfPresent(_Keys.detail),
    );
  }
}

class _Keys {
  static const message = 'message';
  static const code = 'code';
  static const detail = 'detail';
}
