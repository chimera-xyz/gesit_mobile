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
  TaskLane _selectedLane = TaskLane.approvals;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final filteredTasks = DemoData.tasks
        .where((task) => task.lane == _selectedLane)
        .toList();

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, kBottomBarInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RevealUp(child: Text('Tasks', style: textTheme.headlineMedium)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilterPill(
                label: 'Approvals',
                selected: _selectedLane == TaskLane.approvals,
                onTap: () => setState(() => _selectedLane = TaskLane.approvals),
              ),
              FilterPill(
                label: 'Updates',
                selected: _selectedLane == TaskLane.notifications,
                onTap: () =>
                    setState(() => _selectedLane = TaskLane.notifications),
              ),
              FilterPill(
                label: 'Ongoing',
                selected: _selectedLane == TaskLane.ongoing,
                onTap: () => setState(() => _selectedLane = TaskLane.ongoing),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (var index = 0; index < filteredTasks.length; index++) ...[
            RevealUp(
              index: index + 1,
              child: BrandSurface(
                onTap: () => widget.onOpenTask(filteredTasks[index]),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusChip(
                          label: filteredTasks[index].statusLabel,
                          color: filteredTasks[index].accentColor,
                        ),
                        const SizedBox(width: 12),
                        const Spacer(),
                        Text(
                          filteredTasks[index].timeLabel,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      filteredTasks[index].title,
                      style: textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      filteredTasks[index].summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          filteredTasks[index].requester,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        if (filteredTasks[index].requiresSignature)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.draw_rounded,
                              size: 18,
                              color: AppColors.red,
                            ),
                          ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: AppColors.goldDeep,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (index != filteredTasks.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
