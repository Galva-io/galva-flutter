import 'package:meta/meta.dart' show immutable;

part 'private/galva_user_attributes_json_builder.dart';

/// Attributes to set on the current subscriber with [Galva.setAttributes]. Fields left `null`
/// keep their current value.
@immutable
class GalvaUserAttributes {
  /// The subscriber's email. The SDK checks its form and drops an invalid address.
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? fullName;

  /// Your own attributes. Values can be strings, numbers, booleans, lists and maps of those;
  /// others, and `null`, are dropped. Don't start keys with `$gv_`, which Galva reserves.
  final Map<String, Object?>? custom;

  const GalvaUserAttributes({this.email, this.firstName, this.lastName, this.fullName, this.custom});
}
