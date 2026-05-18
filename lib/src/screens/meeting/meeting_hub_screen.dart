import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/meeting_workspace_controller.dart';
import '../../models/meeting_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_widgets.dart';

class MeetingHubScreen extends StatefulWidget {
  const MeetingHubScreen({
    super.key,
    required this.controller,
    required this.onJoinMeeting,
  });

  final MeetingWorkspaceController controller;
  final ValueChanged<MeetingSummary> onJoinMeeting;

  @override
  State<MeetingHubScreen> createState() => _MeetingHubScreenState();
}

class _MeetingHubScreenState extends State<MeetingHubScreen> {
  String _filter = 'Live';

  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final meetings = _filteredMeetings(widget.controller.meetings);
        final textTheme = Theme.of(context).textTheme;

        return RefreshIndicator(
          onRefresh: widget.controller.refresh,
          color: AppColors.goldDeep,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, kBottomBarInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RevealUp(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Meeting', style: textTheme.headlineMedium),
                            const SizedBox(height: 6),
                            Text(
                              'Ruang koordinasi realtime untuk internal GESIT.',
                              style: textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      StatusChip(
                        label: widget.controller.liveKitConfigured
                            ? 'LiveKit ready'
                            : 'Setup needed',
                        color: widget.controller.liveKitConfigured
                            ? AppColors.emerald
                            : AppColors.amber,
                        icon: widget.controller.liveKitConfigured
                            ? Icons.verified_rounded
                            : Icons.settings_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                RevealUp(
                  index: 1,
                  child: _MeetingCommandPanel(
                    onStartInstant: () =>
                        _openCreateSheet(joinImmediately: true),
                    onSchedule: () => _openCreateSheet(joinImmediately: false),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final item in const ['Live', 'Terjadwal', 'Selesai'])
                      FilterPill(
                        label: item,
                        selected: _filter == item,
                        onTap: () => setState(() => _filter = item),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                if (widget.controller.errorMessage != null)
                  _InlineMeetingNotice(
                    message: widget.controller.errorMessage!,
                  ),
                if (widget.controller.isBusy &&
                    widget.controller.meetings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (meetings.isEmpty)
                  BrandSurface(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      _filter == 'Live'
                          ? 'Belum ada meeting live.'
                          : 'Tidak ada meeting untuk filter ini.',
                    ),
                  )
                else
                  for (var index = 0; index < meetings.length; index++) ...[
                    RevealUp(
                      index: index + 2,
                      child: _MeetingCard(
                        meeting: meetings[index],
                        onJoin: () => widget.onJoinMeeting(meetings[index]),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<MeetingSummary> _filteredMeetings(List<MeetingSummary> meetings) {
    return meetings
        .where((meeting) {
          return switch (_filter) {
            'Live' => meeting.status == MeetingStatus.live,
            'Terjadwal' => meeting.status == MeetingStatus.scheduled,
            'Selesai' => meeting.status == MeetingStatus.ended,
            _ => false,
          };
        })
        .toList(growable: false);
  }

  Future<void> _openCreateSheet({required bool joinImmediately}) async {
    final created = await showModalBottomSheet<MeetingSummary>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CreateMeetingSheet(
        controller: widget.controller,
        joinImmediately: joinImmediately,
      ),
    );

    if (created != null && joinImmediately) {
      widget.onJoinMeeting(created);
      return;
    }

    if (created != null && !joinImmediately && mounted) {
      setState(() => _filter = 'Terjadwal');
    }
  }
}

class _MeetingCommandPanel extends StatelessWidget {
  const _MeetingCommandPanel({
    required this.onStartInstant,
    required this.onSchedule,
  });

  final VoidCallback onStartInstant;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    return BrandSurface(
      padding: const EdgeInsets.all(16),
      backgroundColor: const Color(0xFF151515),
      radius: 26,
      child: Row(
        children: [
          Expanded(
            child: _CommandButton(
              icon: Icons.video_call_rounded,
              label: 'Instant',
              foreground: Colors.white,
              background: AppColors.goldDeep,
              onTap: onStartInstant,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CommandButton(
              icon: Icons.event_available_rounded,
              label: 'Schedule',
              foreground: Colors.white,
              background: const Color(0xFF2D2D2D),
              onTap: onSchedule,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandButton extends StatelessWidget {
  const _CommandButton({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({required this.meeting, required this.onJoin});

  final MeetingSummary meeting;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canJoin =
        meeting.status == MeetingStatus.live ||
        (meeting.status == MeetingStatus.scheduled && meeting.canModerate);

    return BrandSurface(
      onTap: canJoin ? onJoin : null,
      padding: const EdgeInsets.all(16),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(
                label: meeting.status.label,
                color: meeting.status == MeetingStatus.live
                    ? AppColors.emerald
                    : meeting.status == MeetingStatus.ended
                    ? AppColors.inkMuted
                    : AppColors.blue,
                icon: meeting.status == MeetingStatus.live
                    ? Icons.radio_button_checked_rounded
                    : Icons.schedule_rounded,
              ),
              const Spacer(),
              Icon(
                Icons.people_alt_rounded,
                size: 18,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: 4),
              Text(
                '${meeting.participants.length}',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            meeting.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleLarge,
          ),
          if (meeting.agenda.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              meeting.agenda,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  _meetingTimeLabel(meeting),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (meeting.status == MeetingStatus.scheduled)
                Text(
                  meeting.canModerate ? 'Mulai' : 'Menunggu host',
                  style: textTheme.bodySmall?.copyWith(
                    color: meeting.canModerate
                        ? AppColors.goldDeep
                        : AppColors.inkMuted,
                    fontWeight: FontWeight.w800,
                  ),
                )
              else if (canJoin)
                Icon(Icons.arrow_forward_rounded, color: AppColors.goldDeep),
            ],
          ),
          if (meeting.durationMinutes != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.timelapse_rounded,
                  size: 16,
                  color: AppColors.inkMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  '${meeting.durationMinutes} menit',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _meetingTimeLabel(MeetingSummary meeting) {
    final date = meeting.startsAt ?? meeting.createdAt;
    if (date == null) {
      return 'Waktu belum ditentukan';
    }
    return DateFormat('EEE, dd MMM yyyy • HH:mm', 'id_ID').format(date);
  }
}

class _CreateMeetingSheet extends StatefulWidget {
  const _CreateMeetingSheet({
    required this.controller,
    required this.joinImmediately,
  });

  final MeetingWorkspaceController controller;
  final bool joinImmediately;

  @override
  State<_CreateMeetingSheet> createState() => _CreateMeetingSheetState();
}

class _CreateMeetingSheetState extends State<_CreateMeetingSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _agendaController = TextEditingController();
  final Set<String> _selectedUserIds = <String>{};
  final Set<String> _cohostUserIds = <String>{};
  bool _recordByDefault = false;
  bool _waitingRoomEnabled = false;
  late DateTime _scheduledAt;
  int _durationMinutes = 30;
  int _reminderMinutesBefore = 15;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.joinImmediately
        ? 'Koordinasi cepat GESIT'
        : 'Meeting GESIT';
    _scheduledAt = _nextScheduleSlot();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _agendaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: BrandSurface(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          radius: 30,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: SizedBox(
                    width: 44,
                    child: Divider(thickness: 4, color: AppColors.borderStrong),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.joinImmediately
                      ? 'Instant Meeting'
                      : 'Schedule Meeting',
                  style: textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Topik meeting'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _agendaController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Agenda'),
                ),
                if (!widget.joinImmediately) ...[
                  const SizedBox(height: 16),
                  Text('Jadwal', style: textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _ScheduleField(
                          icon: Icons.calendar_month_rounded,
                          label: 'Tanggal',
                          value: DateFormat(
                            'EEE, dd MMM yyyy',
                            'id_ID',
                          ).format(_scheduledAt),
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ScheduleField(
                          icon: Icons.schedule_rounded,
                          label: 'Jam',
                          value: DateFormat('HH:mm').format(_scheduledAt),
                          onTap: _pickTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Durasi', style: textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final minutes in const [30, 45, 60, 90, 120])
                        ChoiceChip(
                          label: Text('$minutes menit'),
                          selected: _durationMinutes == minutes,
                          onSelected: (_) =>
                              setState(() => _durationMinutes = minutes),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Pengingat', style: textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final minutes in const [0, 5, 10, 15, 30, 60])
                        ChoiceChip(
                          label: Text(
                            minutes == 0
                                ? 'Tanpa reminder'
                                : '$minutes menit sebelumnya',
                          ),
                          selected: _reminderMinutesBefore == minutes,
                          onSelected: (_) =>
                              setState(() => _reminderMinutesBefore = minutes),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Text('Invite participant', style: textTheme.titleMedium),
                const SizedBox(height: 10),
                _ParticipantPicker(
                  members: widget.controller.directoryMembers,
                  selectedUserIds: _selectedUserIds,
                  cohostUserIds: _cohostUserIds,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 16),
                _MeetingOptionSwitch(
                  value: _waitingRoomEnabled,
                  icon: Icons.lock_clock_rounded,
                  title: 'Waiting room',
                  onChanged: (value) =>
                      setState(() => _waitingRoomEnabled = value),
                ),
                _MeetingOptionSwitch(
                  value: _recordByDefault,
                  icon: Icons.fiber_manual_record_rounded,
                  title: 'Recording default',
                  onChanged: (value) =>
                      setState(() => _recordByDefault = value),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.controller.isBusy ? null : _submit,
                    icon: Icon(
                      widget.joinImmediately
                          ? Icons.video_call_rounded
                          : Icons.event_available_rounded,
                    ),
                    label: Text(widget.joinImmediately ? 'Mulai' : 'Simpan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }
    if (!widget.joinImmediately &&
        !_scheduledAt.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih jadwal meeting yang masih akan datang.'),
        ),
      );
      return;
    }

    final meeting = await widget.controller.createMeeting(
      title: title,
      agenda: _agendaController.text.trim(),
      startsAt: widget.joinImmediately ? null : _scheduledAt,
      participantUserIds: _selectedUserIds.toList(growable: false),
      cohostUserIds: _cohostUserIds.toList(growable: false),
      settings: {
        'waiting_room_enabled': _waitingRoomEnabled,
        'record_by_default': _recordByDefault,
        'allow_participant_screen_share': true,
        'chat_enabled': true,
        'polls_enabled': true,
        'duration_minutes': _durationMinutes,
        'reminder_minutes_before': _reminderMinutesBefore,
      },
    );

    if (!mounted || meeting == null) {
      return;
    }
    Navigator.of(context).pop(meeting);
  }

  DateTime _nextScheduleSlot() {
    final now = DateTime.now().add(const Duration(hours: 1));
    final roundedMinute = now.minute < 30 ? 30 : 0;
    final roundedHour = now.minute < 30 ? now.hour : now.hour + 1;
    return DateTime(now.year, now.month, now.day, roundedHour, roundedMinute);
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _scheduledAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _scheduledAt.hour,
        _scheduledAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _scheduledAt = DateTime(
        _scheduledAt.year,
        _scheduledAt.month,
        _scheduledAt.day,
        selected.hour,
        selected.minute,
      );
    });
  }
}

class _ScheduleField extends StatelessWidget {
  const _ScheduleField({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.goldDeep),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantPicker extends StatelessWidget {
  const _ParticipantPicker({
    required this.members,
    required this.selectedUserIds,
    required this.cohostUserIds,
    required this.onChanged,
  });

  final List<MeetingMember> members;
  final Set<String> selectedUserIds;
  final Set<String> cohostUserIds;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Text(
        'Directory user belum tersedia.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: members.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final member = members[index];
          final selected = selectedUserIds.contains(member.id);
          final cohost = cohostUserIds.contains(member.id);

          return CheckboxListTile(
            value: selected,
            contentPadding: EdgeInsets.zero,
            secondary: CircleAvatar(
              backgroundColor: member.accentColor.withValues(alpha: 0.14),
              child: Text(
                _initials(member.name),
                style: TextStyle(
                  color: member.accentColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            title: Text(
              member.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Row(
              children: [
                Expanded(
                  child: Text(
                    member.roleLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      if (cohost) {
                        cohostUserIds.remove(member.id);
                      } else {
                        cohostUserIds.add(member.id);
                      }
                      onChanged();
                    },
                    child: Text(
                      cohost ? 'Co-host' : 'Set co-host',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cohost ? AppColors.goldDeep : AppColors.blue,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            onChanged: (value) {
              if (value == true) {
                selectedUserIds.add(member.id);
              } else {
                selectedUserIds.remove(member.id);
                cohostUserIds.remove(member.id);
              }
              onChanged();
            },
            controlAffinity: ListTileControlAffinity.trailing,
          );
        },
      ),
    );
  }
}

class _MeetingOptionSwitch extends StatelessWidget {
  const _MeetingOptionSwitch({
    required this.value,
    required this.icon,
    required this.title,
    required this.onChanged,
  });

  final bool value;
  final IconData icon;
  final String title;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      contentPadding: EdgeInsets.zero,
      secondary: Icon(
        icon,
        color: value ? AppColors.goldDeep : AppColors.inkMuted,
      ),
      title: Text(title),
      onChanged: onChanged,
    );
  }
}

class _InlineMeetingNotice extends StatelessWidget {
  const _InlineMeetingNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BrandSurface(
        padding: const EdgeInsets.all(14),
        backgroundColor: AppColors.amber.withValues(alpha: 0.1),
        child: Row(
          children: [
            const Icon(Icons.info_rounded, color: AppColors.amber),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  return parts.take(2).map((part) => part[0]).join().toUpperCase();
}
