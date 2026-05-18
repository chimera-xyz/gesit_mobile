import 'package:flutter/material.dart';

enum MeetingStatus { scheduled, live, ended, cancelled }

extension MeetingStatusX on MeetingStatus {
  static MeetingStatus fromStorageValue(String value) {
    return switch (value.trim().toLowerCase()) {
      'live' => MeetingStatus.live,
      'ended' => MeetingStatus.ended,
      'cancelled' => MeetingStatus.cancelled,
      _ => MeetingStatus.scheduled,
    };
  }

  String get storageValue {
    return switch (this) {
      MeetingStatus.scheduled => 'scheduled',
      MeetingStatus.live => 'live',
      MeetingStatus.ended => 'ended',
      MeetingStatus.cancelled => 'cancelled',
    };
  }

  String get label {
    return switch (this) {
      MeetingStatus.scheduled => 'Terjadwal',
      MeetingStatus.live => 'Live',
      MeetingStatus.ended => 'Selesai',
      MeetingStatus.cancelled => 'Dibatalkan',
    };
  }
}

enum MeetingRole { host, cohost, participant }

extension MeetingRoleX on MeetingRole {
  static MeetingRole fromStorageValue(String value) {
    return switch (value.trim().toLowerCase()) {
      'host' => MeetingRole.host,
      'cohost' => MeetingRole.cohost,
      _ => MeetingRole.participant,
    };
  }

  String get storageValue {
    return switch (this) {
      MeetingRole.host => 'host',
      MeetingRole.cohost => 'cohost',
      MeetingRole.participant => 'participant',
    };
  }

  String get label {
    return switch (this) {
      MeetingRole.host => 'Host',
      MeetingRole.cohost => 'Co-host',
      MeetingRole.participant => 'Participant',
    };
  }

  bool get canModerate =>
      this == MeetingRole.host || this == MeetingRole.cohost;
}

class MeetingMember {
  const MeetingMember({
    required this.id,
    required this.participantId,
    required this.name,
    required this.roleLabel,
    required this.accentColor,
    this.department,
    this.employeeId,
    this.profilePhotoUrl,
    this.isCurrentUser = false,
    this.meetingRole = MeetingRole.participant,
    this.state = 'invited',
  });

  final String id;
  final String participantId;
  final String name;
  final String roleLabel;
  final Color accentColor;
  final String? department;
  final String? employeeId;
  final String? profilePhotoUrl;
  final bool isCurrentUser;
  final MeetingRole meetingRole;
  final String state;

  factory MeetingMember.fromJson(Map<String, dynamic> json) {
    return MeetingMember(
      id: '${json['id'] ?? ''}',
      participantId: '${json['participant_id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      roleLabel: '${json['role_label'] ?? json['role'] ?? 'Internal'}',
      department: json['department'] == null ? null : '${json['department']}',
      employeeId: json['employee_id'] == null ? null : '${json['employee_id']}',
      profilePhotoUrl: json['profile_photo_url'] == null
          ? null
          : '${json['profile_photo_url']}',
      accentColor: Color((json['accent_color'] as num?)?.toInt() ?? 0xFF315EA8),
      isCurrentUser: json['is_current_user'] == true,
      meetingRole: MeetingRoleX.fromStorageValue('${json['role'] ?? ''}'),
      state: '${json['state'] ?? 'invited'}',
    );
  }
}

class MeetingPollOptionResult {
  const MeetingPollOptionResult({
    required this.optionIndex,
    required this.label,
    required this.votes,
  });

  final int optionIndex;
  final String label;
  final int votes;

  factory MeetingPollOptionResult.fromJson(Map<String, dynamic> json) {
    return MeetingPollOptionResult(
      optionIndex: (json['option_index'] as num?)?.toInt() ?? 0,
      label: '${json['label'] ?? ''}',
      votes: (json['votes'] as num?)?.toInt() ?? 0,
    );
  }
}

class MeetingPoll {
  const MeetingPoll({
    required this.id,
    required this.meetingId,
    required this.question,
    required this.options,
    required this.results,
    required this.myVotes,
    required this.status,
    this.allowMultiple = false,
  });

  final String id;
  final String meetingId;
  final String question;
  final List<String> options;
  final List<MeetingPollOptionResult> results;
  final List<int> myVotes;
  final String status;
  final bool allowMultiple;

  bool get isOpen => status == 'open';

