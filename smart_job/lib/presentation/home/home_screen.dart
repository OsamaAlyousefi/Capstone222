import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../application/controllers/smart_job_controller.dart';
import '../../domain/models/job.dart';
import '../../services/supabase_data_service.dart';
import '../../theme/app_colors.dart';
import '../shared/widgets/smart_job_ui.dart';
import 'job_details_screen.dart';
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

    final activeFilters = _activeFilters(state);

    return SmartJobScrollPage(
      scrollViewKey: PageStorageKey('home-feed-scroll-v3'),
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
                            'A cleaner browsing flow is ready. Swipe to triage, open any role as a full page, and keep the feed focused on the jobs that fit best.',
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
                    SmartJobMetricPill(
                      label: 'skip',
                      value: '$notInterestedCount',
                      icon: LucideIcons.circleOff,
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fade().slideY(begin: 0.04),
          const SizedBox(height: 20),
          if (context.isCompact) ...[
            TextField(
              onChanged: ref.read(smartJobControllerProvider.notifier).setSearchQuery,
              decoration: const InputDecoration(
                hintText: 'Search roles, companies, or skills',
                prefixIcon: Icon(LucideIcons.search),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showFeedFilters(context, ref),
                icon: const Icon(LucideIcons.slidersHorizontal, size: 18),
                label: const Text('Filters'),
              ),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged:
                        ref.read(smartJobControllerProvider.notifier).setSearchQuery,
                    decoration: const InputDecoration(
                      hintText: 'Search roles, companies, or skills',
                      prefixIcon: Icon(LucideIcons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 124,
                  child: OutlinedButton.icon(
                    onPressed: () => _showFeedFilters(context, ref),
                    icon: const Icon(LucideIcons.slidersHorizontal, size: 18),
                    label: const Text('Filters'),
                  ),
                ),
              ],
            ).animate().fade(delay: 80.ms),
          if (activeFilters.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in activeFilters) _ActiveFilterChip(label: filter),
                TextButton(
                  onPressed: ref.read(smartJobControllerProvider.notifier).resetJobFilters,
                  child: const Text('Clear all'),
                ),
              ],
            ).animate().fade(delay: 120.ms),
          ],
          const SizedBox(height: 22),
          SmartJobSectionHeader(
            title: 'Jobs feed',
            subtitle:
                'Swipe right to save, swipe left to hide, or open any card for the full role view.',
            trailing: SizedBox(
              width: 136,
              child: OutlinedButton.icon(
                onPressed: () => _showFeedFilters(context, ref),
                icon: const Icon(LucideIcons.listFilter, size: 16),
                label: const Text('Tune feed'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (jobsFeed.isEmpty)
            SmartJobEmptyState(
              icon: LucideIcons.searchX,
              title: 'No jobs found',
              message:
                  'Try widening your role, salary, or experience filters to bring more opportunities back into the feed.',
              action: OutlinedButton.icon(
                onPressed: ref.read(smartJobControllerProvider.notifier).resetJobFilters,
                icon: const Icon(LucideIcons.rotateCcw, size: 16),
                label: const Text('Reset filters'),
              ),
            )
          else
            for (final job in jobsFeed) ...[
              JobCard(
                job: job,
                onOpenDetails: () => _openJobDetails(context, job.id),
                onApply: () => _applyForJob(context, ref, job),
                onSaveToggle: () => _toggleSaveJob(context, ref, job),
                onSwipeSave: () => _saveFromSwipe(context, ref, job),
                onSwipeDismiss: () => _markNotInterested(context, ref, job),
              ).animate().fade(delay: 160.ms).slideY(begin: 0.03),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }

  List<String> _activeFilters(SmartJobState state) {
    return [
      if (state.searchQuery.isNotEmpty) 'Role: ${state.searchQuery}',
      if (state.selectedLocation != 'All locations')
        'Location: ${state.selectedLocation}',
      if (state.selectedSalaryRange != 'Any salary')
        'Salary: ${state.selectedSalaryRange}',
      if (state.selectedWorkMode != null)
        'Setup: ${workModeLabel(state.selectedWorkMode!)}',
      if (state.selectedExperienceLevel != null)
        'Level: ${experienceLevelLabel(state.selectedExperienceLevel!)}',
    ];
  }

  Future<void> _applyForJob(BuildContext context, WidgetRef ref, Job job) async {
    try {
      final created = await SupabaseDataService.applyToJob(job);
      if (!context.mounted) {
        return;
      }
      ref.read(smartJobControllerProvider.notifier).easyApply(job);
      _showToast(
        context,
        created
            ? 'Application sent to ${job.companyName}.'
            : 'You already applied to ${job.companyName}.',
      );
    } catch (error) {
      _showToast(context, 'Could not send application: $error');
    }
  }

  void _toggleSaveJob(BuildContext context, WidgetRef ref, Job job) {
    final nextSaved = !job.isSaved;
    ref.read(smartJobControllerProvider.notifier).toggleSaveJob(job.id);
    SupabaseDataService.saveJobInteraction(
      job.copyWith(isSaved: nextSaved),
      nextSaved ? 'saved' : 'viewed',
    );
  }

  void _saveFromSwipe(BuildContext context, WidgetRef ref, Job job) {
    ref.read(smartJobControllerProvider.notifier).setJobSaved(job.id, true);
    SupabaseDataService.saveJobInteraction(
      job.copyWith(isSaved: true),
      'saved',
    );
    _showToast(context, '${job.title} saved to your list.');
  }

  void _markNotInterested(BuildContext context, WidgetRef ref, Job job) {
    ref
        .read(smartJobControllerProvider.notifier)
        .setJobFeedback(job.id, JobFeedback.notInterested);
    SupabaseDataService.saveJobInteraction(
      job.copyWith(feedback: JobFeedback.notInterested),
      'not_interested',
    );
    _showToast(context, 'We will show fewer roles like ${job.title}.');
  }

  void _openJobDetails(BuildContext context, String jobId) {
    Navigator.of(context, rootNavigator: true).push(_jobDetailsRoute(jobId));
  }

  Route<void> _jobDetailsRoute(String jobId) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) =>
          JobDetailsScreen(jobId: jobId),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0.12, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(opacity: fadeAnimation, child: child),
        );
      },
    );
  }

  Future<void> _showFeedFilters(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(Theme.of(context).brightness),
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(smartJobControllerProvider);
            final controller = ref.read(smartJobControllerProvider.notifier);
            final roleOptions = [
              'All roles',
              ...{
                for (final role in state.profile.jobPreferences.targetRoles) role,
                for (final role in state.jobs.map((job) => job.title)) role,
              }.take(6),
            ];
            final locationOptions = const [
              'All locations',
              'Remote',
              'Dubai',
              'Abu Dhabi',
            ];
            final salaryOptions = const [
              'Any salary',
              '\$3k',
              '\$4k',
              '\$35',
            ];

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Filter jobs',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Refine the feed by role, salary, setup, and experience level.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.subtext(Theme.of(context).brightness),
                          ),
                    ),
                    const SizedBox(height: 20),
                    _FilterSection(
                      title: 'Role',
                      children: [
                        for (final role in roleOptions)
                          _FilterChoiceChip(
                            label: role,
                            selected: role == 'All roles'
                                ? state.searchQuery.isEmpty
                                : state.searchQuery == role,
                            onTap: () => controller.setSearchQuery(
                              role == 'All roles' ? '' : role,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FilterSection(
                      title: 'Salary',
                      children: [
                        for (final salary in salaryOptions)
                          _FilterChoiceChip(
                            label: salary,
                            selected: state.selectedSalaryRange == salary,
                            onTap: () => controller.setSalaryRange(salary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FilterSection(
                      title: 'Work setup',
                      children: [
                        _FilterChoiceChip(
                          label: 'All setups',
                          selected: state.selectedWorkMode == null,
                          onTap: () {
                            if (state.selectedWorkMode != null) {
                              controller.toggleWorkMode(state.selectedWorkMode!);
                            }
                          },
                        ),
                        for (final mode in WorkMode.values)
                          _FilterChoiceChip(
                            label: workModeLabel(mode),
                            selected: state.selectedWorkMode == mode,
                            onTap: () => controller.toggleWorkMode(mode),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FilterSection(
                      title: 'Experience level',
                      children: [
                        _FilterChoiceChip(
                          label: 'All levels',
                          selected: state.selectedExperienceLevel == null,
                          onTap: () {
                            if (state.selectedExperienceLevel != null) {
                              controller.toggleExperienceLevel(
                                state.selectedExperienceLevel!,
                              );
                            }
                          },
                        ),
                        for (final level in ExperienceLevel.values)
                          _FilterChoiceChip(
                            label: experienceLevelLabel(level),
                            selected: state.selectedExperienceLevel == level,
                            onTap: () => controller.toggleExperienceLevel(level),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FilterSection(
                      title: 'Location',
                      children: [
                        for (final location in locationOptions)
                          _FilterChoiceChip(
                            label: location,
                            selected: state.selectedLocation == location,
                            onTap: () => controller.setLocationFilter(location),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: controller.resetJobFilters,
                            child: const Text('Reset all'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Show jobs'),
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
      },
    );
  }

  void _showToast(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children,
        ),
      ],
    );
  }
}

class _FilterChoiceChip extends StatelessWidget {
  const _FilterChoiceChip({
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

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted(brightness),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.stroke(brightness)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.text(brightness),
            ),
      ),
    );
  }
}
