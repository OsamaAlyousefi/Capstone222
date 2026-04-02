import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../application/controllers/smart_job_controller.dart';
import '../../domain/models/message.dart';
import '../../theme/app_colors.dart';
import '../shared/widgets/smart_job_ui.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  String? _selectedMessageId;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartJobControllerProvider);
    final messages = ref.watch(inboxMessagesProvider);
    final unreadCount = state.messages.where((message) => message.isUnread).length;

    final selectedMessage = messages.isNotEmpty
        ? messages.firstWhere(
            (message) => message.id == (_selectedMessageId ?? messages.first.id),
            orElse: () => messages.first,
          )
        : null;

    return SmartJobScrollPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SmartJobPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SmartJobHeroLabel(label: 'Recruiter inbox'),
                const SizedBox(height: 14),
                Text(
                  'A focused mail hub for every hiring update.',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Your SmartJob identity keeps interview invites, rejection letters, and follow-ups aligned with application history.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.subtext(Theme.of(context).brightness),
                      ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SmartJobMetricPill(
                      label: 'identity',
                      value: state.profile.smartInboxAlias,
                      icon: LucideIcons.atSign,
                    ),
                    SmartJobMetricPill(
                      label: 'unread',
                      value: '$unreadCount',
                      icon: LucideIcons.mailOpen,
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fade().slideY(begin: 0.04),
          const SizedBox(height: 18),
          const SmartJobSectionHeader(
            title: 'Filters',
            subtitle: 'Switch between all updates, unread messages, and interview-heavy traffic.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InboxFilterChip(
                label: 'All',
                selected: state.selectedInboxFilter == MessageFilter.all,
                onTap: () => ref
                    .read(smartJobControllerProvider.notifier)
                    .setInboxFilter(MessageFilter.all),
              ),
              _InboxFilterChip(
                label: 'Important',
                selected: state.selectedInboxFilter == MessageFilter.important,
                onTap: () => ref
                    .read(smartJobControllerProvider.notifier)
                    .setInboxFilter(MessageFilter.important),
              ),
              _InboxFilterChip(
                label: 'Unread',
                selected: state.selectedInboxFilter == MessageFilter.unread,
                onTap: () => ref
                    .read(smartJobControllerProvider.notifier)
                    .setInboxFilter(MessageFilter.unread),
              ),
              _InboxFilterChip(
                label: 'Interviews',
                selected: state.selectedInboxFilter == MessageFilter.interviews,
                onTap: () => ref
                    .read(smartJobControllerProvider.notifier)
                    .setInboxFilter(MessageFilter.interviews),
              ),
            ],
          ).animate().fade(delay: 80.ms),
          const SizedBox(height: 18),
          if (selectedMessage != null)
            SmartJobPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SmartJobAvatar(
                        label: selectedMessage.senderCompany.substring(0, 2).toUpperCase(),
                        size: 48,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedMessage.subject,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${selectedMessage.senderName} / ${selectedMessage.senderCompany}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.subtext(
                                      Theme.of(context).brightness,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: messageTypeColor(selectedMessage.type).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          messageTypeLabel(selectedMessage.type),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: messageTypeColor(selectedMessage.type),
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(selectedMessage.body, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ).animate().fade(delay: 120.ms),
          const SizedBox(height: 18),
          const SmartJobSectionHeader(
            title: 'Messages',
            subtitle: 'Tap a message to preview it and mark it as read.',
          ),
          const SizedBox(height: 12),
          if (messages.isEmpty)
            const SmartJobEmptyState(
              icon: LucideIcons.mailX,
              title: 'No messages in this filter',
              message: 'Try switching the inbox filter to reveal more recruiter activity.',
            )
          else
            for (final message in messages) ...[
              GestureDetector(
                onTap: () {
                  setState(() => _selectedMessageId = message.id);
                  ref
                      .read(smartJobControllerProvider.notifier)
                      .markMessageRead(message.id);
                },
                child: SmartJobPanel(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          SmartJobAvatar(
                            label: message.senderName.substring(0, 2).toUpperCase(),
                            size: 48,
                          ),
                          if (message.isUnread)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: AppColors.coral,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    message.subject,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: message.isUnread
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  message.timeLabel,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${message.senderCompany} / ${message.senderName}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.subtext(
                                      Theme.of(context).brightness,
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              message.preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _InboxFilterChip extends StatelessWidget {
  const _InboxFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SmartJobFilterChip(
      label: label,
      selected: selected,
      onTap: onTap,
    );
  }
}
