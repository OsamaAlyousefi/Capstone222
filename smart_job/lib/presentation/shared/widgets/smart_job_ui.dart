import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../domain/models/application.dart';
import '../../../domain/models/job.dart';
import '../../../domain/models/message.dart';
import '../../../theme/app_colors.dart';

extension SmartJobContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isCompact => screenWidth < 700;
  double get contentMaxWidth => screenWidth >= 1280 ? 1160 : 980;
}

class SmartJobBackground extends StatelessWidget {
  const SmartJobBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.canvas(brightness),
              gradient: LinearGradient(
                colors: [
                  AppColors.canvas(brightness),
                  AppColors.surfaceMuted(brightness).withValues(alpha: isDark ? 0.24 : 0.55),
                  AppColors.canvas(brightness),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -40,
          child: _Orb(
            size: 280,
            color: AppColors.sand.withValues(alpha: isDark ? 0.18 : 0.28),
          ),
        ),
        Positioned(
          top: 160,
          left: -90,
          child: _Orb(
            size: 220,
            color: AppColors.teal.withValues(alpha: isDark ? 0.16 : 0.18),
          ),
        ),
        Positioned(
          bottom: -120,
          right: 24,
          child: _Orb(
            size: 240,
            color: AppColors.midnight.withValues(alpha: isDark ? 0.14 : 0.1),
          ),
        ),
        child,
      ],
    );
  }
}

class SmartJobScrollPage extends StatelessWidget {
  const SmartJobScrollPage({
    super.key,
    required this.child,
    this.maxWidth = 1160,
    this.padding,
    this.scrollViewKey,
    this.controller,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final Key? scrollViewKey;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 1100
              ? 32.0
              : constraints.maxWidth >= 720
                  ? 24.0
                  : 16.0;

          return SingleChildScrollView(
            key: scrollViewKey,
            controller: controller,
            padding: EdgeInsets.zero,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: padding ??
                      EdgeInsets.fromLTRB(
                        horizontalPadding,
                        24,
                        horizontalPadding,
                        120,
                      ),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SmartJobPanel extends StatelessWidget {
  const SmartJobPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin,
    this.radius = 28,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface(brightness).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.stroke(brightness)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: brightness == Brightness.dark ? 0.2 : 0.06,
            ),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SmartJobAppLogo extends StatelessWidget {
  const SmartJobAppLogo({
    super.key,
    this.showWordmark = true,
    this.centered = false,
    this.size = 80,
  });

  final bool showWordmark;
  final bool centered;
  final double size;

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      'assets/images/logo.png',
      height: size,
      fit: BoxFit.contain,
    );

    return centered ? Center(child: logo) : logo;
  }
}

class SmartJobSectionHeader extends StatelessWidget {
  const SmartJobSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.displaySmall),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.subtext(Theme.of(context).brightness),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 16),
          trailing!,
        ],
      ],
    );
  }
}

class SmartJobAvatar extends StatelessWidget {
  const SmartJobAvatar({
    super.key,
    required this.label,
    this.size = 48,
  });

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.34),
        gradient: const LinearGradient(
          colors: [AppColors.midnight, AppColors.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        label,
        style: textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontSize: size * 0.28,
        ),
      ),
    );
  }
}

