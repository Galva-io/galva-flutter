/// The service that issued an Android push token, for [Galva.setPushToken].
enum GalvaPushProvider {
  /// Firebase Cloud Messaging. The default.
  fcm,

  /// Huawei Push Kit, on Huawei devices without Google Play services.
  hms,

  /// Amazon Device Messaging, on Amazon Fire devices.
  adm;

  String get jsonValue => name;
}
