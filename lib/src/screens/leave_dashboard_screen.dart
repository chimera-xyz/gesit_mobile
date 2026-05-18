import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/gesit_api_client.dart';
import '../data/leave_data_controller.dart';
import '../models/leave_models.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import 'leave_pdf_preview_screen.dart';

class LeaveDashboardScreen extends StatefulWidget {
  const LeaveDashboardScreen({super.key, required this.controller});

  final LeaveDataController controller;

  @override
  State<LeaveDashboardScreen> createState() => _LeaveDashboardScreenState();
}

class _LeaveDashboardScreenState extends State<LeaveDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.controller.ensureLoaded());
    });
  }

  Future<void> _openLeaveRequestSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LeaveRequestSheet(controller: widget.controller),
    );

    if (!mounted || created != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pengajuan cuti berhasil dikirim.')),
    );
  }

  Future<void> _cancelRequest(LeaveRequestItem request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan cuti?'),
        content: Text(
          'Pengajuan ${request.leaveType?.name ?? 'cuti'} pada ${_formatDateRange(request.startDate, request.endDate)} akan dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.controller.cancelLeaveRequest(request);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan cuti dibatalkan.')),
      );
    } on GesitApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openLeaveDetail(LeaveRequestItem request) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LeaveRequestDetailSheet(
        request: request,
        controller: widget.controller,
        onCancel: request.canCancel
            ? () {
                Navigator.of(context).pop();
                unawaited(_cancelRequest(request));
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GesitBackground(
        child: SafeArea(
          child: Column(
            children: [
              _LeaveTopBar(
                onBack: () => Navigator.of(context).pop(),
                onRefresh: () => unawaited(widget.controller.refresh()),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: widget.controller,
                  builder: (context, _) {
                    final dashboard = widget.controller.dashboard;

                    return RefreshIndicator(
                      onRefresh: widget.controller.refresh,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LeaveHeader(
                              loading: widget.controller.loading,
                              usingFallback: widget.controller.usingFallback,
                              error: widget.controller.error,
                            ),
                            const SizedBox(height: 18),
                            _BalanceOverview(
                              balance: dashboard.balance,
                              summary: dashboard.summary,
                            ),
                            const SizedBox(height: 14),
                            _PrimaryLeaveAction(
                              onPressed: _openLeaveRequestSheet,
                            ),
                            const SizedBox(height: 24),
                            _LongWeekendSection(items: dashboard.longWeekends),
                            const SizedBox(height: 24),
                            _CalendarSection(
                              events: dashboard.calendar,
                              holidays: dashboard.holidays,
                            ),
                            const SizedBox(height: 24),
                            _RequestHistorySection(
                              requests: dashboard.requests,
                              onOpen: _openLeaveDetail,
                              onCancel: _cancelRequest,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaveTopBar extends StatelessWidget {
  const _LeaveTopBar({required this.onBack, required this.onRefresh});

  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Kembali',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface.withValues(alpha: 0.92),
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.border),
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cuti',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleLarge?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Refresh',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface.withValues(alpha: 0.92),
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.border),
            ),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _LeaveHeader extends StatelessWidget {
  const _LeaveHeader({
    required this.loading,
    required this.usingFallback,
    required this.error,
  });

  final bool loading;
  final bool usingFallback;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Dashboard Cuti',
                style: textTheme.displayMedium?.copyWith(
                  fontSize: 32,
                  height: 1.05,
                ),
              ),
            ),
            if (loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          BrandSurface(
            radius: 18,
            padding: const EdgeInsets.all(14),
            backgroundColor: usingFallback
                ? AppColors.goldSoft.withValues(alpha: 0.36)
                : AppColors.surface,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  usingFallback
                      ? Icons.wifi_off_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.goldDeep,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    usingFallback
                        ? 'Server cuti belum siap. Menampilkan data contoh.'
                        : error!,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BalanceOverview extends StatelessWidget {
  const _BalanceOverview({required this.balance, required this.summary});

  final LeaveBalanceSummary balance;
  final LeaveDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final totalDays = balance.totalDays <= 0 ? 1 : balance.totalDays;
    final usedFraction = ((balance.usedDays + balance.pendingDays) / totalDays)
        .clamp(0, 1)
        .toDouble();
    final currentLeave = summary.currentLeave;
    final currentLeaveName = currentLeave?.leaveType?.name ?? 'cuti';

    return BrandSurface(
      padding: const EdgeInsets.all(18),
      radius: 24,
      backgroundColor: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.goldSoft.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.beach_access_rounded,
                  color: AppColors.goldDeep,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(balance.leaveType.name, style: textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Periode ${balance.year}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDays(balance.remainingDays),
                    style: textTheme.headlineMedium?.copyWith(
                      fontSize: 28,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'sisa',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: usedFraction,
              minHeight: 10,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation(AppColors.goldDeep),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TinyMetric(
                  label: 'Terpakai',
                  value: _formatDays(balance.usedDays),
                  icon: Icons.check_circle_rounded,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TinyMetric(
                  label: 'Pending',
                  value: _formatDays(balance.pendingDays),
                  icon: Icons.schedule_rounded,
                  color: AppColors.amber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TinyMetric(
                  label: 'Total',
                  value: _formatDays(balance.totalDays),
                  icon: Icons.calendar_month_rounded,
                  color: AppColors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.border.withValues(alpha: 0.8)),
          const SizedBox(height: 12),
          _SummaryLine(
            label: 'Status hari ini',
            value: currentLeave == null
                ? 'Aktif bekerja'
                : 'Sedang $currentLeaveName',
          ),
          if (currentLeave != null &&
              summary.currentLeaveReturnDate != null) ...[
            const SizedBox(height: 10),
            _SummaryLine(
              label: 'Kembali kerja',
              value: _formatDateRange(
                summary.currentLeaveReturnDate!,
                summary.currentLeaveReturnDate!,
              ),
            ),
          ],
          const SizedBox(height: 10),
          _SummaryLine(
            label: 'Cuti terakhir',
            value: summary.lastLeave == null
                ? 'Belum ada'
                : _formatDateRange(
                    summary.lastLeave!.startDate,
                    summary.lastLeave!.endDate,
                  ),
          ),
          const SizedBox(height: 10),
          _SummaryLine(
            label: 'Cuti berikutnya',
            value: summary.nextLeave == null
                ? 'Belum ada'
                : '${_formatDateRange(summary.nextLeave!.startDate, summary.nextLeave!.endDate)} • ${summary.nextLeave!.statusLabel}',
          ),
        ],
      ),
    );
  }
}

class _TinyMetric extends StatelessWidget {
  const _TinyMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryLeaveAction extends StatelessWidget {
  const _PrimaryLeaveAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajukan cuti'),
      ),
    );
  }
}

class _LongWeekendSection extends StatelessWidget {
  const _LongWeekendSection({required this.items});

  final List<LongWeekendRecommendation> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(eyebrow: 'Insight', title: 'Long Weekend'),
        const SizedBox(height: 14),
        if (items.isEmpty)
          BrandSurface(
            radius: 20,
            padding: const EdgeInsets.all(16),
            child: Text(
              'Belum ada rekomendasi.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          SizedBox(
            height: 154,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  _LongWeekendCard(item: items[index]),
            ),
          ),
      ],
    );
  }
}

class _LongWeekendCard extends StatelessWidget {
  const _LongWeekendCard({required this.item});

  final LongWeekendRecommendation item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final suggestedDates = item.suggestedLeaveDates
        .map(_formatShortDate)
        .join(', ');

    return SizedBox(
      width: 260,
      child: BrandSurface(
        radius: 22,
        padding: const EdgeInsets.all(16),
        backgroundColor: AppColors.surfaceAlt,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusChip(
                  label: '${item.daysOff} hari',
                  color: AppColors.goldDeep,
                  icon: Icons.bolt_rounded,
                ),
                const Spacer(),
                Icon(
                  item.leaveDaysNeeded == 0
                      ? Icons.event_available_rounded
                      : Icons.event_repeat_rounded,
                  color: AppColors.blue,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.holidayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              _formatDateRange(item.startDate, item.endDate),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              item.leaveDaysNeeded == 0
                  ? 'Tanpa cuti tambahan'
                  : 'Ambil cuti: $suggestedDates',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.goldDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarSection extends StatefulWidget {
  const _CalendarSection({required this.events, required this.holidays});

  final List<LeaveCalendarEvent> events;
  final List<LeaveHolidayItem> holidays;

  @override
  State<_CalendarSection> createState() => _CalendarSectionState();
}

class _CalendarSectionState extends State<_CalendarSection> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  void _moveMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  void _showDayDetails(DateTime date, List<_CalendarDayEntry> entries) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_formatFullDate(date)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < entries.length; index++) ...[
              _CalendarDetailRow(entry: entries[index]),
              if (index != entries.length - 1)
                const Divider(height: 18, color: AppColors.border),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entriesByDay = _buildCalendarEntries(
      events: widget.events,
      holidays: widget.holidays,
    );
    final days = _calendarDaysFor(_visibleMonth);
    final monthHolidays =
        widget.holidays
            .where((holiday) => _sameMonth(holiday.date, _visibleMonth))
            .toList(growable: false)
          ..sort((a, b) => a.date.compareTo(b.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(eyebrow: 'Kalender', title: 'Cuti & Libur'),
        const SizedBox(height: 14),
        BrandSurface(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          child: Column(
            children: [
              _CalendarMonthHeader(
                month: _visibleMonth,
                onPrevious: () => _moveMonth(-1),
                onNext: () => _moveMonth(1),
              ),
              const SizedBox(height: 14),
              const _CalendarWeekHeader(),
              const SizedBox(height: 8),
              GridView.builder(
                itemCount: days.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, index) {
                  final day = days[index];

                  if (day == null) {
                    return const SizedBox.shrink();
                  }

                  final entries =
                      entriesByDay[_dateKey(day)] ??
                      const <_CalendarDayEntry>[];

                  return _CalendarDayTile(
                    date: day,
                    entries: entries,
                    isToday: _isSameDay(day, DateTime.now()),
                    onTap: entries.isEmpty
                        ? null
                        : () => _showDayDetails(day, entries),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _MonthHolidaySummary(month: _visibleMonth, holidays: monthHolidays),
      ],
    );
  }
}

class _CalendarMonthHeader extends StatelessWidget {
  const _CalendarMonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        _CalendarNavButton(
          tooltip: 'Bulan sebelumnya',
          icon: Icons.chevron_left_rounded,
          onPressed: onPrevious,
        ),
        Expanded(
          child: Text(
            _formatMonthYear(month),
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(fontSize: 17),
          ),
        ),
        _CalendarNavButton(
          tooltip: 'Bulan berikutnya',
          icon: Icons.chevron_right_rounded,
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _CalendarNavButton extends StatelessWidget {
  const _CalendarNavButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surfaceAlt,
          foregroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }
}

class _CalendarWeekHeader extends StatelessWidget {
  const _CalendarWeekHeader();

  static const _labels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        for (final label in _labels)
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: label == 'Min' ? AppColors.red : AppColors.inkMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarDayTile extends StatelessWidget {
  const _CalendarDayTile({
    required this.date,
    required this.entries,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final List<_CalendarDayEntry> entries;
  final bool isToday;
  final VoidCallback? onTap;

  bool get _isHoliday => entries.any((entry) => entry.isHoliday);
  bool get _isSunday => date.weekday == DateTime.sunday;
  bool get _isSaturday => date.weekday == DateTime.saturday;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final primaryEntry = entries.isEmpty ? null : entries.first;
    final isRedDate = _isHoliday || _isSunday;
    final textColor = isRedDate
        ? AppColors.red
        : _isSaturday
        ? AppColors.inkMuted
        : AppColors.ink;
    final backgroundColor = primaryEntry == null
        ? isToday
              ? AppColors.goldSoft.withValues(alpha: 0.36)
              : Colors.transparent
        : primaryEntry.color.withValues(alpha: isRedDate ? 0.12 : 0.1);
    final borderColor = isToday
        ? AppColors.goldDeep
        : primaryEntry == null
        ? AppColors.border.withValues(alpha: 0.45)
        : primaryEntry.color.withValues(alpha: 0.32);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            child: Column(
              children: [
                Text(
                  '${date.day}',
                  style: textTheme.labelLarge?.copyWith(
                    color: textColor,
                    fontWeight: isToday || entries.isNotEmpty
                        ? FontWeight.w900
                        : FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (entries.isNotEmpty)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 3,
                    runSpacing: 3,
                    children: [
                      for (final entry in entries.take(3))
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: entry.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  )
                else
                  const SizedBox(height: 5),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarDetailRow extends StatelessWidget {
  const _CalendarDetailRow({required this.entry});

  final _CalendarDayEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: entry.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(_eventIcon(entry.kind), color: entry.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.title, style: textTheme.labelLarge),
              const SizedBox(height: 6),
              StatusChip(label: _eventLabel(entry.kind), color: entry.color),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthHolidaySummary extends StatelessWidget {
  const _MonthHolidaySummary({required this.month, required this.holidays});

  final DateTime month;
  final List<LeaveHolidayItem> holidays;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          eyebrow: 'Libur',
          title: 'Tanggal Merah',
          trailing: Text(
            _formatMonthYear(month),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (holidays.isEmpty)
          BrandSurface(
            radius: 20,
            padding: const EdgeInsets.all(16),
            child: Text(
              'Tidak ada tanggal merah.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          BrandSurface(
            radius: 22,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < holidays.length; index++) ...[
                  _HolidayRow(holiday: holidays[index]),
                  if (index != holidays.length - 1)
                    const Divider(height: 1, color: AppColors.border),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _HolidayRow extends StatelessWidget {
  const _HolidayRow({required this.holiday});

  final LeaveHolidayItem holiday;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              _formatShortDate(holiday.date),
              style: textTheme.labelLarge?.copyWith(color: AppColors.red),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              holiday.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (holiday.isJointLeave)
            const StatusChip(label: 'Cuti bersama', color: AppColors.blue),
        ],
      ),
    );
  }
}

class _CalendarDayEntry {
  const _CalendarDayEntry({
    required this.date,
    required this.title,
    required this.kind,
    required this.color,
    required this.isHoliday,
  });

  final DateTime date;
  final String title;
  final String kind;
  final Color color;
  final bool isHoliday;
}

class _RequestHistorySection extends StatelessWidget {
  const _RequestHistorySection({
    required this.requests,
    required this.onOpen,
    required this.onCancel,
  });

  final List<LeaveRequestItem> requests;
  final ValueChanged<LeaveRequestItem> onOpen;
  final ValueChanged<LeaveRequestItem> onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(eyebrow: 'Riwayat', title: 'Pengajuan Cuti'),
        const SizedBox(height: 14),
        if (requests.isEmpty)
          BrandSurface(
            radius: 20,
            padding: const EdgeInsets.all(16),
            child: Text(
              'Belum ada riwayat cuti.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          Column(
            children: [
              for (var index = 0; index < requests.length; index++) ...[
                _LeaveRequestCard(
                  request: requests[index],
                  onTap: () => onOpen(requests[index]),
                  onCancel: requests[index].canCancel
                      ? () => onCancel(requests[index])
                      : null,
                ),
                if (index != requests.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
      ],
    );
  }
}

class _LeaveRequestCard extends StatelessWidget {
  const _LeaveRequestCard({required this.request, this.onTap, this.onCancel});

  final LeaveRequestItem request;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final statusColor = _statusColor(request.status);

    return BrandSurface(
      radius: 22,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(label: request.statusLabel, color: statusColor),
              const Spacer(),
              Text(
                request.durationLabel,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(request.leaveType?.name ?? 'Cuti', style: textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            _formatDateRange(request.startDate, request.endDate),
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            request.reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
          if ((request.replacementName ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Staff pengganti: ${request.replacementName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if ((request.currentPendingActorLabel ?? '').trim().isNotEmpty &&
              request.status == 'pending') ...[
            const SizedBox(height: 6),
            Text(
              'Menunggu: ${request.currentPendingActorLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ],
          if ((request.reviewerNotes ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Catatan: ${request.reviewerNotes}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (onCancel != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Lihat detail',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.goldDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.goldDeep,
                  size: 18,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Batalkan'),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Lihat detail',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.goldDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.goldDeep,
                  size: 18,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LeaveRequestDetailSheet extends StatelessWidget {
  const _LeaveRequestDetailSheet({
    required this.request,
    required this.controller,
    this.onCancel,
  });

  final LeaveRequestItem request;
  final LeaveDataController controller;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final statusColor = _statusColor(request.status);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          child: BrandSurface(
            radius: 30,
            backgroundColor: AppColors.surface,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.borderStrong,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                StatusChip(
                                  label: request.statusLabel,
                                  color: statusColor,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  request.leaveType?.name ?? 'Pengajuan Cuti',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.titleLarge?.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _formatDateRange(
                                    request.startDate,
                                    request.endDate,
                                  ),
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: AppColors.inkSoft,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Tutup',
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: !request.canPreviewPdf
                                  ? null
                                  : () => pushBrandedRoute(
                                      context,
                                      LeavePdfPreviewScreen(
                                        request: request,
                                        controller: controller,
                                      ),
                                    ),
                              icon: const Icon(Icons.picture_as_pdf_rounded),
                              label: Text(
                                request.canPreviewPdf
                                    ? 'Lihat PDF'
                                    : 'PDF belum tersedia',
                              ),
                            ),
                          ),
                          if (onCancel != null) ...[
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: onCancel,
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text('Batalkan'),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 18),
                      _LeaveDetailBlock(
                        title: 'Detail',
                        children: [
                          _LeaveDetailRow(
                            label: 'Durasi',
                            value: request.durationLabel,
                          ),
                          _LeaveDetailRow(
                            label: 'Staff pengganti',
                            value:
                                request.replacementName?.trim().isNotEmpty ==
                                    true
                                ? request.replacementName!
                                : '-',
                          ),
                          _LeaveDetailRow(
                            label: 'Menunggu',
                            value:
                                request.currentPendingActorLabel
                                        ?.trim()
                                        .isNotEmpty ==
                                    true
                                ? request.currentPendingActorLabel!
                                : '-',
                          ),
                          _LeaveDetailRow(
                            label: 'Alasan',
                            value: request.reason.trim().isEmpty
                                ? '-'
                                : request.reason,
                          ),
                          if ((request.emergencyContact ?? '')
                              .trim()
                              .isNotEmpty)
                            _LeaveDetailRow(
                              label: 'Kontak darurat',
                              value: request.emergencyContact!,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _LeaveDetailBlock(
                        title: 'Approval',
                        children: request.approvalSteps.isEmpty
                            ? const [_LeaveEmptyTimeline()]
                            : [
                                for (final step in request.approvalSteps)
                                  _LeaveApprovalStepTile(step: step),
                              ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaveDetailBlock extends StatelessWidget {
  const _LeaveDetailBlock({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _LeaveDetailRow extends StatelessWidget {
  const _LeaveDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.inkMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveApprovalStepTile extends StatelessWidget {
  const _LeaveApprovalStepTile({required this.step});

  final LeaveApprovalStepItem step;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = step.status.trim().toLowerCase();
    final color = _approvalStepColor(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_approvalStepIcon(status), color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.stepName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.approverName?.trim().isNotEmpty == true
                      ? step.approverName!
                      : step.actorLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((step.notes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    step.notes!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(label: _approvalStepLabel(status), color: color),
        ],
      ),
    );
  }
}

class _LeaveEmptyTimeline extends StatelessWidget {
  const _LeaveEmptyTimeline();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Timeline belum tersedia.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.inkMuted,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LeaveRequestSheet extends StatefulWidget {
  const _LeaveRequestSheet({required this.controller});

  final LeaveDataController controller;

  @override
  State<_LeaveRequestSheet> createState() => _LeaveRequestSheetState();
}

class _LeaveRequestSheetState extends State<_LeaveRequestSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _emergencyController = TextEditingController();
  LeaveTypeOption? _selectedType;
  LeaveStaffOption? _selectedReplacement;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _submitting = false;
  String? _sheetMessage;

  @override
  void initState() {
    super.initState();
    final dashboard = widget.controller.dashboard;
    _selectedType = dashboard.leaveTypes.firstWhere(
      (type) => type.code == 'annual',
      orElse: () => dashboard.leaveTypes.isEmpty
          ? const LeaveTypeOption(
              id: '',
              code: 'annual',
              name: 'Tahunan(Cuti)',
              description: '',
              defaultAnnualQuota: 12,
              requiresBalance: true,
              requiresAttachment: false,
              isPaid: true,
              color: '#9B6B17',
            )
          : dashboard.leaveTypes.first,
    );
    _selectedReplacement = dashboard.staffOptions.isEmpty
        ? null
        : dashboard.staffOptions.first;
    final today = _dateOnly(DateTime.now());
    _startDate = _nextWorkingDate(today);
    _endDate = _startDate;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _reasonController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await _pickDate(_startDate);
    if (picked == null) {
      return;
    }

    setState(() {
      _sheetMessage = null;
      _startDate = picked;
      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await _pickDate(_endDate, firstDate: _startDate);
    if (picked == null) {
      return;
    }

    setState(() {
      _sheetMessage = null;
      _endDate = picked;
    });
  }

  Future<DateTime?> _pickDate(DateTime initialDate, {DateTime? firstDate}) {
    final today = _dateOnly(DateTime.now());
    final effectiveFirstDate = _nextWorkingDate(firstDate ?? today);
    final effectiveInitialDate = _nextWorkingDate(
      initialDate.isBefore(effectiveFirstDate)
          ? effectiveFirstDate
          : initialDate,
      minimum: effectiveFirstDate,
    );

    return showDatePicker(
      context: context,
      initialDate: effectiveInitialDate,
      firstDate: effectiveFirstDate,
      lastDate: DateTime(today.year + 2, 12, 31),
      selectableDayPredicate: (date) =>
          !date.isBefore(effectiveFirstDate) && !_isNonWorkingDate(date),
      builder: (context, child) {
        final theme = Theme.of(context);
        const pickerTextColor = Colors.black;
        const selectedDateBackground = Color(0xFFEDEDED);
        const disabledDateColor = Color(0xFFB3B3B3);

        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: pickerTextColor,
              onPrimary: pickerTextColor,
              surface: Colors.white,
              onSurface: pickerTextColor,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: pickerTextColor),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              headerBackgroundColor: Colors.white,
              headerForegroundColor: pickerTextColor,
              dividerColor: const Color(0xFFE5E5E5),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return disabledDateColor;
                }

                return pickerTextColor;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return selectedDateBackground;
                }

                return Colors.transparent;
              }),
              todayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return disabledDateColor;
                }

                return pickerTextColor;
              }),
              todayBackgroundColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
              todayBorder: const BorderSide(color: pickerTextColor),
              yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return disabledDateColor;
                }

                return pickerTextColor;
              }),
              yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return selectedDateBackground;
                }

                return Colors.transparent;
              }),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  Future<LeaveStaffOption?> _showStaffPicker() {
    final staffOptions = widget.controller.dashboard.staffOptions;
    if (staffOptions.isEmpty) {
      _showValidationMessage('Staff pengganti belum tersedia.');
      return Future.value(null);
    }

    return showDialog<LeaveStaffOption>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (context) => _StaffSearchDialog(
        staffOptions: staffOptions,
        selectedStaff: _selectedReplacement,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final leaveTypes = widget.controller.dashboard.leaveTypes;
    final leaveType =
        leaveTypes.where((type) => type.id == _selectedType?.id).firstOrNull ??
        (leaveTypes.isEmpty ? null : leaveTypes.first);
    if (leaveType == null || leaveType.id.trim().isEmpty) {
      _showValidationMessage('Jenis cuti belum tersedia.');
      return;
    }

    final staffOptions = widget.controller.dashboard.staffOptions;
    final replacementStaff =
        staffOptions
            .where((staff) => staff.id == _selectedReplacement?.id)
            .firstOrNull ??
        (staffOptions.isEmpty ? null : staffOptions.first);
    if (replacementStaff == null || replacementStaff.id.trim().isEmpty) {
      _showValidationMessage('Staff pengganti belum tersedia.');
      return;
    }

    if (_isNonWorkingDate(_startDate)) {
      _showValidationMessage('Tanggal mulai cuti harus hari kerja.');
      return;
    }

    if (_isNonWorkingDate(_endDate)) {
      _showValidationMessage('Tanggal selesai cuti harus hari kerja.');
      return;
    }

    final estimatedDays = widget.controller.estimateWorkingDays(
      _startDate,
      _endDate,
    );
    if (estimatedDays <= 0) {
      _showValidationMessage(
        'Rentang cuti belum punya hari kerja yang bisa diajukan.',
      );
      return;
    }

    final signatureDataUrl = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (context) => _LeaveSubmitSignatureSheet(
        title: 'Tanda tangan pemohon',
        onUseSignature: (signature) => Navigator.of(context).pop(signature),
      ),
    );
    if (!mounted || signatureDataUrl == null || signatureDataUrl.isEmpty) {
      return;
    }

    setState(() {
      _submitting = true;
      _sheetMessage = null;
    });
    try {
      await widget.controller.submitLeaveRequest(
        leaveType: leaveType,
        replacementStaff: replacementStaff,
        startDate: _startDate,
        endDate: _endDate,
        reason: _reasonController.text,
        requesterSignatureDataUrl: signatureDataUrl,
        emergencyContact: _emergencyController.text,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on GesitApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showValidationMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Set<String> get _holidayDateKeys => widget.controller.dashboard.holidays
      .map((holiday) => _dateKey(holiday.date))
      .toSet();

  bool _isNonWorkingDate(DateTime date) {
    final normalizedDate = _dateOnly(date);
    final isWeekend =
        normalizedDate.weekday == DateTime.saturday ||
        normalizedDate.weekday == DateTime.sunday;

    return isWeekend || _holidayDateKeys.contains(_dateKey(normalizedDate));
  }

  DateTime _nextWorkingDate(DateTime date, {DateTime? minimum}) {
    var cursor = _dateOnly(date);
    final minDate = minimum == null ? null : _dateOnly(minimum);
    if (minDate != null && cursor.isBefore(minDate)) {
      cursor = minDate;
    }

    var checkedDays = 0;
    while (_isNonWorkingDate(cursor) && checkedDays < 730) {
      cursor = cursor.add(const Duration(days: 1));
      checkedDays++;
    }

    return cursor;
  }

  void _showValidationMessage(String message) {
    setState(() => _sheetMessage = message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final estimatedDays = widget.controller.estimateWorkingDays(
      _startDate,
      _endDate,
    );
    final leaveTypes = widget.controller.dashboard.leaveTypes;
    final staffOptions = widget.controller.dashboard.staffOptions;
    final selectedValue =
        leaveTypes.where((type) => type.id == _selectedType?.id).firstOrNull ??
        (leaveTypes.isEmpty ? null : leaveTypes.first);
    final selectedReplacement =
        staffOptions
            .where((staff) => staff.id == _selectedReplacement?.id)
            .firstOrNull ??
        (staffOptions.isEmpty ? null : staffOptions.first);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Ajukan cuti', style: textTheme.titleLarge),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _sheetMessage == null
                      ? const SizedBox(height: 16)
                      : Padding(
                          key: ValueKey(_sheetMessage),
                          padding: const EdgeInsets.only(top: 12, bottom: 16),
                          child: _LeaveFormAlert(
                            message: _sheetMessage!,
                            onClose: () => setState(() => _sheetMessage = null),
                          ),
                        ),
                ),
                DropdownButtonFormField<LeaveTypeOption>(
                  initialValue: selectedValue,
                  isExpanded: true,
                  items: [
                    for (final type in leaveTypes)
                      DropdownMenuItem(
                        value: type,
                        child: Text(
                          type.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _sheetMessage = null;
                    _selectedType = value;
                  }),
                  validator: (value) =>
                      value == null ? 'Pilih jenis cuti.' : null,
                  decoration: const InputDecoration(labelText: 'Jenis cuti'),
                ),
                const SizedBox(height: 12),
                FormField<LeaveStaffOption>(
                  key: ValueKey(selectedReplacement?.id ?? 'empty-staff'),
                  initialValue: selectedReplacement,
                  validator: (value) =>
                      value == null ? 'Pilih staff pengganti.' : null,
                  builder: (field) => _StaffPickerField(
                    staff: selectedReplacement,
                    errorText: field.errorText,
                    onTap: () async {
                      final picked = await _showStaffPicker();
                      if (picked == null) {
                        return;
                      }

                      setState(() {
                        _sheetMessage = null;
                        _selectedReplacement = picked;
                      });
                      field.didChange(picked);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerField(
                        label: 'Mulai',
                        value: _formatShortDate(_startDate),
                        onTap: _pickStartDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DatePickerField(
                        label: 'Selesai',
                        value: _formatShortDate(_endDate),
                        onTap: _pickEndDate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Estimasi durasi: ${_formatDays(estimatedDays)} hari kerja',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reasonController,
                  minLines: 3,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  validator: (value) {
                    if ((value ?? '').trim().length < 6) {
                      return 'Alasan minimal 6 karakter.';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(labelText: 'Alasan'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emergencyController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Kontak darurat',
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _submitting ? 'Mengirim...' : 'Kirim pengajuan',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaveSubmitSignatureSheet extends StatefulWidget {
  const _LeaveSubmitSignatureSheet({
    required this.title,
    required this.onUseSignature,
  });

  final String title;
  final ValueChanged<String> onUseSignature;

  @override
  State<_LeaveSubmitSignatureSheet> createState() =>
      _LeaveSubmitSignatureSheetState();
}

class _LeaveSubmitSignatureSheetState
    extends State<_LeaveSubmitSignatureSheet> {
  final List<List<Offset>> _strokes = <List<Offset>>[];
  String? _errorText;
  double _headerDragOffset = 0;
  Size _canvasSize = const Size(1, 1);

  bool get _hasSignature => _strokes.any((stroke) => stroke.isNotEmpty);

  void _handlePanStart(DragStartDetails details) {
    setState(() {
      _errorText = null;
      _strokes.add([details.localPosition]);
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_strokes.isEmpty) {
      return;
    }

    setState(() => _strokes.last.add(details.localPosition));
  }

  void _clearCanvas() {
    setState(() {
      _errorText = null;
      _strokes.clear();
    });
  }

  Future<void> _submit() async {
    if (!_hasSignature) {
      setState(() => _errorText = 'Tanda tangan belum digambar.');
      return;
    }

    final signatureDataUrl = await _buildSignatureDataUrl();
    if (signatureDataUrl == null || signatureDataUrl.trim().isEmpty) {
      setState(() => _errorText = 'Tanda tangan tidak berhasil diproses.');
      return;
    }

    widget.onUseSignature(signatureDataUrl);
  }

  void _handleHeaderDragUpdate(DragUpdateDetails details) {
    _headerDragOffset += details.delta.dy;
  }

  void _handleHeaderDragEnd(DragEndDetails details) {
    final shouldClose =
        _headerDragOffset > 48 ||
        (details.primaryVelocity != null && details.primaryVelocity! > 650);
    _headerDragOffset = 0;

    if (shouldClose) {
      Navigator.of(context).pop();
    }
  }

  Future<String?> _buildSignatureDataUrl() async {
    final exportSize = Size(
      _canvasSize.width <= 1 ? 900 : _canvasSize.width,
      _canvasSize.height <= 1 ? 420 : _canvasSize.height,
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Offset.zero & exportSize;
    canvas.drawRect(rect, Paint()..color = Colors.white);
    _LeaveSignatureStrokePainter(strokes: _strokes).paint(canvas, exportSize);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      exportSize.width.ceil(),
      exportSize.height.ceil(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return null;
    }

    return 'data:image/png;base64,${base64Encode(byteData.buffer.asUint8List())}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          child: BrandSurface(
            radius: 30,
            backgroundColor: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: _handleHeaderDragUpdate,
                  onVerticalDragEnd: _handleHeaderDragEnd,
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.borderStrong,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleLarge?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _canvasSize = Size(
                        constraints.maxWidth - 24,
                        constraints.maxHeight - 24,
                      );

                      return Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: _handlePanStart,
                            onPanUpdate: _handlePanUpdate,
                            child: CustomPaint(
                              foregroundPainter: _LeaveSignatureStrokePainter(
                                strokes: _strokes,
                              ),
                              child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                color: Colors.white,
                                alignment: Alignment.center,
                                child: IgnorePointer(
                                  child: !_hasSignature
                                      ? Text(
                                          'Tanda tangan di sini',
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: AppColors.inkMuted,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Batal'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _clearCanvas,
                      child: const Text('Hapus'),
                    ),
                  ],
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorText!,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Pakai tanda tangan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaveSignatureStrokePainter extends CustomPainter {
  const _LeaveSignatureStrokePainter({required this.strokes});

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) {
        continue;
      }

      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, paint.strokeWidth / 2, paint);
        continue;
      }

      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var index = 1; index < stroke.length; index++) {
        path.lineTo(stroke[index].dx, stroke[index].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LeaveSignatureStrokePainter oldDelegate) {
    return true;
  }
}

class _StaffPickerField extends StatelessWidget {
  const _StaffPickerField({
    required this.staff,
    required this.onTap,
    this.errorText,
  });

  final LeaveStaffOption? staff;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selectedStaff = staff;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Staff pengganti',
            helperText: 'Staff ini akan menyetujui tahap pertama.',
            errorText: errorText,
            suffixIcon: const Icon(Icons.search_rounded),
          ),
          child: selectedStaff == null
              ? Text(
                  'Pilih staff pengganti',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : _StaffDropdownLabel(staff: selectedStaff, compact: true),
        ),
      ),
    );
  }
}

class _StaffSearchDialog extends StatefulWidget {
  const _StaffSearchDialog({required this.staffOptions, this.selectedStaff});

  final List<LeaveStaffOption> staffOptions;
  final LeaveStaffOption? selectedStaff;

  @override
  State<_StaffSearchDialog> createState() => _StaffSearchDialogState();
}

class _StaffSearchDialogState extends State<_StaffSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<LeaveStaffOption> get _filteredStaff {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) {
      return widget.staffOptions;
    }

    return widget.staffOptions
        .where((staff) {
          final haystack = [
            staff.name,
            staff.email ?? '',
            staff.department ?? '',
            staff.roleLabel ?? '',
          ].join(' ').toLowerCase();

          return haystack.contains(needle);
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final staffList = _filteredStaff;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.74,
        ),
        child: BrandSurface(
          radius: 28,
          backgroundColor: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pilih staff pengganti',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Tutup',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  labelText: 'Cari staff',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          tooltip: 'Hapus pencarian',
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: staffList.isEmpty
                    ? Center(
                        child: Text(
                          'Staff tidak ditemukan.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: staffList.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final staff = staffList[index];
                          final selected = staff.id == widget.selectedStaff?.id;

                          return _StaffSearchResultTile(
                            staff: staff,
                            selected: selected,
                            onTap: () => Navigator.of(context).pop(staff),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffSearchResultTile extends StatelessWidget {
  const _StaffSearchResultTile({
    required this.staff,
    required this.selected,
    required this.onTap,
  });

  final LeaveStaffOption staff;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.gold.withValues(alpha: 0.10)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: selected
                    ? AppColors.goldDeep
                    : AppColors.surfaceAlt,
                child: Text(
                  _staffInitials(staff.name),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? Colors.white : AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _StaffDropdownLabel(staff: staff)),
              const SizedBox(width: 8),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.goldDeep,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffDropdownLabel extends StatelessWidget {
  const _StaffDropdownLabel({required this.staff, this.compact = false});

  final LeaveStaffOption staff;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = staff.subtitle.trim();

    if (compact || subtitle.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          staff.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: textTheme.bodyLarge?.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            staff.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveFormAlert extends StatelessWidget {
  const _LeaveFormAlert({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.34)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: AppColors.red,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pengajuan belum bisa dikirim',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.inkMuted,
            visualDensity: VisualDensity.compact,
            tooltip: 'Tutup pesan',
          ),
        ],
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
          ),
          child: Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDays(num days) {
  if (days % 1 == 0) {
    return '${days.toInt()}';
  }
  return NumberFormat.decimalPattern('id_ID').format(days);
}

String _formatFullDate(DateTime date) {
  return DateFormat('EEEE, d MMM yyyy', 'id_ID').format(date);
}

String _formatShortDate(DateTime date) {
  return DateFormat('d MMM', 'id_ID').format(date);
}

String _formatMonthYear(DateTime date) {
  return DateFormat('MMMM yyyy', 'id_ID').format(date);
}

String _staffInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return '?';
  }

  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

String _formatDateRange(DateTime start, DateTime end) {
  if (_dateOnly(start) == _dateOnly(end)) {
    return DateFormat('d MMM yyyy', 'id_ID').format(start);
  }

  if (start.year == end.year && start.month == end.month) {
    return '${DateFormat('d', 'id_ID').format(start)}-${DateFormat('d MMM yyyy', 'id_ID').format(end)}';
  }

  return '${DateFormat('d MMM', 'id_ID').format(start)} - ${DateFormat('d MMM yyyy', 'id_ID').format(end)}';
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String _dateKey(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(_dateOnly(date));
}

bool _sameMonth(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month;
}

bool _isSameDay(DateTime a, DateTime b) {
  return _dateOnly(a) == _dateOnly(b);
}

List<DateTime?> _calendarDaysFor(DateTime month) {
  final firstDay = DateTime(month.year, month.month);
  final totalDays = DateTime(month.year, month.month + 1, 0).day;
  final leadingBlanks = firstDay.weekday - 1;
  final cells = <DateTime?>[
    for (var index = 0; index < leadingBlanks; index++) null,
    for (var day = 1; day <= totalDays; day++)
      DateTime(month.year, month.month, day),
  ];

  while (cells.length % 7 != 0) {
    cells.add(null);
  }

  return cells;
}

Map<String, List<_CalendarDayEntry>> _buildCalendarEntries({
  required List<LeaveCalendarEvent> events,
  required List<LeaveHolidayItem> holidays,
}) {
  final entries = <String, List<_CalendarDayEntry>>{};
  final fingerprints = <String>{};

  void addEntry(_CalendarDayEntry entry) {
    final key = _dateKey(entry.date);
    final fingerprint = '$key|${entry.kind}|${entry.title}';
    if (!fingerprints.add(fingerprint)) {
      return;
    }

    entries.putIfAbsent(key, () => <_CalendarDayEntry>[]).add(entry);
  }

  for (final holiday in holidays) {
    addEntry(
      _CalendarDayEntry(
        date: holiday.date,
        title: holiday.name,
        kind: holiday.isJointLeave ? 'joint_leave' : 'holiday',
        color: holiday.isJointLeave ? AppColors.blue : AppColors.red,
        isHoliday: true,
      ),
    );
  }

  final holidayDateKeys = holidays
      .map((holiday) => _dateKey(holiday.date))
      .toSet();

  for (final event in events) {
    final isLeaveEvent =
        event.kind == 'leave_approved' || event.kind == 'leave_pending';
    final isWeekend =
        event.date.weekday == DateTime.saturday ||
        event.date.weekday == DateTime.sunday;
    if (isLeaveEvent &&
        (isWeekend || holidayDateKeys.contains(_dateKey(event.date)))) {
      continue;
    }

    final fallbackColor = _colorFromHex(
      event.color,
      fallback: AppColors.goldDeep,
    );
    final isHoliday = event.kind == 'holiday' || event.kind == 'joint_leave';
    final color = switch (event.kind) {
      'holiday' => AppColors.red,
      'joint_leave' => AppColors.blue,
      _ => fallbackColor,
    };

    addEntry(
      _CalendarDayEntry(
        date: event.date,
        title: event.title,
        kind: event.kind,
        color: color,
        isHoliday: isHoliday,
      ),
    );
  }

  for (final dayEntries in entries.values) {
    dayEntries.sort((a, b) {
      if (a.isHoliday != b.isHoliday) {
        return a.isHoliday ? -1 : 1;
      }

      return a.title.compareTo(b.title);
    });
  }

  return entries;
}

Color _statusColor(String status) {
  return switch (status) {
    'approved' => AppColors.green,
    'rejected' => AppColors.red,
    'cancelled' => AppColors.inkMuted,
    _ => AppColors.amber,
  };
}

Color _approvalStepColor(String status) {
  return switch (status) {
    'approved' => AppColors.green,
    'rejected' => AppColors.red,
    'skipped' => AppColors.inkMuted,
    'pending' => AppColors.amber,
    _ => AppColors.borderStrong,
  };
}

IconData _approvalStepIcon(String status) {
  return switch (status) {
    'approved' => Icons.check_rounded,
    'rejected' => Icons.close_rounded,
    'skipped' => Icons.remove_rounded,
    'pending' => Icons.edit_rounded,
    _ => Icons.schedule_rounded,
  };
}

String _approvalStepLabel(String status) {
  return switch (status) {
    'approved' => 'Selesai',
    'rejected' => 'Ditolak',
    'skipped' => 'Dilewati',
    'pending' => 'Aktif',
    _ => 'Menunggu',
  };
}

IconData _eventIcon(String kind) {
  return switch (kind) {
    'leave_approved' => Icons.beach_access_rounded,
    'leave_pending' => Icons.schedule_rounded,
    'joint_leave' => Icons.groups_rounded,
    _ => Icons.flag_rounded,
  };
}

String _eventLabel(String kind) {
  return switch (kind) {
    'leave_approved' => 'Cuti',
    'leave_pending' => 'Pending',
    'joint_leave' => 'Bersama',
    _ => 'Libur',
  };
}

Color _colorFromHex(String value, {required Color fallback}) {
  final normalized = value.replaceAll('#', '').trim();
  if (normalized.length != 6) {
    return fallback;
  }

  final parsed = int.tryParse('FF$normalized', radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
