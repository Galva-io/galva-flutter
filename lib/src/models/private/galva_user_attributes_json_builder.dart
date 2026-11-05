part of '../galva_user_attributes.dart';

extension GalvaUserAttributesJSONBuilder on GalvaUserAttributes {
  Map<String, dynamic> get jsonValue => {
        _Keys.email: ?email,
        _Keys.firstName: ?firstName,
        _Keys.lastName: ?lastName,
        _Keys.fullName: ?fullName,
        if (custom != null && custom!.isNotEmpty) _Keys.custom: custom,
      };
}

class _Keys {
  static const email = 'email';
  static const firstName = 'first_name';
  static const lastName = 'last_name';
  static const fullName = 'full_name';
  static const custom = 'custom';
}
