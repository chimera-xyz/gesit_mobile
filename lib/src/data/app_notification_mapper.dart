import '../models/app_models.dart';

AppNotification appNotificationFromRemotePayload(Map<String, dynamic> payload) {
  final id =
      '${payload['id'] ?? payload['notification_id'] ?? ''}'.trim().isNotEmpty
      ? '${payload['id'] ?? payload['notification_id']}'.trim()
      : 'notification-${DateTime.now().microsecondsSinceEpoch}';
  final title = '${payload['title'] ?? 'Notifikasi'}'.trim();
  final message = '${payload['message'] ?? ''}'.trim();
  final link = _normalizedString(payload['link']);
  final type = _typeFromPayload(
    _normalizedString(payload['type']) ?? 'general',
    link,
  );
  final destination = _destinationFromLink(link);
  final detail =
      _normalizedString(payload['detail']) ??
      _detailFromDestination(destination);

  return AppNotification(
    id: id,
    title: title.isEmpty ? 'Notifikasi' : title,
    message: message.isEmpty ? 'Ada pembaruan baru untuk Anda.' : message,
    detail: detail,
    type: type,
    createdAt:
        DateTime.tryParse('${payload['created_at'] ?? ''}') ?? DateTime.now(),
    isRead: payload['is_read'] == true,
    storesInCenter: payload['stores_in_center'] != false,
    destination: destination,
    link: link,
    primaryActionLabel:
        _normalizedString(payload['primary_action_label']) ??
        _primaryActionLabel(destination),
  );
}

AppNotification appNotificationFromPushPayload(
  Map<String, String> payload, {
  String? fallbackTitle,
  String? fallbackMessage,
}) {
  return appNotificationFromRemotePayload(<String, dynamic>{
    'id': payload['notification_id'] ?? payload['id'],
    'title': payload['title'] ?? fallbackTitle,
    'message': payload['message'] ?? fallbackMessage,
    'type': payload['type'],
    'link': payload['link'],
    'created_at': payload['created_at'],
    'stores_in_center': payload['stores_in_center'] == null
        ? null
        : payload['stores_in_center'] == '1' ||
              payload['stores_in_center'] == 'true',
    'primary_action_label': payload['primary_action_label'],
  });
}

AppNotificationType _typeFromPayload(String rawType, String? link) {
  switch (rawType) {
    case 'form_submitted':
      return AppNotificationType.submission;
    case 'approval_needed':
    case 'signature_required':
      return AppNotificationType.approval;
    case 'status_changed':
      if (link != null && link.contains('/helpdesk')) {
        return AppNotificationType.helpdesk;
      }
      return AppNotificationType.system;
    case 'general':
      if (link != null && link.contains('/helpdesk')) {
        return AppNotificationType.helpdesk;
      }
      if (link != null && link.contains('/knowledge-hub')) {
        return AppNotificationType.knowledge;
      }
      return AppNotificationType.system;
    default:
      return AppNotificationType.system;
  }
}

NotificationDestination _destinationFromLink(String? link) {
  if (link == null || link.isEmpty) {
    return NotificationDestination.none;
  }

  if (link.contains('/helpdesk')) {
    return NotificationDestination.helpdesk;
  }
  if (link.contains('/knowledge-hub')) {
    return NotificationDestination.knowledgeHub;
  }
  if (link.contains('/profile') || link.contains('/user/profile')) {
    return NotificationDestination.profile;
  }
  if (link.contains('/submissions') || link.contains('/form-submissions')) {
    return NotificationDestination.tasks;
  }
  if (link.contains('/forms')) {
    return NotificationDestination.forms;
  }

  return NotificationDestination.none;
}

String _detailFromDestination(NotificationDestination destination) {
  switch (destination) {
    case NotificationDestination.tasks:
      return 'Buka modul Tasks untuk melihat detail pengajuan terkait.';
    case NotificationDestination.forms:
      return 'Buka modul Forms untuk melihat perubahan terbaru.';
    case NotificationDestination.helpdesk:
      return 'Buka modul Helpdesk untuk melihat tiket terkait.';
    case NotificationDestination.chat:
      return 'Buka modul Chat untuk melihat percakapan terbaru.';
    case NotificationDestination.knowledgeHub:
      return 'Buka Knowledge Hub untuk melihat dokumen terkait.';
    case NotificationDestination.profile:
      return 'Buka profil untuk melihat pembaruan terkait akun Anda.';
    case NotificationDestination.none:
      return 'Notifikasi ini belum memiliki tautan konten khusus.';
  }
}

String? _primaryActionLabel(NotificationDestination destination) {
  switch (destination) {
    case NotificationDestination.tasks:
      return 'Buka task';
    case NotificationDestination.forms:
      return 'Buka form';
    case NotificationDestination.helpdesk:
      return 'Buka tiket';
    case NotificationDestination.chat:
      return 'Buka chat';
    case NotificationDestination.knowledgeHub:
      return 'Buka hub';
    case NotificationDestination.profile:
      return 'Buka profil';
    case NotificationDestination.none:
      return null;
  }
}

String? _normalizedString(Object? value) {
  final normalized = '$value'.trim();
  if (normalized.isEmpty || normalized == 'null') {
    return null;
  }

  return normalized;
}
