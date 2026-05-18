import 'package:flutter/foundation.dart';

import '../models/meeting_models.dart';
import 'app_session_controller.dart';
import 'gesit_api_client.dart';

class MeetingWorkspaceController extends ChangeNotifier {
  MeetingWorkspaceController({
    required this.sessionController,
    GesitApiClient? apiClient,
  }) : _apiClient = apiClient ?? GesitApiClient();

  final AppSessionController sessionController;
  final GesitApiClient _apiClient;

  final List<MeetingSummary> _meetings = [];
  final List<MeetingMember> _directoryMembers = [];
  Future<void>? _loadFuture;
  bool _isBusy = false;
  bool _liveKitConfigured = false;
  String? _liveKitUrl;
  String? _errorMessage;

  List<MeetingSummary> get meetings => List.unmodifiable(_meetings);
  List<MeetingMember> get directoryMembers =>
      List.unmodifiable(_directoryMembers);
  bool get isBusy => _isBusy;
  bool get liveKitConfigured => _liveKitConfigured;
  String? get liveKitUrl => _liveKitUrl;
  String? get errorMessage => _errorMessage;

  List<MeetingSummary> get liveMeetings => _meetings
      .where((meeting) => meeting.status == MeetingStatus.live)
      .toList();

  List<MeetingSummary> get upcomingMeetings => _meetings
      .where((meeting) => meeting.status == MeetingStatus.scheduled)
      .toList();

  MeetingSummary? meetingById(String id) {
    for (final meeting in _meetings) {
      if (meeting.id == id) {
        return meeting;
      }
    }
    return null;
  }

  Future<MeetingSummary?> fetchMeetingById(String meetingId) async {
    final session = sessionController.session;
    if (session == null) {
      return null;
    }

    try {
      final payload = await _apiClient.fetchMeetingById(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        meetingId: meetingId,
      );
      final meetingMap = (payload.data['meeting'] as Map?)
          ?.cast<String, dynamic>();
      if (meetingMap == null) {
        return null;
      }

      final meeting = MeetingSummary.fromJson(meetingMap);
      _upsertMeeting(meeting);
      _errorMessage = null;
      return meeting;
    } on GesitApiException catch (exception) {
      _errorMessage = exception.message;
      notifyListeners();
      return null;
    } catch (_) {
      _errorMessage = 'Meeting gagal dimuat.';
      notifyListeners();
      return null;
    }
  }

  Future<MeetingSummary?> refreshMeeting(String meetingId) {
    return fetchMeetingById(meetingId);
  }

  Future<void> ensureLoaded() {
    return _loadFuture ??= refresh();
  }

  Future<void> refresh() async {
    final session = sessionController.session;
    if (session == null) {
      return;
    }

    _setBusy(true);
    try {
      final payload = await _apiClient.fetchMeetings(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
      );
      _applyWorkspacePayload(payload.data);
      _errorMessage = null;
    } on GesitApiException catch (exception) {
      _errorMessage = exception.message;
    } catch (_) {
      _errorMessage = 'Meeting workspace gagal dimuat.';
    } finally {
      _setBusy(false);
    }
  }

  Future<MeetingSummary?> createMeeting({
    required String title,
    String agenda = '',
    DateTime? startsAt,
    List<String> participantUserIds = const <String>[],
    List<String> cohostUserIds = const <String>[],
    Map<String, dynamic> settings = const <String, dynamic>{},
    String type = 'meeting',
  }) async {
    final session = sessionController.session;
    if (session == null) {
      return null;
    }

    _setBusy(true);
    try {
      final payload = await _apiClient.createMeeting(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        title: title,
        agenda: agenda,
        startsAt: startsAt,
        participantUserIds: participantUserIds,
        cohostUserIds: cohostUserIds,
        settings: settings,
        type: type,
      );
      final meetingMap = (payload.data['meeting'] as Map?)
          ?.cast<String, dynamic>();
      if (meetingMap == null) {
        return null;
      }
      final meeting = MeetingSummary.fromJson(meetingMap);
      _upsertMeeting(meeting);
      _errorMessage = null;
      return meeting;
    } on GesitApiException catch (exception) {
      _errorMessage = exception.message;
      return null;
    } catch (_) {
      _errorMessage = 'Meeting gagal dibuat.';
      return null;
    } finally {
      _setBusy(false);
    }
  }

