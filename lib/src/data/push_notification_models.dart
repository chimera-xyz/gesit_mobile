import 'dart:convert';

class PushNotificationEnvelope {
  const PushNotificationEnvelope({required this.data, this.title, this.body});

  final Map<String, String> data;
  final String? title;
  final String? body;

  String? get link => _normalizedString(data['link']);

  String? get notificationType => _normalizedString(data['type']);

  String? get category =>
      _normalizedString(data['notification_category']) ??
      _normalizedString(data['category']);

  String? get notificationId =>
      _normalizedString(data['notification_id']) ??
      _normalizedString(data['id']);

  bool get isCall {
    final resolvedLink = link ?? '';
    return category == 'call' ||
        notificationType == 'chat_call' ||
        resolvedLink.contains('call=');
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'data': data, 'title': title, 'body': body};
  }

  String toPayload() => jsonEncode(toJson());

  static PushNotificationEnvelope? fromPayload(String? payload) {
    final normalizedPayload = payload?.trim();
    if (normalizedPayload == null || normalizedPayload.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(normalizedPayload);
      if (decoded is! Map) {
        return null;
      }

      final rawData = decoded['data'];
      final dataMap = rawData is Map
          ? rawData.map(
              (key, value) => MapEntry('$key', value == null ? '' : '$value'),
            )
          : const <String, String>{};

      return PushNotificationEnvelope(
        data: dataMap,
        title: _normalizedString(decoded['title']),
        body: _normalizedString(decoded['body']),
      );
    } catch (_) {
      return null;
    }
  }
}

String? normalizedPushString(Object? value) => _normalizedString(value);

String? _normalizedString(Object? value) {
  final normalized = '$value'.trim();
  if (normalized.isEmpty || normalized == 'null') {
    return null;
  }

  return normalized;
}
