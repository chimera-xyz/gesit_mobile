import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/meeting_workspace_controller.dart';
import '../../models/meeting_models.dart';
import '../../theme/app_theme.dart';

class MeetingWaitingRoomScreen extends StatefulWidget {
  const MeetingWaitingRoomScreen({
    super.key,
    required this.controller,
    required this.initialMeeting,
    required this.onAdmitted,
  });

  final MeetingWorkspaceController controller;
  final MeetingSummary initialMeeting;
  final ValueChanged<MeetingJoinAttempt> onAdmitted;

  @override
  State<MeetingWaitingRoomScreen> createState() =>
      _MeetingWaitingRoomScreenState();
}

class _MeetingWaitingRoomScreenState extends State<MeetingWaitingRoomScreen> {
  late MeetingSummary _meeting = widget.initialMeeting;
  Timer? _pollTimer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_checkAdmission()),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
              const Spacer(),
              Center(
                child: Container(
                  width: 148,
                  height: 148,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B1B),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFF2E2E2E)),
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    color: AppColors.goldDeep,
                    size: 58,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                _meeting.title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'Host sedang meninjau permintaan masuk Anda.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Center(child: CircularProgressIndicator()),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkAdmission() async {
    if (_checking) {
      return;
    }

    setState(() => _checking = true);
    final refreshed = await widget.controller.refreshMeeting(_meeting.id);
    if (!mounted) {
      return;
    }
    if (refreshed != null) {
      setState(() => _meeting = refreshed);
    }

    if (_meeting.status == MeetingStatus.ended ||
        _meeting.status == MeetingStatus.cancelled ||
        _meeting.viewerState == 'rejected' ||
        _meeting.viewerState == 'removed') {
      Navigator.of(context).pop();
      return;
    }

    if (_meeting.viewerState == 'admitted' ||
        _meeting.viewerState == 'joined') {
      final attempt = await widget.controller.joinMeeting(_meeting.id);
      if (!mounted) {
        return;
      }
      if (attempt != null && attempt.canEnterRoom) {
        widget.onAdmitted(attempt);
        return;
      }
    }

    if (mounted) {
      setState(() => _checking = false);
    }
  }
}
