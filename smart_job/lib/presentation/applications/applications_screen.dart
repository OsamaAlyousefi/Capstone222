import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../application/controllers/smart_job_controller.dart';
import '../../domain/models/application.dart';
import '../../theme/app_colors.dart';
import '../shared/widgets/smart_job_ui.dart';

class ApplicationsScreen extends ConsumerStatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  ConsumerState<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends ConsumerState<ApplicationsScreen> {
  ApplicationStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartJobControllerProvider);
    final allApps = state.applications;

    final counts = {
      for (final s in ApplicationStatus.values)
        s: allApps.where((a) => a.status == s).length,
    };
    final filtered = _statusFilter == null
        ? allApps
        : allApps.where((a) => a.status == _statusFilter).toList();
    final total = allApps.length;

    return SmartJobScrollPage(
      scrollViewKey: const PageStorageKey('applications-scroll-v2'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header ───────────────────────────────────────────
          SmartJobPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Applications',
                            style: Theme.of(context).textTheme.displayMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Track every stage of your job search in one place.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.subtext(
                                    Theme.of(context).brightness,
                                  ),
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
                        LucideIcons.barChart3,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final statItems = [
                      _StatData(
                        value: '$total',
                        label: 'Total',
                        color: AppColors.midnight,
                      ),
                      _StatData(
                        value: '${counts[ApplicationStatus.interview] ?? 0}',
                        label: 'Interviews',
                        color: AppColors.info,
                      ),
                      _StatData(
                        value: '${counts[ApplicationStatus.accepted] ?? 0}',
                        label: 'Accepted',
                        color: AppColors.success,
                      ),
                      _StatData(
                        value: '${counts[ApplicationStatus.rejected] ?? 0}',
                        label: 'Rejected',
                        color: AppColors.danger,
                      ),
                    ];

                    if (constraints.maxWidth >= 720) {
                      return Row(
                        children: [
                          for (var i = 0; i < statItems.length; i++) ...[
                            Expanded(child: _StatCard(data: statItems[i])),
                            if (i < statItems.length - 1)
                              const SizedBox(width: 12),
                          ],
                        ],
                      );
                    }

                    return GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.8,
                      children: statItems.map((d) => _StatCard(data: d)).toList(),
                    );
                  },
                ),
              ],
            ),
          ).animate().fade().slideY(begin: 0.04),

          const SizedBox(height: 20),

          // ─── Status Filter Tabs ────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterTab(
                  label: 'All',
                  count: total,
                  selected: _statusFilter == null,
                  onTap: () => setState(() => _statusFilter = null),
                ),
                const SizedBox(width: 8),
                _FilterTab(
                  label: 'Applied',
                  count: counts[ApplicationStatus.pending] ?? 0,
                  color: applicationStatusColor(ApplicationStatus.pending),
                  selected: _statusFilter == ApplicationStatus.pending,
                  onTap: () => setState(
                    () => _statusFilter = _statusFilter == ApplicationStatus.pending
                        ? null
                        : ApplicationStatus.pending,
                  ),
                ),
                const SizedBox(width: 8),
                _FilterTab(
                  label: 'Interview',
                  count: counts[ApplicationStatus.interview] ?? 0,
                  color: applicationStatusColor(ApplicationStatus.interview),
                  selected: _statusFilter == ApplicationStatus.interview,
                  onTap: () => setState(
                    () => _statusFilter = _statusFilter == ApplicationStatus.interview
                        ? null
                        : ApplicationStatus.interview,
                  ),
                ),
                const SizedBox(width: 8),
                _FilterTab(
                  label: 'Accepted',
                  count: counts[ApplicationStatus.accepted] ?? 0,
                  color: applicationStatusColor(ApplicationStatus.accepted),
                  selected: _statusFilter == ApplicationStatus.accepted,
                  onTap: () => setState(
                    () => _statusFilter = _statusFilter == ApplicationStatus.accepted
                        ? null
                        : ApplicationStatus.accepted,
                  ),
                ),
                const SizedBox(width: 8),
                _FilterTab(
                  label: 'Rejected',
                  count: counts[ApplicationStatus.rejected] ?? 0,
                  color: applicationStatusColor(ApplicationStatus.rejected),
                  selected: _statusFilter == ApplicationStatus.rejected,
                  onTap: () => setState(
                    () => _statusFilter = _statusFilter == ApplicationStatus.rejected
                        ? null
                        : ApplicationStatus.rejected,
                  ),
                ),
                const SizedBox(width: 8),
                _FilterTab(
                  label: 'Saved',
                  count: counts[ApplicationStatus.saved] ?? 0,
                  color: applicationStatusColor(ApplicationStatus.saved),
                  selected: _statusFilter == ApplicationStatus.saved,
                  onTap: () => setState(
                    () => _statusFilter = _statusFilter == ApplicationStatus.saved
                        ? null
                        : ApplicationStatus.saved,
                  ),
                ),
              ],
            ),
          ).animate().fade(delay: 80.ms),

          const SizedBox(height: 20),

          // ─── Application List ──────────────────────────────────
          if (allApps.isEmpty)
            SmartJobEmptyState(
              icon: LucideIcons.inbox,
              title: 'No applications yet',
              message:
                  'Apply to roles from the Home tab and SmartJob will track your full journey here.',
            )
          else if (filtered.isEmpty)
            SmartJobEmptyState(
              icon: LucideIcons.filterX,
              title: 'No ${_statusLabel(_statusFilter)} applications',
              message: 'Try a different filter or apply to more roles to fill this stage.',
              action: TextButton.icon(
                onPressed: () => setState(() => _statusFilter = null),
                icon: const Icon(LucideIcons.rotateCcw, size: 16),
                label: const Text('Show all'),
              ),
            )
          else ...[
            SmartJobSectionHeader(
              title: _statusFilter == null
                  ? 'All applications'
                  : '${_statusLabel(_statusFilter)} applications',
              subtitle:
                  '${filtered.length} ${filtered.length == 1 ? 'application' : 'applications'} in this view.',
            ),
            const SizedBox(height: 14),
            for (final application in filtered) ...[
              _ApplicationCard(
                application: application,
                onTap: () => _showDetailSheet(context, application),
              ).animate().fade(delay: 120.ms).slideY(begin: 0.02),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  String _statusLabel(ApplicationStatus? status) {
    if (status == null) return 'all';
    return applicationStatusLabel(status).toLowerCase();
  }

  void _showDetailSheet(BuildContext context, JobApplication application) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final brightness = Theme.of(sheetContext).brightness;
        return DraggableScrollableSheet(
          initialChildSize: 0.62,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface(brightness),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(
                  color: AppColors.stroke(brightness),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.subtext(brightness).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SmartJobAvatar(
                                label: application.logoLabel,
                                size: 56,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      application.role,
                                      style: Theme.of(context)
                                          .textTheme
                                          .displaySmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      application.company,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            color: AppColors.teal,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      application.location,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.subtext(brightness),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              _StatusBadge(status: application.status),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted(brightness),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.stroke(brightness),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.calendarClock,
                                  size: 16,
                                  color: AppColors.subtext(brightness),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    application.appliedLabel,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                                if (application.source.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.midnight
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      application.source,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.midnight,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (application.note.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              application.note,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.subtext(brightness),
                                  ),
                            ),
                          ],
                          if (application.timeline.isNotEmpty) ...[
                            const SizedBox(height: 22),
                            Text(
                              'Application timeline',
                              style:
                                  Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 16),
                            for (var i = 0;
                                i < application.timeline.length;
                                i++) ...[
                              _TimelineItem(
                                event: application.timeline[i],
                                isLast: i == application.timeline.length - 1,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// Components
// ─────────────────────────────────────────────────────────

class _StatData {
  const _StatData({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value;
  final String label;
  final Color color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatData data;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: data.color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            data.value,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: data.color,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            data.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.subtext(brightness),
                ),
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final activeColor = color ?? AppColors.midnight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? activeColor
                : AppColors.surface(brightness),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? activeColor
                  : AppColors.stroke(brightness),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
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

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.onTap,
  });

  final JobApplication application;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final statusColor = applicationStatusColor(application.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface(brightness).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.stroke(brightness)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: brightness == Brightness.dark ? 0.18 : 0.05,
                ),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              SmartJobAvatar(label: application.logoLabel, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            application.role,
                            style:
                                Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        _StatusBadge(status: application.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      application.company,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.teal,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.mapPin,
                          size: 12,
                          color: AppColors.subtext(brightness),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          application.location,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.subtext(brightness),
                              ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          LucideIcons.clock,
                          size: 12,
                          color: AppColors.subtext(brightness),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          application.appliedLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.subtext(brightness),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Progress dots for timeline
                    if (application.timeline.isNotEmpty)
                      _TimelineProgress(
                        events: application.timeline,
                        statusColor: statusColor,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.subtext(brightness),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineProgress extends StatelessWidget {
  const _TimelineProgress({
    required this.events,
    required this.statusColor,
  });

  final List<ApplicationTimelineEvent> events;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final completed = events.where((e) => e.isComplete).length;

    return Row(
      children: [
        for (var i = 0; i < events.length; i++) ...[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < completed
                  ? statusColor
                  : AppColors.stroke(brightness),
              border: Border.all(
                color: i < completed
                    ? statusColor
                    : AppColors.stroke(brightness),
              ),
            ),
          ),
          if (i < events.length - 1)
            Expanded(
              child: Container(
                height: 2,
                color: i < completed - 1
                    ? statusColor
                    : AppColors.stroke(brightness),
              ),
            ),
        ],
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final color = applicationStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        applicationStatusLabel(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.event,
    required this.isLast,
  });

  final ApplicationTimelineEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = event.isComplete ? AppColors.teal : AppColors.stroke(brightness);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: event.isComplete ? AppColors.teal : Colors.transparent,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: event.isComplete
                      ? const Icon(
                          Icons.check,
                          size: 8,
                          color: Colors.white,
                        )
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.stroke(brightness),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.label,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                      Text(
                        event.dateLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.subtext(brightness),
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.caption,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.subtext(brightness),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
