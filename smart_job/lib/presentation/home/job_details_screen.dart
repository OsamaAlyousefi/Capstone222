import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/controllers/smart_job_controller.dart';
import '../../domain/models/job.dart';
import '../../services/job_match_service.dart';
import '../../services/supabase_data_service.dart';
import '../../theme/app_colors.dart';
import '../shared/widgets/smart_job_ui.dart';

class JobDetailsScreen extends ConsumerWidget {
  const JobDetailsScreen({
    super.key,
    required this.jobId,
  });

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final state = ref.watch(smartJobControllerProvider);
    final maybeJob = _findJob(state.jobs, jobId);

    if (maybeJob == null) {
      return Scaffold(
        backgroundColor: AppColors.canvas(brightness),
        body: SmartJobBackground(
          child: Center(
            child: SmartJobPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Job not found',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This role may have been removed from the feed.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.subtext(brightness),
                        ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to jobs'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final job = maybeJob;
    final profile = state.profile;
    final applied = state.applications.any((application) => application.jobId == job.id);
    final matchedSkills = _matchedSkills(profile.skills, job.skills);
    final suggestedSkills = _suggestedSkills(
      profile.skills,
      job.skills,
      profile.cvInsight.missingKeywords,
    );
    final similarJobs = _similarJobs(state.jobs, job, profile.skills);

    return Scaffold(
      backgroundColor: AppColors.canvas(brightness),
      bottomNavigationBar: _StickyActionBar(
        job: job,
        applied: applied,
        onSave: () {
          ref.read(smartJobControllerProvider.notifier).toggleSaveJob(job.id);
          final nextSaved = !job.isSaved;
          SupabaseDataService.saveJobInteraction(
            job.copyWith(isSaved: nextSaved),
            nextSaved ? 'saved' : 'viewed',
          );
          _showToast(
            context,
            job.isSaved ? 'Removed from saved jobs.' : 'Saved to your shortlist.',
          );
        },
        onApply: () async {
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
        },
        onShare: () => _showToast(context, 'Share link ready for ${job.title}.'),
      ),
      body: SmartJobBackground(
        child: CustomScrollView(
          key: PageStorageKey('job-details-scroll-$jobId'),
          slivers: [
            SliverAppBar(
              pinned: true,
              stretch: true,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              backgroundColor: AppColors.canvas(brightness).withValues(alpha: 0.92),
              expandedHeight: context.isCompact ? 400 : 358,
              leading: _TopBarButton(
                icon: LucideIcons.chevronLeft,
                onTap: () => Navigator.of(context).pop(),
              ),
              actions: [
                _TopBarButton(
                  icon: LucideIcons.share2,
                  onTap: () => _showToast(context, 'Share link ready for ${job.title}.'),
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.isCompact ? 16 : 24,
                    92,
                    context.isCompact ? 16 : 24,
                    20,
                  ),
                  child: _HeroHeaderCard(job: job),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                context.isCompact ? 16 : 24,
                0,
                context.isCompact ? 16 : 24,
                132,
              ),
              sliver: SliverList.list(
                children: [
                  _DetailsSection(
                    icon: LucideIcons.fileText,
                    title: 'About the role',
                    child: Text(
                      '${job.description} ${job.aiSummary}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailsSection(
                    icon: LucideIcons.listChecks,
                    title: 'Responsibilities',
                    child: _BulletList(items: _responsibilities(job)),
                  ),
                  const SizedBox(height: 16),
                  _DetailsSection(
                    icon: LucideIcons.badgeCheck,
                    title: 'Requirements',
                    child: _BulletList(items: _requirements(job, suggestedSkills)),
                  ),
                  if (JobMatchService.hasProfileData(profile)) ...[
                    const SizedBox(height: 16),
                    _MatchBreakdownSection(
                      result: JobMatchService.calculate(profile, job),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _DetailsSection(
                    icon: LucideIcons.sparkles,
                    title: 'Skills match',
                    child: _SkillsMatchBlock(
                      matchedSkills: matchedSkills,
                      suggestedSkills: suggestedSkills,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailsSection(
                    icon: LucideIcons.building2,
                    title: 'Company info',
                    child: Text(
                      _companySummary(job),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailsSection(
                    icon: LucideIcons.briefcase,
                    title: 'Similar jobs',
                    child: SizedBox(
                      height: 214,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: similarJobs.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final similarJob = similarJobs[index];
                          return _SimilarJobCard(
                            job: similarJob,
                            onTap: () => Navigator.of(context).push(
                              _jobDetailsRoute(similarJob.id),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Job? _findJob(List<Job> jobs, String id) {
    for (final job in jobs) {
      if (job.id == id) {
        return job;
      }
    }
    return null;
  }

  List<String> _matchedSkills(List<String> profileSkills, List<String> jobSkills) {
    final profileLookup = {
      for (final skill in profileSkills) skill.toLowerCase(): skill,
    };

    return [
      for (final skill in jobSkills)
        if (profileLookup.containsKey(skill.toLowerCase())) skill,
    ];
  }

  List<String> _suggestedSkills(
    List<String> profileSkills,
    List<String> jobSkills,
    List<String> profileSuggestions,
  ) {
    final normalizedProfile = profileSkills.map((skill) => skill.toLowerCase()).toSet();
    final suggestions = <String>[];

    for (final skill in [...jobSkills, ...profileSuggestions]) {
      final normalized = skill.toLowerCase();
      if (normalizedProfile.contains(normalized) || suggestions.contains(skill)) {
        continue;
      }
      suggestions.add(skill);
    }

    return suggestions.take(3).toList();
  }

  List<String> _responsibilities(Job job) {
    return [
      'Own polished ${job.title.toLowerCase()} work from concept through shipped output.',
      'Collaborate with design, product, and recruiting stakeholders in a ${workModeLabel(job.workMode).toLowerCase()} workflow.',
      'Use ${job.skills.take(2).join(' and ')} to raise quality, speed, and consistency across the product.',
    ];
  }

  List<String> _requirements(Job job, List<String> suggestedSkills) {
    return [
      '${experienceLevelLabel(job.experienceLevel)}-level confidence across ${job.skills.join(', ')}.',
      'Comfort with ${jobTypeLabel(job.jobType).toLowerCase()} expectations and ${workModeLabel(job.workMode).toLowerCase()} collaboration.',
      if (suggestedSkills.isNotEmpty)
        'Nice to have: ${suggestedSkills.join(', ')}.',
    ];
  }

  String _companySummary(Job job) {
    final tagLine = job.tags.take(2).join(' and ');
    return '${job.companyName} is hiring through ${job.source} for a ${jobTypeLabel(job.jobType).toLowerCase()} role based in ${job.location}. The team appears focused on $tagLine, with strong emphasis on ${job.skills.take(2).join(' and ')}.';
  }

  List<Job> _similarJobs(List<Job> jobs, Job currentJob, List<String> profileSkills) {
    final currentSkills = currentJob.skills.map((skill) => skill.toLowerCase()).toSet();
    final profileLookup = profileSkills.map((skill) => skill.toLowerCase()).toSet();
    final candidates = jobs.where((job) => job.id != currentJob.id).toList();

    candidates.sort((a, b) {
      double scoreFor(Job job) {
        final overlap = job.skills
            .where((skill) => currentSkills.contains(skill.toLowerCase()))
            .length;
        final profileBoost = job.skills
            .where((skill) => profileLookup.contains(skill.toLowerCase()))
            .length;
        final modeBoost = job.workMode == currentJob.workMode ? 0.04 : 0.0;
        return job.matchScore + (overlap * 0.05) + (profileBoost * 0.03) + modeBoost;
      }

      return scoreFor(b).compareTo(scoreFor(a));
    });

    return candidates.take(4).toList();
  }

  Route<void> _jobDetailsRoute(String jobId) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) =>
          JobDetailsScreen(jobId: jobId),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(
          begin: const Offset(0.12, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        return SlideTransition(
          position: slide,
          child: FadeTransition(opacity: animation, child: child),
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

class _HeroHeaderCard extends StatelessWidget {
  const _HeroHeaderCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    return SmartJobPanel(
      padding: const EdgeInsets.all(22),
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(icon: LucideIcons.clock3, label: job.postedLabel),
              _HeroPill(icon: LucideIcons.badgeInfo, label: job.source),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(height: 1.1),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      job.companyName,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.location,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.subtext(Theme.of(context).brightness),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Hero(
                tag: 'job-logo-${job.id}',
                child: SmartJobAvatar(label: job.logoLabel, size: 68),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetaChip(icon: LucideIcons.banknote, label: job.salary),
              _MetaChip(icon: LucideIcons.briefcase, label: jobTypeLabel(job.jobType)),
              _MetaChip(icon: LucideIcons.wifi, label: workModeLabel(job.workMode)),
              _MetaChip(
                icon: LucideIcons.barChart3,
                label: experienceLevelLabel(job.experienceLevel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SmartJobPanel(
      padding: const EdgeInsets.all(20),
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: AppColors.teal, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Column(
      children: [
        for (final item in items) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.sand,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.text(brightness).withValues(alpha: 0.9),
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SkillsMatchBlock extends StatelessWidget {
  const _SkillsMatchBlock({
    required this.matchedSkills,
    required this.suggestedSkills,
  });

  final List<String> matchedSkills;
  final List<String> suggestedSkills;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Matched', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final skill in matchedSkills)
              _SkillPill(label: skill, color: AppColors.success),
          ],
        ),
        const SizedBox(height: 18),
        Text('Suggested to add', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final skill in suggestedSkills)
              _SkillPill(label: skill, color: AppColors.warning),
          ],
        ),
      ],
    );
  }
}

class _SkillPill extends StatelessWidget {
  const _SkillPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}

class _SimilarJobCard extends StatelessWidget {
  const _SimilarJobCard({
    required this.job,
    required this.onTap,
  });

  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return SizedBox(
      width: 252,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: SmartJobPanel(
            padding: const EdgeInsets.all(18),
            radius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SmartJobAvatar(label: job.logoLabel, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        job.companyName,
                        style: Theme.of(context).textTheme.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  job.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  '${job.location} / ${workModeLabel(job.workMode)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.subtext(brightness),
                      ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      job.source,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.teal,
                          ),
                    ),
                    const Spacer(),
                    const Icon(LucideIcons.arrowRight, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StickyActionBar extends StatelessWidget {
  const _StickyActionBar({
    required this.job,
    required this.applied,
    required this.onSave,
    required this.onApply,
    required this.onShare,
  });

  final Job job;
  final bool applied;
  final VoidCallback onSave;
  final VoidCallback onApply;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SmartJobPanel(
          padding: const EdgeInsets.all(12),
          radius: 24,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSave,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(
                      job.isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      key: ValueKey(job.isSaved),
                      size: 18,
                    ),
                  ),
                  label: Text(job.isSaved ? 'Saved' : 'Save job'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: applied ? null : onApply,
                  icon: Icon(
                    applied
                        ? LucideIcons.badgeCheck
                        : job.applyUrl.isNotEmpty
                            ? LucideIcons.externalLink
                            : LucideIcons.send,
                    size: 18,
                  ),
                  label: Text(
                    applied
                        ? 'Applied'
                        : job.applyUrl.isNotEmpty
                            ? 'Apply on ${job.source}'
                            : 'Easy apply',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 50,
                height: 50,
                child: OutlinedButton(
                  onPressed: onShare,
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Icon(LucideIcons.share2, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBarButton extends StatelessWidget {
  const _TopBarButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: AppColors.surface(brightness).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 18),
          ),
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted(brightness),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.teal),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surfaceMuted(brightness),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.teal),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.text(brightness),
                ),
          ),
        ],
      ),
    );
  }
}

class _MatchBreakdownSection extends StatelessWidget {
  const _MatchBreakdownSection({required this.result});
  final JobMatchResult result;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    if (!result.shouldShow) return const SizedBox.shrink();

    return SmartJobPanel(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: result.percentage / 100,
                      strokeWidth: 4,
                      backgroundColor: AppColors.stroke(brightness),
                      valueColor: AlwaysStoppedAnimation(result.color),
                    ),
                    Text(
                      '${result.percentage}%',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: result.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.label,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: result.color,
                      ),
                    ),
                    Text(
                      'Based on your CV and profile data',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.subtext(brightness),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _BreakdownRow(
            label: 'Skills',
            detail: result.matchedSkills.isEmpty
                ? 'No overlap'
                : '${result.matchedSkills.length} matched',
            value: result.skillsScore,
            color: result.color,
            brightness: brightness,
          ),
          const SizedBox(height: 10),
          _BreakdownRow(
            label: 'Title',
            detail: result.titleScore >= 0.6
                ? 'Strong overlap'
                : result.titleScore >= 0.3
                    ? 'Some overlap'
                    : 'Low overlap',
            value: result.titleScore,
            color: result.color,
            brightness: brightness,
          ),
          const SizedBox(height: 10),
          _BreakdownRow(
            label: 'Location',
            detail: result.locationScore >= 0.9
                ? 'Exact match'
                : result.locationScore >= 0.6
                    ? 'Good match'
                    : 'Partial',
            value: result.locationScore,
            color: result.color,
            brightness: brightness,
          ),
          const SizedBox(height: 10),
          _BreakdownRow(
            label: 'Experience',
            detail: result.experienceScore >= 0.9
                ? 'Great fit'
                : result.experienceScore >= 0.5
                    ? 'Good fit'
                    : 'Gap',
            value: result.experienceScore,
            color: result.color,
            brightness: brightness,
          ),
          if (result.matchedSkills.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Matched skills',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.matchedSkills.map((s) => _MatchChip(
                label: s,
                color: AppColors.success,
                brightness: brightness,
              )).toList(),
            ),
          ],
          if (result.missingSkills.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Consider adding these skills',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.subtext(brightness),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.missingSkills.take(6).map((s) => _MatchChip(
                label: s,
                color: AppColors.subtext(brightness),
                brightness: brightness,
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.detail,
    required this.value,
    required this.color,
    required this.brightness,
  });

  final String label;
  final String detail;
  final double value;
  final Color color;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.stroke(brightness),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(
            detail,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.subtext(brightness),
            ),
          ),
        ),
      ],
    );
  }
}

class _MatchChip extends StatelessWidget {
  const _MatchChip({
    required this.label,
    required this.color,
    required this.brightness,
  });

  final String label;
  final Color color;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

