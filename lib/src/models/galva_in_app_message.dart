import 'package:meta/meta.dart' show immutable;

import 'private/json_builder.dart';

part 'private/galva_in_app_message_json_builder.dart';

/// The type of Galva flow that sent an in-app message. Messages can carry types newer than
/// these, so compare with `==` rather than switching exhaustively.
@immutable
class GalvaWorkflowType {
  /// The server's identifier, such as `trial-rescue`.
  final String rawValue;

  const GalvaWorkflowType(this.rawValue);

  static const trialRescue = GalvaWorkflowType('trial-rescue');
  static const cancellationRecovery = GalvaWorkflowType('cancellation-recovery');
  static const winback = GalvaWorkflowType('winback');
  static const paymentRecovery = GalvaWorkflowType('payment-recovery');

  @override
  bool operator ==(Object other) => other is GalvaWorkflowType && other.rawValue == rawValue;

  @override
  int get hashCode => rawValue.hashCode;

  @override
  String toString() => rawValue;
}

/// A Galva in-app message, from [Galva.inAppMessageStream]. Pass it to [Galva.showMessage].
@immutable
class GalvaInAppMessage {
  /// The message's ID. Stable, so you can use it to drop duplicates.
  final String id;

  /// The flow that sent it, or `null` when it isn't part of a recovery flow.
  final GalvaWorkflowType? workflowType;

  /// When Galva queued the message, when the platform reports it.
  final DateTime? createdAt;

  const GalvaInAppMessage({required this.id, this.workflowType, this.createdAt});

  @override
  bool operator ==(Object other) => other is GalvaInAppMessage && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'GalvaInAppMessage(id: $id, workflowType: $workflowType, createdAt: $createdAt)';
}
