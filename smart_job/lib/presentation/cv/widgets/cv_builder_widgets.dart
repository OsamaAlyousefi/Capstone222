import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../domain/models/profile.dart';
import '../../../theme/app_colors.dart';
import '../../shared/widgets/smart_job_ui.dart';
import 'cv_builder_config.dart';

class CvTemplateGallery extends StatelessWidget {
  const CvTemplateGallery({
    super.key,
    required this.selectedTemplate,
    required this.onSelect,
  });

  final String selectedTemplate;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SmartJobPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmartJobSectionHeader(
            title: 'Template gallery',
            subtitle:
                'Choose a visual direction and keep switching until the preview feels right.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final option in cvTemplateOptions)
                _TemplateCard(
                  option: option,
                  selected: option.title == selectedTemplate,
                  onTap: () => onSelect(option.title),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class CvPreviewPanel extends StatelessWidget {
  const CvPreviewPanel({
    super.key,
    required this.profile,
    required this.template,
  });

  final UserProfile profile;
  final CvTemplateOption template;

  @override
  Widget build(BuildContext context) {
    return SmartJobPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmartJobSectionHeader(
            title: 'Live template preview',
            subtitle:
                'See how the selected layout frames your headline, skills, and strongest sections.',
          ),
          const SizedBox(height: 16),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: template.background,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: template.borderColor),
            ),
            child: _PreviewCanvas(profile: profile, template: template),
          ),
        ],
      ),
    );
  }
}

class CvPersonalInfoSection extends StatelessWidget {
  const CvPersonalInfoSection({
    super.key,
    required this.profile,
    required this.onEdit,
  });

  final UserProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return SmartJobPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartJobSectionHeader(
            title: 'Personal info',
            subtitle:
                'Keep the identity block tight, clear, and easy to contact.',
            trailing: TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(LucideIcons.penTool, size: 16),
              label: const Text('Edit'),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted(Theme.of(context).brightness),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  profile.headline,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SmartJobMetricPill(
                      label: 'email',
                      value: profile.email.isEmpty ? 'Add email' : profile.email,
                      icon: LucideIcons.mail,
                    ),
                    SmartJobMetricPill(
                      label: 'phone',
                      value: profile.phoneNumber.isEmpty
                          ? 'Add phone'
                          : profile.phoneNumber,
                      icon: LucideIcons.phone,
                    ),
                    SmartJobMetricPill(
                      label: 'location',
                      value: profile.location.isEmpty
                          ? 'Add location'
                          : profile.location,
                      icon: LucideIcons.mapPin,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const CvSuggestionRow(
            text:
                'Keep your headline specific. Mention your target role, strongest tools, and what kind of work you want to be hired for.',
          ),
        ],
      ),
    );
  }
}

