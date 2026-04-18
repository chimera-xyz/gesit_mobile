import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, required this.onOpenTask});

  final ValueChanged<TaskItem> onOpenTask;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TextEditingController _searchController = TextEditingController();
  TaskLane _selectedLane = TaskLane.approvals;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final query = _searchController.text.trim().toLowerCase();
    final filteredTasks = DemoData.tasks.where((task) {
      final matchesLane = task.lane == _selectedLane;
      final matchesQuery =
          query.isEmpty ||
          task.title.toLowerCase().contains(query) ||
          task.requester.toLowerCase().contains(query) ||
          task.summary.toLowerCase().contains(query) ||
          task.statusLabel.toLowerCase().contains(query);
      return matchesLane && matchesQuery;
    }).toList();

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, kBottomBarInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RevealUp(child: Text('Tasks', style: textTheme.headlineMedium)),
          const SizedBox(height: 14),
          AppSearchField(
            controller: _searchController,
            hintText: 'Cari task, requester, atau status',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Row(
              children: [
                for (final lane in const [
                  (label: 'Approvals', value: TaskLane.approvals),
                  (label: 'Updates', value: TaskLane.notifications),
                  (label: 'Ongoing', value: TaskLane.ongoing),
                ]) ...[
                  FilterPill(
                    label: lane.label,
                    selected: _selectedLane == lane.value,
                    onTap: () => setState(() => _selectedLane = lane.value),
                  ),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (filteredTasks.isEmpty)
            BrandSurface(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Belum ada task yang cocok dengan pencarian atau filter ini.',
                style: textTheme.bodyMedium,
              ),
            )
          else
            for (var index = 0; index < filteredTasks.length; index++) ...[
              RevealUp(
                index: index + 1,
                child: _TaskListCard(
                  task: filteredTasks[index],
                  onTap: () => widget.onOpenTask(filteredTasks[index]),
                ),
              ),
              if (index != filteredTasks.length - 1) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _TaskListCard extends StatelessWidget {
  const _TaskListCard({required this.task, required this.onTap});

  final TaskItem task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return BrandSurface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusChip(label: task.statusLabel, color: task.accentColor),
              const SizedBox(width: 12),
              const Spacer(),
              Text(
                task.timeLabel,
                style: textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _RequesterAvatar(name: task.requester),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${task.requester} • ${task.priorityLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (task.requiresSignature)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.draw_rounded,
                    size: 18,
                    color: AppColors.red,
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.goldDeep,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RequesterAvatar extends StatelessWidget {
  const _RequesterAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = _buildInitials(name);

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  String _buildInitials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '--';
    }

    if (parts.length == 1) {
      final token = parts.first;
      return token
          .substring(0, token.length >= 2 ? 2 : token.length)
          .toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
