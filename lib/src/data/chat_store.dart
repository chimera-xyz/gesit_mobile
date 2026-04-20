import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

class ChatWorkspaceSnapshot {
  const ChatWorkspaceSnapshot({
    required this.conversations,
    required this.messagesByConversation,
    required this.membersByConversation,
    required this.assetsByConversation,
    this.directoryMembers = const [],
    this.activeCall,
    this.events = const [],
    this.lastEventId = 0,
  });

  final List<ConversationPreview> conversations;
  final Map<String, List<ChatMessage>> messagesByConversation;
  final Map<String, List<GroupMember>> membersByConversation;
  final Map<String, List<ConversationAsset>> assetsByConversation;
  final List<GroupMember> directoryMembers;
  final ChatCallSession? activeCall;
  final List<ChatWorkspaceEvent> events;
  final int lastEventId;

  factory ChatWorkspaceSnapshot.fromJson(Map<String, dynamic> json) {
    return ChatWorkspaceSnapshot(
      conversations: ((json['conversations'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                ConversationPreview.fromJson(item.cast<String, dynamic>()),
          )
          .toList(),
      messagesByConversation: _decodeNestedCollection(
        json['messages_by_conversation'],
        ChatMessage.fromJson,
      ),
      membersByConversation: _decodeNestedCollection(
        json['members_by_conversation'],
        GroupMember.fromJson,
      ),
      assetsByConversation: _decodeNestedCollection(
        json['assets_by_conversation'],
        ConversationAsset.fromJson,
      ),
      directoryMembers: ((json['directory_members'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => GroupMember.fromJson(item.cast<String, dynamic>()))
          .toList(),
      activeCall: json['active_call'] is Map<String, dynamic>
          ? ChatCallSession.fromJson(
              (json['active_call'] as Map<String, dynamic>),
            )
          : json['active_call'] is Map
          ? ChatCallSession.fromJson(
              (json['active_call'] as Map).cast<String, dynamic>(),
            )
          : null,
      events: ((json['events'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => ChatWorkspaceEvent.fromJson(item.cast<String, dynamic>()),
          )
          .toList(),
      lastEventId: (json['last_event_id'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversations': conversations.map((item) => item.toJson()).toList(),
      'messages_by_conversation': _encodeNestedCollection(
        messagesByConversation,
      ),
      'members_by_conversation': _encodeNestedCollection(membersByConversation),
      'assets_by_conversation': _encodeNestedCollection(assetsByConversation),
      'directory_members': directoryMembers
          .map((item) => item.toJson())
          .toList(),
      'active_call': activeCall?.toJson(),
      'events': events.map((item) => item.toJson()).toList(),
      'last_event_id': lastEventId,
    };
  }

  static Map<String, List<T>> _decodeNestedCollection<T>(
    Object? rawValue,
    T Function(Map<String, dynamic> json) factory,
  ) {
    final decoded = <String, List<T>>{};
    final map = rawValue is Map ? rawValue.cast<String, dynamic>() : null;
    if (map == null) {
      return decoded;
    }

    for (final entry in map.entries) {
      final items = (entry.value as List?)
          ?.whereType<Map>()
          .map((item) => factory(item.cast<String, dynamic>()))
          .toList();

      if (items == null) {
        continue;
      }

      decoded[entry.key] = items;
    }

    return decoded;
  }

  static Map<String, List<Map<String, dynamic>>> _encodeNestedCollection<T>(
    Map<String, List<T>> source,
  ) {
    final encoded = <String, List<Map<String, dynamic>>>{};

    for (final entry in source.entries) {
      encoded[entry.key] = entry.value
          .map((item) {
            if (item is ChatMessage) {
              return item.toJson();
            }
            if (item is GroupMember) {
              return item.toJson();
            }
            if (item is ConversationAsset) {
              return item.toJson();
            }

            throw StateError('Unsupported chat snapshot item: $T');
          })
          .toList(growable: false);
    }

    return encoded;
  }
}

class ChatStore {
  ChatStore({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const String _stateKeyPrefix = 'gesit.chat.workspace.v4';
  final SharedPreferencesAsync _prefs;

  String _keyFor(String userId) => '$_stateKeyPrefix.$userId';

  Future<ChatWorkspaceSnapshot?> readWorkspace(String userId) async {
    try {
      final rawValue = await _prefs.getString(_keyFor(userId));
      if (rawValue == null || rawValue.trim().isEmpty) {
        return null;
      }

      final decoded = jsonDecode(rawValue);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return ChatWorkspaceSnapshot.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeWorkspace(
    String userId,
    ChatWorkspaceSnapshot snapshot,
  ) async {
    try {
      await _prefs.setString(_keyFor(userId), jsonEncode(snapshot.toJson()));
    } catch (_) {
      // Ignore local persistence failures and keep chat in-memory.
    }
  }

  Future<void> clearWorkspace(String userId) async {
    try {
      await _prefs.remove(_keyFor(userId));
    } catch (_) {
      // Ignore local persistence failures.
    }
  }
}
