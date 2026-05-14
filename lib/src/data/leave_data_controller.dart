import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/leave_models.dart';
import 'app_session_controller.dart';
import 'gesit_api_client.dart';
import 'leave_demo_data.dart';

class LeaveDataController extends ChangeNotifier {
  LeaveDataController({
    required AppSessionController sessionController,
    GesitApiClient? apiClient,
  }) : _sessionController = sessionController,
       _apiClient = apiClient ?? GesitApiClient();

  final AppSessionController _sessionController;
  final GesitApiClient _apiClient;

  LeaveDashboardData _dashboard = LeaveDemoData.dashboard();
  bool _loading = false;
  bool _loaded = false;
  bool _usingFallback = true;
  bool _submitting = false;
  String? _error;

  LeaveDashboardData get dashboard => _dashboard;
  bool get loading => _loading;
  bool get loaded => _loaded;
  bool get usingFallback => _usingFallback;
  bool get submitting => _submitting;
  String? get error => _error;

  Future<void> ensureLoaded() async {
    if (_loaded || _loading) {
      return;
    }

    await refresh();
  }

  Future<void> refresh({int? year}) async {
    final session = _sessionController.session;
    if (session == null) {
      return;
    }

    _loading = true;
    notifyListeners();

    try {
      final payload = await _apiClient.fetchLeaveDashboard(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        year: year,
      );
      await _sessionController.syncCookies(payload.cookies);
      _dashboard = LeaveDashboardData.fromJson(payload.data);
      _usingFallback = false;
      _error = null;
    } on GesitApiException catch (error) {
      if (error.statusCode == 401) {
        _error = 'Sesi login berakhir. Silakan masuk lagi.';
        await _sessionController.invalidateSession(errorMessage: _error);
        return;
      }
      _error = error.message;
      _dashboard = LeaveDemoData.dashboard();
      _usingFallback = true;
    } on TimeoutException {
      _error = 'Server cuti terlalu lama merespons.';
      _dashboard = LeaveDemoData.dashboard();
      _usingFallback = true;
    } catch (_) {
      _error = 'Dashboard cuti belum bisa dimuat dari server.';
      _dashboard = LeaveDemoData.dashboard();
      _usingFallback = true;
    } finally {
      _loading = false;
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> submitLeaveRequest({
    required LeaveTypeOption leaveType,
    required LeaveStaffOption replacementStaff,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    required String requesterSignatureDataUrl,
    String? delegationNotes,
    String? emergencyContact,
  }) async {
    final session = _sessionController.session;
    if (session == null) {
      throw const GesitApiException('Session login tidak tersedia.');
    }

    _submitting = true;
    notifyListeners();

    try {
      final payload = await _apiClient.createLeaveRequest(
        baseUrl: session.apiBaseUrl,
        cookies: session.cookies,
        leaveTypeId: leaveType.id,
        replacementUserId: replacementStaff.id,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        requesterSignatureDataUrl: requesterSignatureDataUrl,
        delegationNotes: delegationNotes,
        emergencyContact: emergencyContact,
      );
      await _sessionController.syncCookies(payload.cookies);
      await refresh();
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> cancelLeaveRequest(LeaveRequestItem request) async {
    final session = _sessionController.session;
    if (session == null) {
      throw const GesitApiException('Session login tidak tersedia.');
    }

    final payload = await _apiClient.cancelLeaveRequest(
      baseUrl: session.apiBaseUrl,
      cookies: session.cookies,
      leaveRequestId: request.id,
    );
    await _sessionController.syncCookies(payload.cookies);
    await refresh();
  }

  Future<void> approveLeaveRequest(LeaveRequestItem request) async {
    final session = _sessionController.session;
    if (session == null) {
      throw const GesitApiException('Session login tidak tersedia.');
    }

    final payload = await _apiClient.approveLeaveRequest(
      baseUrl: session.apiBaseUrl,
      cookies: session.cookies,
      leaveRequestId: request.id,
    );
    await _sessionController.syncCookies(payload.cookies);
    await refresh();
  }

  Future<void> rejectLeaveRequest({
    required LeaveRequestItem request,
    required String reviewerNotes,
  }) async {
    final session = _sessionController.session;
    if (session == null) {
      throw const GesitApiException('Session login tidak tersedia.');
    }

    final payload = await _apiClient.rejectLeaveRequest(
      baseUrl: session.apiBaseUrl,
      cookies: session.cookies,
      leaveRequestId: request.id,
      reviewerNotes: reviewerNotes,
    );
    await _sessionController.syncCookies(payload.cookies);
    await refresh();
  }

  Future<Uint8List> fetchLeavePdfPreview(LeaveRequestItem request) async {
    final session = _sessionController.session;
    if (session == null) {
      throw const GesitApiException('Session login tidak tersedia.');
    }

    final payload = await _apiClient.fetchLeavePdfPreview(
      baseUrl: session.apiBaseUrl,
      cookies: session.cookies,
      leaveRequestId: request.id,
    );
    await _sessionController.syncCookies(payload.cookies);

    if (payload.bytes.isEmpty) {
      throw const GesitApiException(
        'File PDF cuti kosong atau belum tersedia.',
      );
    }

    return payload.bytes;
  }

  int estimateWorkingDays(DateTime startDate, DateTime endDate) {
    if (endDate.isBefore(startDate)) {
      return 0;
    }

    final holidayDates = _dashboard.holidays
        .map((holiday) => _dateKey(holiday.date))
        .toSet();
    var cursor = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    var days = 0;

    while (!cursor.isAfter(end)) {
      final isWeekend =
          cursor.weekday == DateTime.saturday ||
          cursor.weekday == DateTime.sunday;
      if (!isWeekend && !holidayDates.contains(_dateKey(cursor))) {
        days++;
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    return days;
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
