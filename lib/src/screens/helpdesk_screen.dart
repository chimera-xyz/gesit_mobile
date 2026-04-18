import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/app_models.dart';
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
          ticket.ticketId.toLowerCase().contains(query) ||
          ticket.assignee.toLowerCase().contains(query) ||
          ticket.category.toLowerCase().contains(query);
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
                  hintText: 'Cari ticket, ID, kategori, atau PIC',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    children: [
                      for (final label in const [
                        'Semua',
                        'Open Queue',
                        'In Progress',
                        'Critical',
                      ]) ...[
                        FilterPill(
                          label: label,
                          selected: _selectedFilter == label,
                          onTap: () => setState(() => _selectedFilter = label),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (filteredTickets.isEmpty)
                  BrandSurface(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'Belum ada ticket yang cocok dengan pencarian atau filter ini.',
                      style: textTheme.bodyMedium,
                    ),
                  )
                else
                  for (
                    var index = 0;
                    index < filteredTickets.length;
                    index++
                  ) ...[
                    RevealUp(
                      index: index + 1,
                      child: _HelpdeskTicketCard(
                        ticket: filteredTickets[index],
                      ),
                    ),
                    if (index != filteredTickets.length - 1)
                      const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HelpdeskTicketCard extends StatelessWidget {
  const _HelpdeskTicketCard({required this.ticket});

  final HelpdeskTicket ticket;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return BrandSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      color: _priorityColor(ticket.priorityLabel),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ticket.ticketId,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppColors.goldDeep,
                  ),
                ],
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _TicketMetaPill(
                icon: Icons.account_tree_rounded,
                text: ticket.category,
              ),
              _TicketMetaPill(
                icon: Icons.person_rounded,
                text: ticket.assignee,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MetaLine(icon: Icons.schedule_rounded, text: ticket.updatedLabel),
        ],
      ),
    );
  }
}

class _TicketMetaPill extends StatelessWidget {
  const _TicketMetaPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.inkMuted),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ),
        ],
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

Color _priorityColor(String priorityLabel) {
  switch (priorityLabel) {
    case 'Critical':
      return AppColors.red;
    case 'Medium':
      return AppColors.amber;
    case 'Normal':
      return AppColors.blue;
    default:
      return AppColors.goldDeep;
  }
}
