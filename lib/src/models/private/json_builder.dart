/// Typed reads from decoded JSON maps, shared by the JSON builders.
extension MapExtension on Map<String, dynamic> {
  String string(String key) => this[key] as String;

  String? stringIfPresent(String key) => this[key] as String?;

  int integer(String key) => (this[key] as num).toInt();

  DateTime? dateTimeIfPresent(String key) {
    final value = this[key];
    if (value == null) return null;
    return DateTime.tryParse(value as String);
  }
}

extension DateTimeJSONBuilder on DateTime {
  /// ISO 8601 in UTC, without fractional seconds, as the native SDKs write it.
  String toGalvaValidString() => toUtc().copyWith(microsecond: 0, millisecond: 0).toIso8601String();
}
