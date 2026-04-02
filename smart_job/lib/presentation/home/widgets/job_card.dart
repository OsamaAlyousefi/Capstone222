import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../domain/models/job.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/smart_job_ui.dart';

class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.job,
    required this.onReadMore,
    required this.onApply,
    required this.onSaveToggle,
    required this.onFeedback,
    this.featured = false,
  });

  final Job job;
  final VoidCallback onReadMore;
  final VoidCallback onApply;
  final VoidCallback onSaveToggle;
  final ValueChanged<JobFeedback> onFeedback;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;

    return SmartJobPanel(
      margin: EdgeInsets.only(right: featured ? 14 : 0),
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: featured ? 320 : null,
        child: featured
            ? SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: _JobCardContent(
                  job: job,
                  featured: featured,
                  brightness: brightness,
                  textTheme: textTheme,
                  onReadMore: onReadMore,
                  onApply: onApply,
                  onSaveToggle: onSaveToggle,
                  onFeedback: onFeedback,
                ),
              )
            : _JobCardContent(
                job: job,
                featured: featured,
                brightness: brightness,
                textTheme: textTheme,
                onReadMore: onReadMore,
                onApply: onApply,
                onSaveToggle: onSaveToggle,
                onFeedback: onFeedback,
              ),
      ),
    );
  }
}

class _JobCardContent extends StatelessWidget {
  const _JobCardContent({
    required this.job,
    required this.featured,
    required this.brightness,
    required this.textTheme,
    required this.onReadMore,
    required this.onApply,
    required this.onSaveToggle,
    required this.onFeedback,
  });

  final Job job;
  final bool featured;
  final Brightness brightness;
  final TextTheme textTheme;
  final VoidCallback onReadMore;
  final VoidCallback onApply;
  final VoidCallback onSaveToggle;
  final ValueChanged<JobFeedback> onFeedback;

  @override
  Widget build(BuildContext context) {
    final matchColor = jobMatchColor(job.matchScore);
    final matchPercentage = (job.matchScore * 100).round();
    final matchLabel = jobMatchLabel(job.matchScore);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SmartJobAvatar(label: job.logoLabel, size: 50),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    maxLines: featured ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${job.companyName} / ${job.source}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.subtext(brightness),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onSaveToggle,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                LucideIcons.bookmark,
                size: 20,
                color: job.isSaved
                    ? AppColors.midnight
                    : AppColors.subtext(brightness),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _MatchBanner(
          matchPercentage: matchPercentage,
          matchLabel: matchLabel,
          color: matchColor,
          brightness: brightness,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MiniTag(icon: LucideIcons.mapPin, label: job.location),
            _MiniTag(icon: LucideIcons.banknote, label: job.salary),
            _MiniTag(icon: LucideIcons.briefcase, label: jobTypeLabel(job.jobType)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted(brightness),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.sparkles, size: 16, color: AppColors.sand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  job.aiSummary,
                  maxLines: featured ? 4 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in job.tags.take(2)) _MiniTag(icon: LucideIcons.tag, label: tag),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onReadMore,
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
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _FeedbackButton(
                icon: LucideIcons.badgeCheck,
                label: 'Interested',
                selected: job.feedback == JobFeedback.interested,
                onTap: () => onFeedback(JobFeedback.interested),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FeedbackButton(
                icon: LucideIcons.circleOff,
                label: 'Not for me',
                selected: job.feedback == JobFeedback.notInterested,
                onTap: () => onFeedback(JobFeedback.notInterested),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MatchBanner extends StatelessWidget {
  const _MatchBanner({
    required this.matchPercentage,
    required this.matchLabel,
    required this.color,
    required this.brightness,
  });

  final int matchPercentage;
  final String matchLabel;
  final Color color;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: brightness == Brightness.dark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              '$matchPercentage%',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Job match',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.subtext(brightness),
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  matchLabel,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: color,
                      ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: matchPercentage / 100,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceMuted(brightness),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(16),
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

class _FeedbackButton extends StatefulWidget {
  const _FeedbackButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FeedbackButton> createState() => _FeedbackButtonState();
}

class _FeedbackButtonState extends State<_FeedbackButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: widget.selected
                  ? AppColors.midnight
                  : _hovered
                      ? AppColors.surface(brightness)
                      : AppColors.surfaceMuted(brightness),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  size: 16,
                  color: widget.selected ? Colors.white : AppColors.subtext(brightness),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: widget.selected ? Colors.white : AppColors.text(brightness),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
