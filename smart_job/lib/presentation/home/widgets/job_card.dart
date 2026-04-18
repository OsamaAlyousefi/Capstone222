import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../domain/models/job.dart';
import '../../../services/job_summary_service.dart';
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

class _JobCardContent extends StatefulWidget {
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
  State<_JobCardContent> createState() => _JobCardContentState();
}

class _JobCardContentState extends State<_JobCardContent> {
  String? _aiSummary;

  @override
  void initState() {
    super.initState();
    _aiSummary = JobSummaryService.getCached(widget.job.id);
    if (_aiSummary == null) {
      JobSummaryService.summaryNotifier.addListener(_onSummaryUpdate);
    }
  }

  @override
  void dispose() {
    JobSummaryService.summaryNotifier.removeListener(_onSummaryUpdate);
    super.dispose();
  }

  void _onSummaryUpdate() {
    final cached = JobSummaryService.getCached(widget.job.id);
    if (cached != null && mounted) {
      setState(() => _aiSummary = cached);
      JobSummaryService.summaryNotifier.removeListener(_onSummaryUpdate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;
    final job = widget.job;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    job.source.isNotEmpty
                        ? '${job.companyName} / via ${job.source}'
                        : job.companyName,
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
              onTap: widget.onSaveToggle,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(icon: LucideIcons.mapPin, label: job.location),
            if (job.salary != 'Not listed')
              _InfoChip(icon: LucideIcons.banknote, label: job.salary),
            _InfoChip(icon: LucideIcons.briefcase, label: jobTypeLabel(job.jobType)),
            _InfoChip(icon: LucideIcons.wifi, label: workModeLabel(job.workMode)),
          ],
        ),
        const SizedBox(height: 14),

        // Show AI summary if available, otherwise cleaned raw description.
        Text(
          _aiSummary ?? job.description,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.text(brightness).withValues(alpha: 0.88),
          ),
        ),
        if (_aiSummary != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '\u2728 AI Summary',
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.subtext(brightness),
              ),
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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onOpenDetails,
                child: const Text('Read more'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed:
                    (job.applyUrl.isNotEmpty || job.hasEasyApply) ? widget.onApply : null,
                child: Text(job.applyUrl.isNotEmpty ? 'Apply' : 'Easy apply'),
              ),
            ),
          ],
        ),
      ],
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
