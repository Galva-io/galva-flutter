part of '../galva_in_app_message.dart';

extension GalvaInAppMessageJSONBuilder on GalvaInAppMessage {
  Map<String, dynamic> get jsonValue => {
        _Keys.id: id,
        _Keys.workflowType: ?workflowType?.rawValue,
        _Keys.createdAt: ?createdAt?.toGalvaValidString(),
      };

  static GalvaInAppMessage fromJsonValue(Map<String, dynamic> json) {
    final workflowType = json.stringIfPresent(_Keys.workflowType);
    return GalvaInAppMessage(
      id: json.string(_Keys.id),
      workflowType: workflowType == null ? null : GalvaWorkflowType(workflowType),
      createdAt: json.dateTimeIfPresent(_Keys.createdAt),
    );
  }
}

class _Keys {
  static const id = 'id';
  static const workflowType = 'workflow_type';
  static const createdAt = 'created_at';
}