  factory MeetingPoll.fromJson(Map<String, dynamic> json) {
    return MeetingPoll(
      id: '${json['id'] ?? ''}',
      meetingId: '${json['meeting_id'] ?? ''}',
      question: '${json['question'] ?? ''}',
      options: ((json['options'] as List?) ?? const [])
          .map((item) => '$item')
          .toList(growable: false),
      results: ((json['results'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                MeetingPollOptionResult.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false),
      myVotes: ((json['my_votes'] as List?) ?? const [])
          .map(
            (item) => item is num ? item.toInt() : int.tryParse('$item') ?? -1,
          )
          .where((item) => item >= 0)
          .toList(growable: false),
      status: '${json['status'] ?? 'draft'}',
      allowMultiple: json['allow_multiple'] == true,
    );
  }
}

class MeetingSummary {
  const MeetingSummary({
    required this.id,
    required this.title,
    required this.roomName,
    required this.type,
    required this.status,
    required this.viewerRole,
    required this.viewerState,
    required this.participants,
    this.agenda = '',
    this.creatorName = 'GESIT',
    this.startsAt,
    this.createdAt,
    this.endedAt,
    this.settings = const <String, dynamic>{},
    this.polls = const <MeetingPoll>[],
  });

  final String id;
  final String title;
  final String agenda;
  final String roomName;
  final String type;
  final MeetingStatus status;
  final MeetingRole viewerRole;
  final String viewerState;
  final List<MeetingMember> participants;
  final String creatorName;
  final DateTime? startsAt;
  final DateTime? createdAt;
  final DateTime? endedAt;
  final Map<String, dynamic> settings;
  final List<MeetingPoll> polls;

  bool get isLive => status == MeetingStatus.live;
  bool get isCall => type == 'call';
  bool get canModerate => viewerRole.canModerate;
  bool get isWaiting => viewerState == 'waiting';
  String get callMediaType => '${settings['call_media_type'] ?? 'voice'}';
  int? get durationMinutes {
    final value = settings['duration_minutes'];
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value');
  }

  int get joinedCount =>
      participants.where((item) => item.state == 'joined').length;

  MeetingSummary copyWith({
    MeetingStatus? status,
    List<MeetingMember>? participants,
    List<MeetingPoll>? polls,
    String? viewerState,
  }) {
    return MeetingSummary(
      id: id,
      title: title,
      agenda: agenda,
      roomName: roomName,
      type: type,
      status: status ?? this.status,
      viewerRole: viewerRole,
      viewerState: viewerState ?? this.viewerState,
      participants: participants ?? this.participants,
      creatorName: creatorName,
      startsAt: startsAt,
      createdAt: createdAt,
      endedAt: endedAt,
      settings: settings,
      polls: polls ?? this.polls,
    );
  }

  factory MeetingSummary.fromJson(Map<String, dynamic> json) {
    return MeetingSummary(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? 'Meeting'}',
      agenda: '${json['agenda'] ?? ''}',
      roomName: '${json['room_name'] ?? ''}',
      type: '${json['type'] ?? 'meeting'}',
      status: MeetingStatusX.fromStorageValue('${json['status'] ?? ''}'),
      viewerRole: MeetingRoleX.fromStorageValue('${json['viewer_role'] ?? ''}'),
      viewerState: '${json['viewer_state'] ?? 'invited'}',
      creatorName: '${json['creator_name'] ?? 'GESIT'}',
      startsAt: DateTime.tryParse('${json['starts_at'] ?? ''}'),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      endedAt: DateTime.tryParse('${json['ended_at'] ?? ''}'),
      settings: json['settings'] is Map<String, dynamic>
          ? json['settings'] as Map<String, dynamic>
          : json['settings'] is Map
          ? (json['settings'] as Map).cast<String, dynamic>()
          : const <String, dynamic>{},
      participants: ((json['participants'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => MeetingMember.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false),
      polls: ((json['polls'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => MeetingPoll.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}

class LiveKitJoinCredentials {
  const LiveKitJoinCredentials({
    required this.url,
    required this.token,
    required this.roomName,
    required this.identity,
    required this.role,
  });

  final String url;
  final String token;
  final String roomName;
  final String identity;
  final MeetingRole role;

  factory LiveKitJoinCredentials.fromJson(Map<String, dynamic> json) {
    return LiveKitJoinCredentials(
      url: '${json['url'] ?? ''}',
      token: '${json['token'] ?? ''}',
      roomName: '${json['room_name'] ?? ''}',
      identity: '${json['identity'] ?? ''}',
      role: MeetingRoleX.fromStorageValue('${json['role'] ?? ''}'),
    );
  }
}

class MeetingJoinPayload {
  const MeetingJoinPayload({required this.meeting, required this.credentials});

  final MeetingSummary meeting;
  final LiveKitJoinCredentials credentials;
}

class MeetingJoinAttempt {
  const MeetingJoinAttempt({
    required this.meeting,
    this.credentials,
    this.waitingRoom = false,
  });

  final MeetingSummary meeting;
  final LiveKitJoinCredentials? credentials;
  final bool waitingRoom;

  bool get canEnterRoom => credentials != null && !waitingRoom;
}