class CvBuilderSectionCard extends StatelessWidget {
  const CvBuilderSectionCard({
    super.key,
    required this.config,
    required this.entries,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final CvSectionConfig config;
  final List<String> entries;
  final VoidCallback onAdd;
  final void Function(int index, String currentValue) onEdit;
  final void Function(int index) onDelete;

  @override
  Widget build(BuildContext context) {
    return SmartJobPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartJobSectionHeader(
            title: config.title,
            subtitle: config.subtitle,
            trailing: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add'),
            ),
          ),
          const SizedBox(height: 16),
          CvSuggestionRow(text: config.suggestion),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            CvInlineEmptyState(
              icon: config.icon,
              title: config.emptyTitle,
              message: config.emptyMessage,
            )
          else
            Column(
              children: [
                for (var index = 0; index < entries.length; index++) ...[
                  CvEntryExpansionCard(
                    icon: config.icon,
                    title: entryTitle(entries[index]),
                    subtitle: entrySubtitle(entries[index]),
                    value: entries[index],
                    onEdit: () => onEdit(index, entries[index]),
                    onDelete: () => onDelete(index),
                  ),
                  if (index < entries.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class CvGeneratedPersonalInfoSection extends StatelessWidget {
  const CvGeneratedPersonalInfoSection({
    super.key,
    required this.profile,
    required this.onRefreshData,
  });

  final UserProfile profile;
  final VoidCallback onRefreshData;

  @override
  Widget build(BuildContext context) {
    return SmartJobPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartJobSectionHeader(
            title: 'Source profile',
            subtitle:
                'This identity block was generated from your guided CV setup answers.',
            trailing: TextButton.icon(
              onPressed: onRefreshData,
              icon: const Icon(LucideIcons.penTool, size: 16),
              label: const Text('Update data'),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted(Theme.of(context).brightness),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  profile.headline,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SmartJobMetricPill(
                      label: 'email',
                      value: profile.email.isEmpty ? 'Missing' : profile.email,
                      icon: LucideIcons.mail,
                    ),
                    SmartJobMetricPill(
                      label: 'phone',
                      value: profile.phoneNumber.isEmpty ? 'Missing' : profile.phoneNumber,
                      icon: LucideIcons.phone,
                    ),
                    SmartJobMetricPill(
                      label: 'location',
                      value: profile.location.isEmpty ? 'Missing' : profile.location,
                      icon: LucideIcons.mapPin,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CvGeneratedSectionCard extends StatelessWidget {
  const CvGeneratedSectionCard({
    super.key,
    required this.config,
    required this.entries,
  });

  final CvSectionConfig config;
  final List<String> entries;

  @override
  Widget build(BuildContext context) {
    return SmartJobPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartJobSectionHeader(
            title: config.title,
            subtitle: config.subtitle,
          ),
          const SizedBox(height: 16),
          CvSuggestionRow(text: config.suggestion),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            CvInlineEmptyState(
              icon: config.icon,
              title: config.emptyTitle,
              message: config.emptyMessage,
            )
          else
            Column(
              children: [
                for (var index = 0; index < entries.length; index++) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted(Theme.of(context).brightness),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.teal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(config.icon, size: 16, color: AppColors.teal),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entryTitle(entries[index]),
                                    style: Theme.of(context).textTheme.headlineMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    entries[index],
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (index < entries.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class CvGeneratedChipSectionCard extends StatelessWidget {
  const CvGeneratedChipSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.suggestion,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.values,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String suggestion;
  final String emptyTitle;
  final String emptyMessage;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return SmartJobPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartJobSectionHeader(
            title: title,
            subtitle: subtitle,
          ),
          const SizedBox(height: 16),
          CvSuggestionRow(text: suggestion),
          const SizedBox(height: 16),
          if (values.isEmpty)
            CvInlineEmptyState(
              icon: icon,
              title: emptyTitle,
              message: emptyMessage,
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final value in values) Chip(label: Text(value)),
              ],
            ),
        ],
      ),
    );
  }
}

class CvChipSectionCard extends StatelessWidget {
  const CvChipSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.suggestion,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.values,
    required this.onAdd,
    required this.onDelete,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String suggestion;
  final String emptyTitle;
  final String emptyMessage;
  final List<String> values;
  final VoidCallback onAdd;
  final void Function(String value) onDelete;

  @override
  Widget build(BuildContext context) {
    return SmartJobPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartJobSectionHeader(
            title: title,
            subtitle: subtitle,
            trailing: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add'),
            ),
          ),
          const SizedBox(height: 16),
          CvSuggestionRow(text: suggestion),
          const SizedBox(height: 16),
          if (values.isEmpty)
            CvInlineEmptyState(
              icon: icon,
              title: emptyTitle,
              message: emptyMessage,
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final value in values)
                  Chip(
                    label: Text(value),
                    deleteIcon: const Icon(LucideIcons.x, size: 16),
                    onDeleted: () => onDelete(value),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class CvEntryExpansionCard extends StatelessWidget {
  const CvEntryExpansionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onEdit,
    required this.onDelete,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 16, color: AppColors.teal),
          ),
          title: Text(title, style: Theme.of(context).textTheme.headlineMedium),
          subtitle: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.subtext(Theme.of(context).brightness),
                ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(LucideIcons.penTool),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                    onPressed: onDelete,
                    icon: const Icon(LucideIcons.trash2),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CvInlineEmptyState extends StatelessWidget {
  const CvInlineEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.teal),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.subtext(Theme.of(context).brightness),
                ),
          ),
        ],
      ),
    );
  }
}

class CvSuggestionRow extends StatelessWidget {
  const CvSuggestionRow({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sand.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.sparkles, size: 16, color: AppColors.sand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

String entryTitle(String value) {
  final lines = value.split('\n').where((line) => line.trim().isNotEmpty).toList();
  if (lines.isEmpty) {
    return 'Untitled entry';
  }
  return lines.first.length > 48
      ? '${lines.first.substring(0, 48)}...'
      : lines.first;
}

String entrySubtitle(String value) {
  final normalized = value.replaceAll('\n', ' ');
  if (normalized.length <= 80) {
    return normalized;
  }
  return '${normalized.substring(0, 80)}...';
}

class _PreviewCanvas extends StatelessWidget {
  const _PreviewCanvas({required this.profile, required this.template});

  final UserProfile profile;
  final CvTemplateOption template;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: template.textColor,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: template.headerBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName.isEmpty ? 'Your Name' : profile.fullName,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: template.textColor,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  profile.headline.isEmpty
                      ? 'Add a strong headline to preview your CV'
                      : profile.headline,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: template.textColor.withValues(alpha: 0.8),
                      ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (profile.email.isNotEmpty)
                      _PreviewTag(text: profile.email, option: template),
                    if (profile.location.isNotEmpty)
                      _PreviewTag(text: profile.location, option: template),
                    if (profile.phoneNumber.isNotEmpty)
                      _PreviewTag(text: profile.phoneNumber, option: template),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _PreviewSection(
            option: template,
            title: 'Skills',
            lines: profile.skills.isEmpty
                ? const ['Add skills to make the preview stronger.']
                : profile.skills.take(5).toList(),
          ),
          const SizedBox(height: 12),
          _PreviewSection(
            option: template,
            title: 'Experience',
            lines: profile.experience.isEmpty
                ? const ['No experience added yet.']
                : profile.experience.take(2).toList(),
          ),
          const SizedBox(height: 12),
          _PreviewSection(
            option: template,
            title: 'Projects',
            lines: profile.projects.isEmpty
                ? const ['No projects added yet.']
                : profile.projects.take(2).toList(),
          ),
        ],
      ),
    );
  }
}

class _PreviewTag extends StatelessWidget {
  const _PreviewTag({required this.text, required this.option});

  final String text;
  final CvTemplateOption option;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: option.chipBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: option.textColor,
            ),
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.option,
    required this.title,
    required this.lines,
  });

  final CvTemplateOption option;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: option.sectionBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: option.textColor,
                ),
          ),
          const SizedBox(height: 10),
          for (final line in lines.take(2)) ...[
            Text(
              line,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: option.textColor.withValues(alpha: 0.88),
                  ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _TemplateCard extends StatefulWidget {
  const _TemplateCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final CvTemplateOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.01 : 1,
        duration: const Duration(milliseconds: 160),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 200,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.selected
                  ? AppColors.midnight
                  : AppColors.surface(Theme.of(context).brightness),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.selected
                    ? AppColors.midnight
                    : AppColors.stroke(Theme.of(context).brightness),
              ),
              boxShadow: [
                if (_hovered)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 124,
                  decoration: BoxDecoration(
                    color: widget.option.previewCanvas,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: widget.option.borderColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 60,
                          height: 6,
                          decoration: BoxDecoration(
                            color: widget.option.previewAccent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          height: 14,
                          decoration: BoxDecoration(
                            color: widget.option.previewAccent.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _PreviewBar(color: widget.option.previewBar)),
                            const SizedBox(width: 8),
                            Expanded(child: _PreviewBar(color: widget.option.previewBar)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _PreviewBar(color: widget.option.previewBar),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: _PreviewPanelBlock(color: widget.option.previewBar)),
                            const SizedBox(width: 8),
                            Expanded(child: _PreviewPanelBlock(color: widget.option.previewBar)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.option.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: widget.selected
                            ? Colors.white
                            : AppColors.text(Theme.of(context).brightness),
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.option.caption,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: widget.selected
                            ? Colors.white.withValues(alpha: 0.72)
                            : AppColors.subtext(Theme.of(context).brightness),
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

class _PreviewBar extends StatelessWidget {
  const _PreviewBar({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _PreviewPanelBlock extends StatelessWidget {
  const _PreviewPanelBlock({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

