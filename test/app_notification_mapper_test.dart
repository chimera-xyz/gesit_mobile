import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/data/app_notification_mapper.dart';
import 'package:gesit_app/src/models/app_models.dart';

void main() {
  group('appNotificationFromPushPayload', () {
    test('maps supported notification links to their destinations', () {
      final cases = <_NotificationLinkCase>[
        _NotificationLinkCase(
          label: 'approval submission',
          type: 'approval_needed',
          link: '/submissions/42',
          expectedType: AppNotificationType.approval,
          expectedDestination: NotificationDestination.tasks,
        ),
        _NotificationLinkCase(
          label: 'form submission detail',
          type: 'status_changed',
          link: '/form-submissions/42',
          expectedType: AppNotificationType.system,
          expectedDestination: NotificationDestination.tasks,
        ),
        _NotificationLinkCase(
          label: 'chat message',
          type: 'general',
          link: '/chat/conversations/5',
          expectedType: AppNotificationType.chat,
          expectedDestination: NotificationDestination.chat,
        ),
        _NotificationLinkCase(
          label: 'chat call',
          type: 'general',
          link: '/chat/conversations/5?call=52',
          expectedType: AppNotificationType.call,
          expectedDestination: NotificationDestination.chat,
        ),
        _NotificationLinkCase(
          label: 'feed thread',
          type: 'feed_thread',
          link: '/feed/posts/19',
          expectedType: AppNotificationType.system,
          expectedDestination: NotificationDestination.feed,
        ),
        _NotificationLinkCase(
          label: 'feed mention',
          type: 'feed_mention',
          link: '/feed/posts/19',
          expectedType: AppNotificationType.system,
          expectedDestination: NotificationDestination.feed,
        ),
        _NotificationLinkCase(
          label: 'helpdesk ticket',
          type: 'general',
          link: '/helpdesk/10',
          expectedType: AppNotificationType.helpdesk,
          expectedDestination: NotificationDestination.helpdesk,
        ),
        _NotificationLinkCase(
          label: 'knowledge hub',
          type: 'general',
          link: '/knowledge-hub',
          expectedType: AppNotificationType.knowledge,
          expectedDestination: NotificationDestination.knowledgeHub,
        ),
        _NotificationLinkCase(
          label: 'forms',
          type: 'general',
          link: '/forms',
          expectedType: AppNotificationType.system,
          expectedDestination: NotificationDestination.forms,
        ),
        _NotificationLinkCase(
          label: 'profile',
          type: 'general',
          link: '/profile',
          expectedType: AppNotificationType.system,
          expectedDestination: NotificationDestination.profile,
        ),
      ];

      for (final item in cases) {
        final notification = appNotificationFromPushPayload({
          'notification_id': item.label,
          'title': item.label,
          'message': 'Test message',
          'type': item.type,
          'link': item.link,
        });

        expect(notification.link, item.link, reason: item.label);
        expect(notification.type, item.expectedType, reason: item.label);
        expect(
          notification.destination,
          item.expectedDestination,
          reason: item.label,
        );
        expect(notification.primaryActionLabel, isNotNull, reason: item.label);
      }
    });
  });
}

class _NotificationLinkCase {
  const _NotificationLinkCase({
    required this.label,
    required this.type,
    required this.link,
    required this.expectedType,
    required this.expectedDestination,
  });

  final String label;
  final String type;
  final String link;
  final AppNotificationType expectedType;
  final NotificationDestination expectedDestination;
}
