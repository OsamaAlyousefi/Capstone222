import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../domain/models/job.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/smart_job_ui.dart';

class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.job,
    required this.onOpenDetails,
    required this.onApply,
    required this.onSaveToggle,
    required this.onSwipeSave,
    required this.onSwipeDismiss,
  });

  final Job job;
  final VoidCallback onOpenDetails;
  final VoidCallback onApply;
  final VoidCallback onSaveToggle;
  final VoidCallback onSwipeSave;
  final VoidCallback onSwipeDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 320) {
          onSwipeSave();
        } else if (velocity < -320) {
          onSwipeDismiss();
        }
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpenDetails,
          borderRadius: BorderRadius.circular(26),
          child: SmartJobPanel(
            padding: const EdgeInsets.all(16),
            radius: 26,
            child: _JobCardContent(
              job: job,
              onOpenDetails: onOpenDetails,
              onApply: onApply,
              onSaveToggle: onSaveToggle,
            ),
          ),
        ),
      ),
    );
  }
}

class _JobCardContent extends StatelessWidget {
  const _JobCardContent({
    required this.job,
    required this.onOpenDetails,
    required this.onApply,
    required this.onSaveToggle,
  });

  final Job job;
  final VoidCallback onOpenDetails;
  final VoidCallback onApply;
  final VoidCallback onSaveToggle;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;
    final matchColor = jobMatchColor(job.matchScore);
    final matchPercentage = (job.matchScore * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CompactMatchStrip(
          matchPercentage: matchPercentage,
          matchLabel: jobMatchLabel(job.matchScore),
          color: matchColor,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'job-logo-${job.id}',
              child: SmartJobAvatar(label: job.logoLabel, size: 52),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.headlineMedium?.copyWith(height: 1.15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${job.companyName} / ${job.source}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.subtext(brightness),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    job.postedLabel,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.subtext(brightness),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _AnimatedSaveButton(
              isSaved: job.isSaved,
              onTap: onSaveToggle,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(icon: LucideIcons.mapPin, label: job.location),
            _InfoChip(icon: LucideIcons.banknote, label: job.salary),
            _InfoChip(icon: LucideIcons.briefcase, label: jobTypeLabel(job.jobType)),
            _InfoChip(icon: LucideIcons.wifi, label: workModeLabel(job.workMode)),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          job.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.text(brightness).withValues(alpha: 0.88),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final skill in job.skills.take(4)) _SkillTag(label: skill),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Swipe right to save or left for not interested',
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.subtext(brightness),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onOpenDetails,
                child: const Text('Read more'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: job.hasEasyApply ? onApply : null,
                child: const Text('Easy apply'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactMatchStrip extends StatelessWidget {
  const _CompactMatchStrip({
    required this.matchPercentage,
    required this.matchLabel,
    required this.color,
  });

  final int matchPercentage;
  final String matchLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted(brightness).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.stroke(brightness)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$matchPercentage%',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontSize: 8.5,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Match',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontSize: 8.5,
                    color: AppColors.subtext(brightness),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MatchProgressBar(
              value: matchPercentage / 100,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            matchLabel,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchProgressBar extends StatelessWidget {
  const _MatchProgressBar({
    required this.value,
    required this.color,
  });

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final fillWidth = (trackWidth * value.clamp(0.0, 1.0)).toDouble();

        return Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.surface(brightness),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: fillWidth,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [
                    AppColors.midnight.withValues(alpha: 0.68),
                    color,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedSaveButton extends StatelessWidget {
  const _AnimatedSaveButton({
    required this.isSaved,
    required this.onTap,
  });

  final bool isSaved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AnimatedScale(
      scale: isSaved ? 1.06 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSaved
                ? AppColors.midnight
                : AppColors.surfaceMuted(brightness),
            borderRadius: BorderRadius.circular(16),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              key: ValueKey(isSaved),
              size: 20,
              color: isSaved ? Colors.white : AppColors.subtext(brightness),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted(brightness).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
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

class _SkillTag extends StatelessWidget {
  const _SkillTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.stroke(brightness)),
        color: AppColors.surface(brightness).withValues(alpha: 0.82),
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
