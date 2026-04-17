import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import 'knowledge_assistant_screen.dart';

class KnowledgeHubScreen extends StatefulWidget {
  const KnowledgeHubScreen({super.key});

  @override
  State<KnowledgeHubScreen> createState() => _KnowledgeHubScreenState();
}

class _KnowledgeHubScreenState extends State<KnowledgeHubScreen> {
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
    final filters = <String>{
      'Semua',
      ...DemoData.knowledgeItems.map((item) => item.category),
    }.toList();
    final query = _searchController.text.trim().toLowerCase();
    final filteredItems = DemoData.knowledgeItems.where((item) {
      final matchesFilter =
          _selectedFilter == 'Semua' || item.category == _selectedFilter;
      final matchesQuery =
          query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.space.toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    }).toList();
    final pinnedItems = filteredItems.where((item) => item.isPinned).toList();
    final otherItems = filteredItems.where((item) => !item.isPinned).toList();

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
                          'Knowledge Hub',
                          style: textTheme.headlineMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AppSearchField(
                  controller: _searchController,
                  hintText: 'Cari SOP, panduan, atau FAQ',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    children: [
                      for (final filter in filters) ...[
                        FilterPill(
                          label: filter,
                          selected: _selectedFilter == filter,
                          onTap: () => setState(() => _selectedFilter = filter),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Access', style: textTheme.titleLarge),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: RevealUp(
                        index: 1,
                        child: SizedBox(
                          height: 138,
                          child: _KnowledgeAccessCard(
                            shortcut: DemoData.knowledgeShortcuts[0],
                            onTap: () => pushBrandedRoute(
                              context,
                              const KnowledgeAssistantScreen(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RevealUp(
                        index: 2,
                        child: SizedBox(
                          height: 138,
                          child: _KnowledgeAccessCard(
                            shortcut: DemoData.knowledgeShortcuts[1],
                            onTap: () => _showShortcutMessage(
                              'UI document explorer Knowledge siap untuk tahap berikutnya.',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (pinnedItems.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Pinned', style: textTheme.titleLarge),
                  const SizedBox(height: 10),
                  ...pinnedItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RevealUp(
                        index: index + 3,
                        child: _KnowledgeRow(
                          item: item,
                          onTap: () => _showItemMessage(item.title),
                        ),
                      ),
                    );
                  }),
                ],
                if (filteredItems.isEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Knowledge', style: textTheme.titleLarge),
                  const SizedBox(height: 10),
                  BrandSurface(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'Tidak ada item yang cocok dengan pencarian.',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ] else if (otherItems.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Documents', style: textTheme.titleLarge),
                  const SizedBox(height: 10),
                  ...otherItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RevealUp(
                        index: index + 5,
                        child: _KnowledgeRow(
                          item: item,
                          onTap: () => _showItemMessage(item.title),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showShortcutMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showItemMessage(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Preview "$title" siap untuk tahap berikutnya.')),
    );
  }
}

class _KnowledgeAccessCard extends StatelessWidget {
  const _KnowledgeAccessCard({required this.shortcut, required this.onTap});

  final KnowledgeShortcut shortcut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return BrandSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: shortcut.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(shortcut.icon, color: shortcut.accentColor, size: 20),
          ),
          const Spacer(),
          Text(shortcut.title, style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            shortcut.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeRow extends StatelessWidget {
  const _KnowledgeRow({required this.item, required this.onTap});

  final KnowledgeItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return BrandSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_iconFor(item.category), color: item.accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.category} • ${item.space}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.updatedLabel,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
        ],
      ),
    );
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'SOP':
        return Icons.library_books_rounded;
      case 'Panduan':
        return Icons.menu_book_rounded;
      case 'FAQ':
        return Icons.help_outline_rounded;
      case 'AI':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.description_rounded;
    }
  }
}
