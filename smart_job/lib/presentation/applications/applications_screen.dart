import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  String? _selectedApplicationId;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartJobControllerProvider);
    final stats = ref.watch(applicationStatsProvider);
    final applications = state.applications;
    final total = applications.length;

    final selectedApplication = applications.isEmpty
        ? null
        : applications.firstWhere(
            (application) =>
                application.id == (_selectedApplicationId ?? applications.first.id),
            orElse: () => applications.first,
          );

    return SmartJobScrollPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SmartJobPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SmartJobHeroLabel(label: 'Application tracker'),
                const SizedBox(height: 14),
                Text(
                  'Keep every application stage readable at a glance.',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Counts, timeline status, recruiter notes, and inbox updates stay linked inside SmartJob.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.subtext(Theme.of(context).brightness),
                      ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SmartJobMetricPill(label: 'total', value: '$total'),
                    SmartJobMetricPill(
                      label: 'interviews',
                      value: '${stats[ApplicationStatus.interview] ?? 0}',
                    ),
                    SmartJobMetricPill(
                      label: 'accepted',
                      value: '${stats[ApplicationStatus.accepted] ?? 0}',
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fade().slideY(begin: 0.04),
          const SizedBox(height: 18),
          if (applications.isEmpty)
            const SmartJobEmptyState(
              icon: Icons.inbox_outlined,
              title: 'No applications yet',
              message:
                  'Apply to a few roles from the Home tab and SmartJob will start building your timeline here.',
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final tiles = [
                  SmartJobProgressPill(
                    value: stats[ApplicationStatus.pending] ?? 0,
                    total: total,
                    label: 'Pending',
                    color: applicationStatusColor(ApplicationStatus.pending),
                  ),
                  SmartJobProgressPill(
                    value: stats[ApplicationStatus.interview] ?? 0,
                    total: total,
                    label: 'Interview',
                    color: applicationStatusColor(ApplicationStatus.interview),
                  ),
                  SmartJobProgressPill(
                    value: stats[ApplicationStatus.accepted] ?? 0,
                    total: total,
                    label: 'Accepted',
                    color: applicationStatusColor(ApplicationStatus.accepted),
                  ),
                ];

                if (constraints.maxWidth >= 920) {
                  return Row(
                    children: [
                      for (var index = 0; index < tiles.length; index++) ...[
                        Expanded(child: tiles[index]),
                        if (index < tiles.length - 1) const SizedBox(width: 12),
                      ],
                    ],
                  );
                }

                return Column(
                  children: [
                    for (var index = 0; index < tiles.length; index++) ...[
                      tiles[index],
                      if (index < tiles.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            if (selectedApplication != null)
              SmartJobPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SmartJobAvatar(label: selectedApplication.logoLabel, size: 52),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedApplication.role,
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${selectedApplication.company} / ${selectedApplication.appliedLabel}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.subtext(
                                        Theme.of(context).brightness,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        _StatusChip(status: selectedApplication.status),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      selectedApplication.note,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    for (final event in selectedApplication.timeline) ...[
                      _TimelineRow(event: event),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ).animate().fade(delay: 160.ms),
            const SizedBox(height: 22),
            const SmartJobSectionHeader(
              title: 'Application history',
              subtitle: 'All tracked applications with live status labels.',
            ),
            const SizedBox(height: 12),
            for (final application in applications) ...[
              GestureDetector(
                onTap: () => setState(() => _selectedApplicationId = application.id),
                child: SmartJobPanel(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      SmartJobAvatar(label: application.logoLabel),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              application.role,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${application.company} / ${application.location}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.subtext(
                                      Theme.of(context).brightness,
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              application.appliedLabel,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _StatusChip(status: application.status),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final color = applicationStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        applicationStatusLabel(status),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event});

  final ApplicationTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final color = event.isComplete ? AppColors.teal : AppColors.warning;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            Container(
              width: 2,
              height: 46,
              color: AppColors.stroke(Theme.of(context).brightness),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.label, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 4),
              Text(
                event.caption,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.subtext(Theme.of(context).brightness),
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(event.dateLabel, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