class SmartJobMetricPill extends StatelessWidget {
  const SmartJobMetricPill({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted(brightness),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.stroke(brightness)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.teal),
            const SizedBox(width: 8),
          ],
          Text(
            value,
            style: textTheme.labelLarge?.copyWith(color: AppColors.midnight),
          ),
          const SizedBox(width: 8),
          Text(label, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class SmartJobEmptyState extends StatelessWidget {
  const SmartJobEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SmartJobPanel(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 28, color: AppColors.teal),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.subtext(Theme.of(context).brightness),
                ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

class SmartJobFilterChip extends StatefulWidget {
  const SmartJobFilterChip({
    super.key,
    required this.label,
    this.selected = false,
    this.icon,
    this.onTap,
  });

  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  State<SmartJobFilterChip> createState() => _SmartJobFilterChipState();
}

class _SmartJobFilterChipState extends State<SmartJobFilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final baseColor = widget.selected
        ? AppColors.midnight
        : AppColors.surface(brightness).withValues(alpha: 0.88);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.01 : 1,
        duration: const Duration(milliseconds: 160),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _hovered && !widget.selected
                    ? AppColors.surfaceMuted(brightness)
                    : baseColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.selected
                      ? AppColors.midnight
                      : AppColors.stroke(brightness),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: 16,
                      color: widget.selected
                          ? Colors.white
                          : AppColors.text(brightness),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: widget.selected
                              ? Colors.white
                              : AppColors.text(brightness),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SmartJobProgressPill extends StatelessWidget {
  const SmartJobProgressPill({
    super.key,
    required this.value,
    required this.total,
    required this.label,
    required this.color,
    this.helpMessage,
  });

  final int value;
  final int total;
  final String label;
  final Color color;
  final String? helpMessage;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final progress = total == 0 ? 0.0 : value / total;
    return SmartJobPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(label, style: Theme.of(context).textTheme.bodySmall),
              ),
              if (helpMessage != null)
                Tooltip(
                  message: helpMessage!,
                  child: Icon(
                    LucideIcons.info,
                    size: 14,
                    color: AppColors.subtext(brightness),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceMuted(brightness),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class SmartJobHeroLabel extends StatelessWidget {
  const SmartJobHeroLabel({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.sand.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.sparkles, size: 14, color: AppColors.sand),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.midnight,
                ),
          ),
        ],
      ),
    ).animate().fade(duration: 350.ms).slideY(begin: -0.08);
  }
}

class SmartJobSkeletonBlock extends StatelessWidget {
  const SmartJobSkeletonBlock({
    super.key,
    this.height = 16,
    this.width,
    this.radius = 14,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted(brightness),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

String workModeLabel(WorkMode workMode) {
  return switch (workMode) {
    WorkMode.remote => 'Remote',
    WorkMode.hybrid => 'Hybrid',
    WorkMode.onsite => 'On-site',
  };
}

String jobTypeLabel(JobType jobType) {
  return switch (jobType) {
    JobType.fullTime => 'Full time',
    JobType.contract => 'Contract',
    JobType.internship => 'Internship',
    JobType.partTime => 'Part time',
  };
}

String experienceLevelLabel(ExperienceLevel level) {
  return switch (level) {
    ExperienceLevel.internship => 'Intern',
    ExperienceLevel.junior => 'Junior',
    ExperienceLevel.mid => 'Mid',
    ExperienceLevel.senior => 'Senior',
    ExperienceLevel.lead => 'Lead',
  };
}

String applicationStatusLabel(ApplicationStatus status) {
  return switch (status) {
    ApplicationStatus.saved => 'Saved',
    ApplicationStatus.pending => 'Pending',
    ApplicationStatus.interview => 'Interview',
    ApplicationStatus.accepted => 'Accepted',
    ApplicationStatus.rejected => 'Rejected',
  };
}

Color applicationStatusColor(ApplicationStatus status) {
  return switch (status) {
    ApplicationStatus.saved => AppColors.info,
    ApplicationStatus.pending => AppColors.warning,
    ApplicationStatus.interview => AppColors.teal,
    ApplicationStatus.accepted => AppColors.success,
    ApplicationStatus.rejected => AppColors.danger,
  };
}

String messageTypeLabel(MessageType type) {
  return switch (type) {
    MessageType.interview => 'Interview',
    MessageType.offer => 'Offer',
    MessageType.rejection => 'Rejected',
    MessageType.update => 'Update',
    MessageType.followUp => 'Follow up',
  };
}

Color messageTypeColor(MessageType type) {
  return switch (type) {
    MessageType.interview => AppColors.teal,
    MessageType.offer => AppColors.success,
    MessageType.rejection => AppColors.danger,
    MessageType.update => AppColors.info,
    MessageType.followUp => AppColors.warning,
  };
}

Color jobMatchColor(double score) {
  final percentage = (score * 100).round();
  if (percentage >= 80) return AppColors.success;
  if (percentage >= 60) return AppColors.teal;
  if (percentage >= 40) return AppColors.sand;
  return AppColors.coral;
}

String jobMatchLabel(double score) {
  final percentage = (score * 100).round();
  if (percentage >= 80) return 'Excellent match';
  if (percentage >= 60) return 'Strong match';
  if (percentage >= 40) return 'Good match';
  return 'Low match';
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}


