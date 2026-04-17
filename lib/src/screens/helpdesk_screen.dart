import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';

class HelpdeskScreen extends StatefulWidget {
  const HelpdeskScreen({super.key});

  @override
  State<HelpdeskScreen> createState() => _HelpdeskScreenState();
}

class _HelpdeskScreenState extends State<HelpdeskScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'Semua';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final query = _searchController.text.trim().toLowerCase();
    final filteredTickets = DemoData.helpdeskTickets.where((ticket) {
      final matchesFilter =
          _selectedFilter == 'Semua' ||
          ticket.statusLabel == _selectedFilter ||
          ticket.priorityLabel == _selectedFilter;
      final matchesQuery =
          query.isEmpty ||
          ticket.title.toLowerCase().contains(query) ||
          ticket.ticketId.toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GesitBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RevealUp(
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          side: const BorderSide(color: AppColors.border),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Helpdesk',
                          style: textTheme.headlineMedium,
                        ),
                      ),
                      FilledButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'UI ticket baru siap untuk tahap API.',
                              ),
                            ),
                          );
                        },
                        child: const Text('New'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AppSearchField(
                  controller: _searchController,
                  hintText: 'Cari ticket atau ID',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final label in [
                      'Semua',
                      'Open Queue',
                      'In Progress',
                      'Critical',
                    ])
                      FilterPill(
                        label: label,
                        selected: _selectedFilter == label,
                        onTap: () => setState(() => _selectedFilter = label),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                ...filteredTickets.asMap().entries.map((entry) {
                  final index = entry.key;
                  final ticket = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: RevealUp(
                      index: index + 1,
                      child: BrandSurface(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      StatusChip(
                                        label: ticket.statusLabel,
                                        color: ticket.accentColor,
                                      ),
                                      StatusChip(
                                        label: ticket.priorityLabel,
                                        color: AppColors.amber,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  ticket.ticketId,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.inkMuted,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(ticket.title, style: textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Text(
                              ticket.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _MetaLine(
                                    icon: Icons.account_tree_rounded,
                                    text: ticket.category,
                                  ),
                                ),
                                Expanded(
                                  child: _MetaLine(
                                    icon: Icons.person_rounded,
                                    text: ticket.assignee,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _MetaLine(
                                    icon: Icons.schedule_rounded,
                                    text: ticket.updatedLabel,
                                  ),
                                ),
                                const Spacer(),
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
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(icon, size: 16, color: AppColors.inkMuted),
          ),
          const TextSpan(text: '  '),
          TextSpan(text: text),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
    );
  }
}
