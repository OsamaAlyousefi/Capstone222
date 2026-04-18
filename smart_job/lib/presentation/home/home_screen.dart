import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/controllers/smart_job_controller.dart';
import '../../router/app_router.dart';
import '../../domain/models/job.dart';
import '../../services/job_match_service.dart';
import '../../services/job_summary_service.dart';
import '../../services/supabase_data_service.dart';
import '../../theme/app_colors.dart';
import '../shared/widgets/smart_job_ui.dart';
import 'job_details_screen.dart';
import 'widgets/job_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasSearched = false;
  bool _isLoadingJobs = false;
  bool _isLoadingSlow = false;
  bool _sortByMatch = true; // true = Best Match, false = Most Recent

  @override
  void initState() {
    super.initState();
    // Fetch real jobs from APIs on first load.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasSearched) {
        _hasSearched = true;
        _fetchJobs();
      }
    });
  }

  Future<void> _fetchJobs() async {
    if (!mounted) return;
    setState(() {
      _isLoadingJobs = true;
      _isLoadingSlow = false;
    });

    // Show extra message after 10 seconds.
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoadingJobs) {
        setState(() => _isLoadingSlow = true);
      }
    });

    try {
      await ref.read(smartJobControllerProvider.notifier).searchExternalJobs();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingJobs = false;
          _isLoadingSlow = false;
        });
      }
    }

    // Auto-summarize first 5 jobs in the background after list is shown.
    final jobs = ref.read(filteredJobsProvider);
    if (jobs.isNotEmpty) {
      JobSummaryService.summarizeInBackground(jobs);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final state = ref.watch(smartJobControllerProvider);
    final profile = state.profile;
    final filteredJobs = ref.watch(filteredJobsProvider);
    final savedJobs = ref.watch(savedJobsProvider);

    final jobsFeed = [...filteredJobs];
    if (_sortByMatch) {
      jobsFeed.sort((a, b) {
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
    }
    // "Most Recent" keeps the API order (newest first by default).

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
                            'Find jobs that match your skills.',
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
          if (state.isGlobalFallback && jobsFeed.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.globe, size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Showing international job opportunities. For UAE-specific jobs, try searching \'jobs\' with location \'Dubai\'.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.warning,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (_isLoadingJobs && jobsFeed.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Finding jobs for you...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.subtext(Theme.of(context).brightness),
                          ),
                    ),
                    if (_isLoadingSlow) ...[
                      const SizedBox(height: 8),
                      Text(
                        'This may take a moment...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.subtext(Theme.of(context).brightness),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else if (jobsFeed.isEmpty)
            SmartJobEmptyState(
              icon: LucideIcons.searchX,
              title: 'No jobs found',
              message:
                  'Try different keywords or check your connection.',
              action: OutlinedButton.icon(
                onPressed: _fetchJobs,
                icon: const Icon(LucideIcons.rotateCcw, size: 16),
                label: const Text('Retry'),
              ),
            )
          else ...[
            if (!JobMatchService.hasProfileData(profile))
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.go(AppRoute.cv),
                    borderRadius: BorderRadius.circular(18),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: AppColors.info.withValues(alpha: 0.10),
                        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.sparkles, size: 18, color: AppColors.info),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Complete your CV to see how well you match each job',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.info,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(LucideIcons.chevronRight, size: 16, color: AppColors.info),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // ── Sort toggle ──
            Row(
              children: [
                Text(
                  '${jobsFeed.length} jobs',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.subtext(Theme.of(context).brightness),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _SortToggle(
                  sortByMatch: _sortByMatch,
                  onChanged: (v) => setState(() => _sortByMatch = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final job in jobsFeed) ...[
              JobCard(
                job: job,
                matchResult: JobMatchService.hasProfileData(profile)
                    ? JobMatchService.calculate(profile, job)
                    : null,
                onOpenDetails: () => _openJobDetails(context, job.id),
                onApply: () => _applyForJob(context, ref, job),
                onSaveToggle: () => _toggleSaveJob(context, ref, job),
                onSwipeSave: () => _saveFromSwipe(context, ref, job),
                onSwipeDismiss: () => _markNotInterested(context, ref, job),
              ).animate().fade(delay: 160.ms).slideY(begin: 0.03),
              const SizedBox(height: 14),
            ],
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
    // External jobs — open URL in browser and track.
    if (job.applyUrl.isNotEmpty) {
      final uri = Uri.tryParse(job.applyUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!context.mounted) return;
      ref.read(smartJobControllerProvider.notifier).easyApply(job);
      _showToast(context, 'Opening ${job.source} to apply.');
      return;
    }

    // Internal Easy Apply.
    try {
      final created = await SupabaseDataService.applyToJob(job);
      if (!context.mounted) return;
      ref.read(smartJobControllerProvider.notifier).easyApply(job);
      _showToast(
        context,
        created
            ? 'Application sent to ${job.companyName}.'
            : 'You already applied to ${job.companyName}.',
      );
    } catch (error) {
      if (!context.mounted) return;
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

class _SortToggle extends StatelessWidget {
  const _SortToggle({
    required this.sortByMatch,
    required this.onChanged,
  });

  final bool sortByMatch;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted(brightness),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.stroke(brightness)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SortOption(
            label: 'Best Match',
            icon: LucideIcons.sparkles,
            selected: sortByMatch,
            onTap: () => onChanged(true),
          ),
          _SortOption(
            label: 'Most Recent',
            icon: LucideIcons.clock,
            selected: !sortByMatch,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.midnight : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? Colors.white : AppColors.subtext(brightness),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? Colors.white : AppColors.subtext(brightness),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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