  Future<MeetingJoinAttempt?> joinMeeting(String meetingId) async {
    final session = sessionController.session;
    if (session == null) {
      return null;
    }

    _setBusy(true);
    try {
      final payload = await _apiClient.joinMeeting(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        meetingId: meetingId,
      );
      final meetingMap = (payload.data['meeting'] as Map?)
          ?.cast<String, dynamic>();
      final liveKitMap = (payload.data['livekit'] as Map?)
          ?.cast<String, dynamic>();
      if (meetingMap == null) {
        _errorMessage = 'Meeting tidak lengkap.';
        return null;
      }

      final meeting = MeetingSummary.fromJson(meetingMap);
      _upsertMeeting(meeting);

      if (payload.data['waiting_room'] == true) {
        _errorMessage = null;
        return MeetingJoinAttempt(meeting: meeting, waitingRoom: true);
      }

      if (liveKitMap == null) {
        _errorMessage = 'Credential LiveKit tidak lengkap.';
        return null;
      }

      _errorMessage = null;
      return MeetingJoinAttempt(
        meeting: meeting,
        credentials: LiveKitJoinCredentials.fromJson(liveKitMap),
      );
    } on GesitApiException catch (exception) {
      _errorMessage = exception.message;
      return null;
    } catch (_) {
      _errorMessage = 'Gagal masuk meeting.';
      return null;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> leaveMeeting(String meetingId) async {
    final session = sessionController.session;
    if (session == null) {
      return;
    }

    try {
      final payload = await _apiClient.leaveMeeting(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        meetingId: meetingId,
      );
      _upsertMeetingFromPayload(payload.data);
    } catch (_) {
      // Best-effort cleanup; LiveKit disconnect is more important for UX.
    }
  }

  Future<void> endMeeting(String meetingId) async {
    final session = sessionController.session;
    if (session == null) {
      return;
    }

    _setBusy(true);
    try {
      final payload = await _apiClient.endMeeting(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        meetingId: meetingId,
      );
      _upsertMeetingFromPayload(payload.data);
      _errorMessage = null;
    } on GesitApiException catch (exception) {
      _errorMessage = exception.message;
    } catch (_) {
      _errorMessage = 'Gagal mengakhiri meeting.';
    } finally {
      _setBusy(false);
    }
  }

  Future<MeetingSummary?> admitParticipant({
    required String meetingId,
    required String participantId,
  }) {
    return _moderateParticipant(
      meetingId: meetingId,
      participantId: participantId,
      action: _apiClient.admitMeetingParticipant,
      fallbackError: 'Gagal mengizinkan participant masuk.',
    );
  }

  Future<MeetingSummary?> rejectParticipant({
    required String meetingId,
    required String participantId,
  }) {
    return _moderateParticipant(
      meetingId: meetingId,
      participantId: participantId,
      action: _apiClient.rejectMeetingParticipant,
      fallbackError: 'Gagal menolak participant.',
    );
  }

  Future<MeetingSummary?> promoteParticipant({
    required String meetingId,
    required String participantId,
  }) {
    return _moderateParticipant(
      meetingId: meetingId,
      participantId: participantId,
      action: _apiClient.promoteMeetingParticipant,
      fallbackError: 'Gagal menjadikan participant sebagai co-host.',
    );
  }

  Future<MeetingSummary?> demoteParticipant({
    required String meetingId,
    required String participantId,
  }) {
    return _moderateParticipant(
      meetingId: meetingId,
      participantId: participantId,
      action: _apiClient.demoteMeetingParticipant,
      fallbackError: 'Gagal menurunkan co-host.',
    );
  }

  Future<MeetingSummary?> removeParticipant({
    required String meetingId,
    required String participantId,
  }) {
    return _moderateParticipant(
      meetingId: meetingId,
      participantId: participantId,
      action: _apiClient.removeMeetingParticipant,
      fallbackError: 'Gagal mengeluarkan participant.',
    );
  }

  Future<MeetingPoll?> createPoll({
    required String meetingId,
    required String question,
    required List<String> options,
    bool allowMultiple = false,
  }) async {
    final session = sessionController.session;
    if (session == null) {
      return null;
    }

    try {
      final payload = await _apiClient.createMeetingPoll(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        meetingId: meetingId,
        question: question,
        options: options,
        allowMultiple: allowMultiple,
      );
      final pollMap = (payload.data['poll'] as Map?)?.cast<String, dynamic>();
      if (pollMap == null) {
        return null;
      }
      final poll = MeetingPoll.fromJson(pollMap);
      _upsertPoll(meetingId, poll);
      return poll;
    } on GesitApiException catch (exception) {
      _errorMessage = exception.message;
      notifyListeners();
      return null;
    } catch (_) {
      _errorMessage = 'Polling gagal dibuat.';
      notifyListeners();
      return null;
    }
  }

  Future<MeetingPoll?> votePoll({
    required String meetingId,
    required String pollId,
    required List<int> optionIndexes,
  }) async {
    final session = sessionController.session;
    if (session == null) {
      return null;
    }

    try {
      final payload = await _apiClient.voteMeetingPoll(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        meetingId: meetingId,
        pollId: pollId,
        optionIndexes: optionIndexes,
      );
      final pollMap = (payload.data['poll'] as Map?)?.cast<String, dynamic>();
      if (pollMap == null) {
        return null;
      }
      final poll = MeetingPoll.fromJson(pollMap);
      _upsertPoll(meetingId, poll);
      return poll;
    } catch (_) {
      return null;
    }
  }

  void _applyWorkspacePayload(Map<String, dynamic> data) {
    _liveKitConfigured = data['livekit_configured'] == true;
    _liveKitUrl = data['livekit_url'] == null ? null : '${data['livekit_url']}';

    _meetings
      ..clear()
      ..addAll(
        ((data['meetings'] as List?) ?? const []).whereType<Map>().map(
          (item) => MeetingSummary.fromJson(item.cast<String, dynamic>()),
        ),
      );
    _directoryMembers
      ..clear()
      ..addAll(
        ((data['directory_members'] as List?) ?? const []).whereType<Map>().map(
          (item) => MeetingMember.fromJson(item.cast<String, dynamic>()),
        ),
      );
  }

  Future<MeetingSummary?> _moderateParticipant({
    required String meetingId,
    required String participantId,
    required Future<JsonApiPayload> Function({
      required String baseUrl,
      required Map<String, String> cookies,
      required String meetingId,
      required String participantId,
    })
    action,
    required String fallbackError,
  }) async {
    final session = sessionController.session;
    if (session == null) {
      return null;
    }

    try {
      final payload = await action(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        meetingId: meetingId,
        participantId: participantId,
      );
      final meetingMap = (payload.data['meeting'] as Map?)
          ?.cast<String, dynamic>();
      if (meetingMap == null) {
        return null;
      }
      final meeting = MeetingSummary.fromJson(meetingMap);
      _upsertMeeting(meeting);
      _errorMessage = null;
      return meeting;
    } on GesitApiException catch (exception) {
      _errorMessage = exception.message;
      notifyListeners();
      return null;
    } catch (_) {
      _errorMessage = fallbackError;
      notifyListeners();
      return null;
    }
  }

  void _upsertMeetingFromPayload(Map<String, dynamic> data) {
    final meetingMap = (data['meeting'] as Map?)?.cast<String, dynamic>();
    if (meetingMap == null) {
      return;
    }
    _upsertMeeting(MeetingSummary.fromJson(meetingMap));
  }

  void _upsertPoll(String meetingId, MeetingPoll poll) {
    final index = _meetings.indexWhere((meeting) => meeting.id == meetingId);
    if (index == -1) {
      return;
    }
    final current = _meetings[index];
    final polls = List<MeetingPoll>.from(current.polls);
    final pollIndex = polls.indexWhere((item) => item.id == poll.id);
    if (pollIndex == -1) {
      polls.insert(0, poll);
    } else {
      polls[pollIndex] = poll;
    }
    _meetings[index] = current.copyWith(polls: polls);
    notifyListeners();
  }

  void _upsertMeeting(MeetingSummary meeting) {
    final index = _meetings.indexWhere((item) => item.id == meeting.id);
    if (index == -1) {
      _meetings.insert(0, meeting);
    } else {
      _meetings[index] = meeting;
    }
    notifyListeners();
  }

  void _setBusy(bool value) {
    if (_isBusy == value) {
      return;
    }
    _isBusy = value;
    notifyListeners();
  }
}
