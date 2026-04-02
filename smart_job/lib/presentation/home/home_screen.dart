import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../application/controllers/smart_job_controller.dart';
import '../../domain/models/job.dart';
import '../../theme/app_colors.dart';
import '../shared/widgets/smart_job_ui.dart';
import 'widgets/job_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(smartJobControllerProvider);
    final profile = state.profile;
    final filteredJobs = ref.watch(filteredJobsProvider);
    final savedJobs = ref.watch(savedJobsProvider);

    final interestedCount = state.jobs
        .where((job) => job.feedback == JobFeedback.interested)
        .length;
    final notInterestedCount = state.jobs
        .where((job) => job.feedback == JobFeedback.notInterested)
        .length;

    final locationOptions = const [
      'All locations',
      'Remote',
      'Dubai',
      'Abu Dhabi',
    ];
    final nextLocation = locationOptions[
      (locationOptions.indexOf(state.selectedLocation) + 1) % locationOptions.length
    ];

    final jobsFeed = [...filteredJobs]
      ..sort((a, b) {
        final aScore = a.matchScore +
            (a.isSaved ? 0.08 : 0) +
            (a.feedback == JobFeedback.interested ? 0.12 : 0) -
            (a.feedback == JobFeedback.notInterested ? 0.12 : 0);
        final bScore = b.matchScore +
            (b.isSaved ? 0.08 : 0) +
            (b.feedback == JobFeedback.interested ? 0.12 : 0) -
            (b.feedback == JobFeedback.notInterested ? 0.12 : 0);
        return bScore.compareTo(aScore);
      });

    return SmartJobScrollPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SmartJobPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, ${profile.firstName}',
                            style: Theme.of(context).textTheme.displayMedium,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Everything is now in one stream. Search, filter, and scroll through each matching job below.',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppColors.subtext(Theme.of(context).brightness),
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SmartJobAvatar(label: profile.photoLabel, size: 58),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SmartJobMetricPill(
                      label: 'jobs',
                      value: '${jobsFeed.length}',
                      icon: LucideIcons.briefcase,
                    ),
                    SmartJobMetricPill(
                      label: 'saved',
                      value: '${savedJobs.length}',
                      icon: LucideIcons.bookmark,
                    ),
                    SmartJobMetricPill(
                      label: 'interested',
                      value: '$interestedCount',
                      icon: LucideIcons.trendingUp,
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fade().slideY(begin: 0.04),
          const SizedBox(height: 18),
          TextField(
            onChanged: ref.read(smartJobControllerProvider.notifier).setSearchQuery,
            decoration: const InputDecoration(
              hintText: 'Search roles, companies, or skills',
              prefixIcon: Icon(LucideIcons.search),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SmartJobFilterChip(
                label: state.selectedLocation,
                icon: LucideIcons.mapPin,
                selected: state.selectedLocation != 'All locations',
                onTap: () {
                  ref
                      .read(smartJobControllerProvider.notifier)
                      .setLocationFilter(nextLocation);
                },
              ),
              SmartJobFilterChip(
                label: state.selectedSalaryRange,
                icon: LucideIcons.banknote,
                selected: state.selectedSalaryRange != 'Any salary',
                onTap: () {
                  final ranges = [
                    'Any salary',
                    '\$3k',
                    '\$4k',
                    '\$35',
                  ];
                  final currentIndex = ranges.indexOf(state.selectedSalaryRange);
                  final nextIndex = (currentIndex + 1) % ranges.length;
                  ref
                      .read(smartJobControllerProvider.notifier)
                      .setSalaryRange(ranges[nextIndex]);
                },
              ),
              SmartJobFilterChip(
                label: 'Remote',
                selected: state.selectedWorkMode == WorkMode.remote,
                onTap: () => ref
                    .read(smartJobControllerProvider.notifier)
                    .toggleWorkMode(WorkMode.remote),
              ),
              SmartJobFilterChip(
                label: 'Hybrid',
                selected: state.selectedWorkMode == WorkMode.hybrid,
                onTap: () => ref
                    .read(smartJobControllerProvider.notifier)
                    .toggleWorkMode(WorkMode.hybrid),
              ),
              SmartJobFilterChip(
                label: 'Full time',
                selected: state.selectedJobType == JobType.fullTime,
                onTap: () => ref
                    .read(smartJobControllerProvider.notifier)
                    .toggleJobType(JobType.fullTime),
              ),
              SmartJobFilterChip(
                label: 'Contract',
                selected: state.selectedJobType == JobType.contract,
                onTap: () => ref
                    .read(smartJobControllerProvider.notifier)
                    .toggleJobType(JobType.contract),
              ),
            ],
          ).animate().fade(delay: 120.ms),
          const SizedBox(height: 20),
          SmartJobPanel(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommendation tuning',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Interested feedback boosts similar roles. Not-for-me feedback quietly reduces matching weight in your next feed refresh.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.subtext(Theme.of(context).brightness),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  children: [
                    SmartJobMetricPill(
                      label: 'like',
                      value: '$interestedCount',
                      icon: LucideIcons.badgeCheck,
                    ),
                    const SizedBox(height: 10),
                    SmartJobMetricPill(
                      label: 'skip',
                      value: '$notInterestedCount',
                      icon: LucideIcons.circleOff,
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fade(delay: 150.ms),
          const SizedBox(height: 24),
          const SmartJobSectionHeader(
            title: 'Jobs feed',
            subtitle: 'Every matching role is stacked here in one list.',
          ),
          const SizedBox(height: 14),
          if (jobsFeed.isEmpty)
            SmartJobEmptyState(
              icon: LucideIcons.searchX,
              title: 'No jobs match these filters',
              message:
                  'Try widening your location or work mode filters to reveal more roles.',
              action: OutlinedButton(
                onPressed: () {
                  ref
                      .read(smartJobControllerProvider.notifier)
                      .setLocationFilter('All locations');
                },
                child: const Text('Reset location'),
              ),
            )
          else
            for (final job in jobsFeed) ...[
              JobCard(
                job: job,
                onReadMore: () => _showJobDetails(context, ref, job),
                onApply: () => _applyForJob(context, ref, job),
                onSaveToggle: () => ref
                    .read(smartJobControllerProvider.notifier)
                    .toggleSaveJob(job.id),
                onFeedback: (feedback) => ref
                    .read(smartJobControllerProvider.notifier)
                    .setJobFeedback(job.id, feedback),
              ).animate().fade(delay: 180.ms),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }

  void _applyForJob(BuildContext context, WidgetRef ref, Job job) {
    ref.read(smartJobControllerProvider.notifier).easyApply(job);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied to ${job.companyName} via Easy Apply.')),
    );
  }

  void _showJobDetails(BuildContext context, WidgetRef ref, Job job) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SmartJobPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SmartJobSectionHeader(
                  title: job.title,
                  subtitle: '${job.companyName} / ${job.source}',
                  trailing: SmartJobAvatar(label: job.logoLabel),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SmartJobMetricPill(
                      label: 'salary',
                      value: job.salary,
                      icon: LucideIcons.banknote,
                    ),
                    SmartJobMetricPill(
                      label: 'mode',
                      value: workModeLabel(job.workMode),
                      icon: LucideIcons.mapPin,
                    ),
                    SmartJobMetricPill(
                      label: 'level',
                      value: experienceLevelLabel(job.experienceLevel),
                      icon: LucideIcons.barChart3,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(job.description, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final skill in job.skills) Chip(label: Text(skill)),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          ref
                              .read(smartJobControllerProvider.notifier)
                              .toggleSaveJob(job.id);
                        },
                        child: Text(job.isSaved ? 'Unsave' : 'Save'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _applyForJob(context, ref, job);
                        },
                        child: const Text('Easy apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
