/// Method names on the `flutter.galva.io/galva` channel. Keep in step with cross_platform.yaml.
class Method {
  static const String configure = 'configure';
  static const String isConfigured = 'is_configured';
  static const String setLogLevel = 'set_log_level';

  static const String identify = 'identify';
  static const String logout = 'logout';
  static const String getIdentifiedUserId = 'get_identified_user_id';
  static const String setAttributes = 'set_attributes';
  static const String track = 'track';

  static const String setOptOut = 'set_opt_out';
  static const String isOptedOut = 'is_opted_out';

  static const String checkForMessages = 'check_for_messages';
  static const String showMessage = 'show_message';
  static const String handleOpenUrl = 'handle_open_url';

  static const String setPushToken = 'set_push_token';
  static const String setApnsToken = 'set_apns_token';
  static const String clearPushToken = 'clear_push_token';
  static const String isGalvaNotification = 'is_galva_notification';
  static const String handlePush = 'handle_push';

  static const String reconcileTransactions = 'reconcile_transactions';
}
