import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../application/controllers/smart_job_controller.dart';
import '../../domain/models/message.dart';
import '../../services/supabase_data_service.dart';
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
    final sourceMessages = state.messages;
    debugPrint('[Inbox] state.messages.length = ${sourceMessages.length}');
    final messages = _applyFilter(sourceMessages, state.selectedInboxFilter);
    debugPrint('[Inbox] filtered messages.length = ${messages.length} (filter: ${state.selectedInboxFilter})');
    final unreadCount =
        sourceMessages.where((message) => message.isUnread).length;

    final selectedMessage = messages.isNotEmpty
        ? messages.firstWhere(
            (m) => m.id == (_selectedMessageId ?? messages.first.id),
            orElse: () => messages.first,
          )
        : null;

    return SmartJobScrollPage(
      scrollViewKey: const PageStorageKey('inbox-scroll-v2'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header (compact) ──────────────────────────────────
          SmartJobPanel(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inbox',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sourceMessages.isEmpty
                            ? 'No messages yet'
                            : '${sourceMessages.length} messages · $unreadCount unread',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.subtext(Theme.of(context).brightness),
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.midnight, AppColors.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    LucideIcons.mailCheck,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
          ).animate().fade().slideY(begin: 0.04),

          const SizedBox(height: 20),

          // ─── Filter chips ───────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _InboxFilterChip(
                  label: 'All',
                  count: sourceMessages.length,
                  selected: state.selectedInboxFilter == MessageFilter.all,
                  onTap: () => ref
                      .read(smartJobControllerProvider.notifier)
                      .setInboxFilter(MessageFilter.all),
                ),
                const SizedBox(width: 8),
                _InboxFilterChip(
                  label: 'Unread',
                  count: unreadCount,
                  selected: state.selectedInboxFilter == MessageFilter.unread,
                  onTap: () => ref
                      .read(smartJobControllerProvider.notifier)
                      .setInboxFilter(MessageFilter.unread),
                  highlightColor: AppColors.coral,
                ),
                const SizedBox(width: 8),
                _InboxFilterChip(
                  label: 'Interviews',
                  count: sourceMessages
                      .where((m) => m.type == MessageType.interview)
                      .length,
                  selected:
                      state.selectedInboxFilter == MessageFilter.interviews,
                  onTap: () => ref
                      .read(smartJobControllerProvider.notifier)
                      .setInboxFilter(MessageFilter.interviews),
                  highlightColor: AppColors.info,
                ),
                const SizedBox(width: 8),
                _InboxFilterChip(
                  label: 'Important',
                  count:
                      sourceMessages.where((m) => m.isImportant).length,
                  selected:
                      state.selectedInboxFilter == MessageFilter.important,
                  onTap: () => ref
                      .read(smartJobControllerProvider.notifier)
                      .setInboxFilter(MessageFilter.important),
                  highlightColor: AppColors.sand,
                ),
              ],
            ),
          ).animate().fade(delay: 80.ms),

          const SizedBox(height: 20),

          // ─── Message preview pane ───────────────────────────────
          if (selectedMessage != null && messages.isNotEmpty)
            _MessageDetailCard(message: selectedMessage)
                .animate()
                .fade(delay: 100.ms),

          if (selectedMessage != null && messages.isNotEmpty)
            const SizedBox(height: 20),

          // ─── Message list ───────────────────────────────────────
          SmartJobSectionHeader(
            title: 'Messages',
            subtitle: messages.isEmpty
                ? 'No messages in this filter.'
                : '${messages.length} ${messages.length == 1 ? 'message' : 'messages'}${unreadCount > 0 ? ' · $unreadCount unread' : ''}',
          ),
          const SizedBox(height: 14),
          if (messages.isEmpty)
            SmartJobEmptyState(
              icon: LucideIcons.mailX,
              title: 'No messages here',
              message:
                  'Apply to roles and share your SmartJob email with companies. Recruiter replies will appear here.',
            )
          else
            for (final message in messages) ...[
              _MessageTile(
                message: message,
                isSelected: message.id ==
                    (_selectedMessageId ?? messages.first.id),
                onTap: () {
                  setState(() => _selectedMessageId = message.id);
                  ref
                      .read(smartJobControllerProvider.notifier)
                      .markMessageRead(message.id);
                  unawaited(SupabaseDataService.markMessageRead(message.id));
                },
              ).animate().fade(delay: 120.ms).slideY(begin: 0.02),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  List<InboxMessage> _applyFilter(
    List<InboxMessage> messages,
    MessageFilter filter,
  ) {
    switch (filter) {
      case MessageFilter.all:
        return messages;
      case MessageFilter.important:
        return messages.where((m) => m.isImportant).toList();
      case MessageFilter.unread:
        return messages.where((m) => m.isUnread).toList();
      case MessageFilter.interviews:
        return messages.where((m) => m.type == MessageType.interview).toList();
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// Message Detail Card
// ─────────────────────────────────────────────────────────────────

class _MessageDetailCard extends StatelessWidget {
  const _MessageDetailCard({required this.message});

  final InboxMessage message;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final typeColor = messageTypeColor(message.type);

    return SmartJobPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SmartJobAvatar(
                label: message.senderCompany.isNotEmpty
                    ? message.senderCompany.substring(
                        0,
                        message.senderCompany.length >= 2 ? 2 : 1,
                      ).toUpperCase()
                    : 'SJ',
                size: 52,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.subject,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${message.senderName} · ${message.senderCompany}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.subtext(brightness),
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border:
                          Border.all(color: typeColor.withValues(alpha: 0.28)),
                    ),
                    child: Text(
                      messageTypeLabel(message.type),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: typeColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message.timeLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.subtext(brightness),
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Text(
            message.body,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Message Tile
// ─────────────────────────────────────────────────────────────────

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.message,
    required this.isSelected,
    required this.onTap,
  });

  final InboxMessage message;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final typeColor = messageTypeColor(message.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.midnight.withValues(alpha: 0.06)
                : AppColors.surface(brightness).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? AppColors.midnight.withValues(alpha: 0.3)
                  : AppColors.stroke(brightness),
            ),
            boxShadow: isSelected
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: brightness == Brightness.dark ? 0.16 : 0.04,
                      ),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SmartJobAvatar(
                    label: message.senderName.isNotEmpty
                        ? message.senderName
                            .substring(
                              0,
                              message.senderName.length >= 2 ? 2 : 1,
                            )
                            .toUpperCase()
                        : 'SJ',
                    size: 46,
                  ),
                  if (message.isUnread)
                    Positioned(
                      top: -3,
                      right: -3,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: message.isUnread
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          message.timeLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.subtext(brightness),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${message.senderCompany} · ${message.senderName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.teal,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            messageTypeLabel(message.type),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: typeColor,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.subtext(brightness),
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

// ─────────────────────────────────────────────────────────────────
// Filter Chip
// ─────────────────────────────────────────────────────────────────

class _InboxFilterChip extends StatelessWidget {
  const _InboxFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.highlightColor,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final activeColor = highlightColor ?? AppColors.midnight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? activeColor : AppColors.surface(brightness),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? activeColor : AppColors.stroke(brightness),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected
                          ? Colors.white
                          : AppColors.text(brightness),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : AppColors.surfaceMuted(brightness),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected
                            ? Colors.white
                            : AppColors.subtext(brightness),
                        fontWeight: FontWeight.w700,
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
