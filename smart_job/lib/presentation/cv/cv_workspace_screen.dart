import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../application/controllers/smart_job_controller.dart';
import '../../domain/models/profile.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/smart_job_studio_theme.dart';
import '../shared/widgets/smart_job_ui.dart';
import 'widgets/cv_builder_config.dart';

class CVScreen extends ConsumerStatefulWidget {
  const CVScreen({super.key});

  @override
  ConsumerState<CVScreen> createState() => _CVScreenState();
}

class _CVScreenState extends ConsumerState<CVScreen> {
  static const _fontFamilies = ['Inter', 'Poppins', 'Roboto', 'Playfair Display'];
  static const _accentChoices = [
    AppColors.info,
    AppColors.teal,
    AppColors.sand,
    AppColors.coral,
    AppColors.midnight,
  ];

  double _zoom = 1;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(smartJobControllerProvider.select((state) => state.profile));
    final cv = profile.cvInsight;
    final template = cvTemplateOptions.firstWhere(
      (option) => option.title == cv.selectedTemplate,
      orElse: () => cvTemplateOptions.first,
    );
    final studioTheme = Theme.of(context).extension<SmartJobStudioTheme>()!;
    final parsedCompletion = ((cv.sectionOrder.length / defaultCvSectionOrder.length) * 100)
        .round()
        .clamp(40, 100);
    final accentColor = _hexToColor(cv.accentColorHex, template.defaultAccentColor);
    final document = _buildMockParsedDocument(profile);

    return Stack(
      children: [
        SmartJobScrollPage(
          maxWidth: 1360,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 220),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StudioHero(
                profile: profile,
                parsedCompletion: parsedCompletion,
                lastEditedLabel: _timeAgo(cv.lastEditedAtIso),
                onExport: () => _showMessage(context, 'PDF export is queued in prototype mode.'),
                onEditContent: () => context.go(AppRoute.cvSetup),
              ).animate().fade().slideY(begin: 0.04),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cards = [
                    SmartJobProgressPill(
                      value: cv.completionScore,
                      total: 100,
                      label: 'CV completion',
                      color: AppColors.midnight,
                      helpMessage: 'Measures how complete the generated resume is across core sections.',
                    ),
                    SmartJobProgressPill(
                      value: cv.atsScore,
                      total: 100,
                      label: 'ATS score',
                      color: AppColors.teal,
                      helpMessage: 'Estimates parsing strength and structure quality for ATS systems.',
                    ),
                    SmartJobProgressPill(
                      value: cv.keywordMatchScore,
                      total: 100,
                      label: 'Keyword match',
                      color: AppColors.sand,
                      helpMessage: 'Shows how well your CV language aligns with your target roles.',
                    ),
                  ];

                  if (constraints.maxWidth >= 920) {
                    return Row(
                      children: [
                        for (var index = 0; index < cards.length; index++) ...[
                          Expanded(child: cards[index]),
                          if (index < cards.length - 1) const SizedBox(width: 14),
                        ],
                      ],
                    );
                  }

                  return Column(
                    children: [
                      for (var index = 0; index < cards.length; index++) ...[
                        cards[index],
                        if (index < cards.length - 1) const SizedBox(height: 14),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final previewPanel = _StudioPanel(
                    title: 'Live CV Preview',
                    subtitle: 'A scrollable A4 preview that updates as soon as you change the template or styling.',
                    trailing: _ZoomControls(
                      zoom: _zoom,
                      onSelected: (value) => setState(() => _zoom = value),
                    ),
                    child: _PreviewViewport(
                      zoom: _zoom,
                      template: template,
                      accentColor: accentColor,
                      fontFamily: cv.fontFamily,
                      sectionOrder: cv.sectionOrder,
                      document: document,
                    ),
                  );

                  final sideColumn = Column(
                    children: [
                      _StudioPanel(
                        title: 'Template Gallery',
                        subtitle: 'Pick a layout and watch the preview transition instantly.',
                        child: _TemplateGrid(
                          selectedTemplate: cv.selectedTemplate,
                          onSelect: (option) {
                            ref.read(smartJobControllerProvider.notifier).updateCvStudioCustomization(
                                  templateName: option.title,
                                  accentColorHex: _colorToHex(option.defaultAccentColor),
                                  fontFamily: option.defaultFontFamily,
                                );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      _StudioPanel(
                        title: 'Template Customization',
                        subtitle: 'Accent color, font family, and section order all save into your workspace.',
                        trailing: _AutosaveChip(label: _timeAgo(cv.lastEditedAtIso)),
                        child: _CustomizationPanel(
                          accentColor: accentColor,
                          currentFontFamily: cv.fontFamily,
                          sectionOrder: cv.sectionOrder,
                          accentChoices: _accentChoices,
                          fontFamilies: _fontFamilies,
                          onAccentSelected: (color) {
                            ref.read(smartJobControllerProvider.notifier).updateCvStudioCustomization(
                                  accentColorHex: _colorToHex(color),
                                );
                          },
                          onFontSelected: (fontFamily) {
                            ref.read(smartJobControllerProvider.notifier).updateCvStudioCustomization(
                                  fontFamily: fontFamily,
                                );
                          },
                          onReorder: (updatedOrder) {
                            ref.read(smartJobControllerProvider.notifier).updateCvStudioCustomization(
                                  sectionOrder: updatedOrder,
                                );
                          },
                        ),
                      ),
                    ],
                  );

                  if (constraints.maxWidth >= 1100) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: previewPanel),
                        const SizedBox(width: 18),
                        Expanded(flex: 5, child: sideColumn),
                      ],
                    );
                  }

                  return Column(
                    children: [previewPanel, const SizedBox(height: 18), sideColumn],
                  );
                },
              ),
            ],
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 102,
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: studioTheme.exportBar,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: studioTheme.glassBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 24,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      _ExportAction(
                        icon: LucideIcons.fileOutput,
                        label: 'Download PDF',
                        filled: true,
                        onTap: () => _showMessage(context, 'PDF export is queued in prototype mode.'),
                      ),
                      _ExportAction(
                        icon: LucideIcons.fileText,
                        label: 'Download DOCX',
                        onTap: () => _showMessage(context, 'DOCX export is queued in prototype mode.'),
                      ),
                      _ExportAction(
                        icon: LucideIcons.link2,
                        label: 'Share public link',
                        onTap: () => _showMessage(context, 'Public CV sharing will open here in a future backend release.'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _buildMockParsedDocument(UserProfile profile) {
    return {
      'name': profile.fullName.isEmpty ? 'Your Name' : profile.fullName,
      'title': profile.headline.isEmpty ? 'Add a headline' : profile.headline,
      'summary': profile.cvInsight.parsedSummary,
      'contact': [
        if (!profile.hideContactInfo && profile.email.isNotEmpty) profile.email,
        if (!profile.hideContactInfo && profile.phoneNumber.isNotEmpty) profile.phoneNumber,
        if (profile.location.isNotEmpty) profile.location,
        if (profile.linkedInUrl.isNotEmpty) profile.linkedInUrl,
        if (profile.portfolioUrl.isNotEmpty) profile.portfolioUrl,
      ],
      'skills': profile.skills.isEmpty ? const ['Flutter', 'Dart', 'State management'] : profile.skills,
      'experience': profile.experience.isEmpty
          ? const ['SmartJob mock experience entry describing shipped features, ownership, and measurable impact.']
          : profile.experience,
      'education': profile.education.isEmpty
          ? const ['BSc in Computer Science / University / 2026']
          : profile.education,
      'projects': profile.projects.isEmpty
          ? const ['SmartJob capstone project focused on CV automation and job matching.']
          : profile.projects,
    };
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Color _hexToColor(String value, Color fallback) {
    final normalized = value.replaceAll('#', '').trim();
    if (normalized.length != 6) {
      return fallback;
    }
    final parsed = int.tryParse('FF$normalized', radix: 16);
    return parsed == null ? fallback : Color(parsed);
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  String _timeAgo(String isoString) {
    if (isoString.isEmpty) {
      return 'Autosaved just now';
    }
    final editedAt = DateTime.tryParse(isoString);
    if (editedAt == null) {
      return 'Autosaved just now';
    }
    final diff = DateTime.now().toUtc().difference(editedAt.toUtc());
    if (diff.inSeconds < 45) {
      return 'Last edited ${diff.inSeconds.clamp(1, 44)}s ago';
    }
    if (diff.inMinutes < 60) {
      return 'Last edited ${diff.inMinutes}m ago';
    }
    return 'Last edited ${diff.inHours}h ago';
  }
}

class _StudioHero extends StatelessWidget {
  const _StudioHero({required this.profile, required this.parsedCompletion, required this.lastEditedLabel, required this.onExport, required this.onEditContent});

  final UserProfile profile;
  final int parsedCompletion;
  final String lastEditedLabel;
  final VoidCallback onExport;
  final VoidCallback onEditContent;

  @override
  Widget build(BuildContext context) {
    return SmartJobPanel(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your CV is connected to SmartJob', style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroChip(icon: LucideIcons.badgeCheck, label: profile.hasUploadedCv ? 'Uploaded' : 'Builder ready'),
              const _HeroChip(icon: LucideIcons.save, label: 'Autosaved'),
              _HeroChip(icon: LucideIcons.layoutGrid, label: 'Sections parsed $parsedCompletion%'),
              _AutosaveChip(label: lastEditedLabel),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(onPressed: onExport, icon: const Icon(LucideIcons.fileOutput), label: const Text('Export PDF')),
              OutlinedButton.icon(onPressed: onEditContent, icon: const Icon(LucideIcons.penSquare), label: const Text('Edit content')),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.stroke(Theme.of(context).brightness)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: AppColors.teal), const SizedBox(width: 8), Text(label, style: Theme.of(context).textTheme.bodySmall)]),
    );
  }
}

class _AutosaveChip extends StatelessWidget {
  const _AutosaveChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(18)),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _StudioPanel extends StatelessWidget {
  const _StudioPanel({required this.title, required this.subtitle, required this.child, this.trailing});

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final studioTheme = Theme.of(context).extension<SmartJobStudioTheme>()!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: studioTheme.glassPanel, borderRadius: BorderRadius.circular(24), border: Border.all(color: studioTheme.glassBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SmartJobSectionHeader(title: title, subtitle: subtitle, trailing: trailing), const SizedBox(height: 18), child]),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.zoom, required this.onSelected});

  final double zoom;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final scale in const [0.75, 1.0, 1.25])
          ChoiceChip(
            selected: zoom == scale,
            label: Text('${(scale * 100).round()}%'),
            onSelected: (_) => onSelected(scale),
          ),
      ],
    );
  }
}

class _PreviewViewport extends StatelessWidget {
  const _PreviewViewport({required this.zoom, required this.template, required this.accentColor, required this.fontFamily, required this.sectionOrder, required this.document});

  final double zoom;
  final CvTemplateOption template;
  final Color accentColor;
  final String fontFamily;
  final List<String> sectionOrder;
  final Map<String, dynamic> document;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 760,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(22)),
      child: Scrollbar(
        child: SingleChildScrollView(
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: SizedBox(
                key: ValueKey('${template.title}-${accentColor.value}-$fontFamily-${sectionOrder.join('-')}-$zoom'),
                width: 540 * zoom,
                child: AspectRatio(
                  aspectRatio: 1 / 1.414,
                  child: _CvPreviewDocument(
                    template: template,
                    accentColor: accentColor,
                    fontFamily: fontFamily,
                    sectionOrder: sectionOrder,
                    document: document,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateGrid extends StatelessWidget {
  const _TemplateGrid({required this.selectedTemplate, required this.onSelect});

  final String selectedTemplate;
  final ValueChanged<CvTemplateOption> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: cvTemplateOptions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.84,
      ),
      itemBuilder: (context, index) {
        final option = cvTemplateOptions[index];
        final isSelected = option.title == selectedTemplate;
        return InkWell(
          onTap: () => onSelect(option),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.midnight : AppColors.surface(Theme.of(context).brightness),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: isSelected ? AppColors.midnight : AppColors.stroke(Theme.of(context).brightness)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 118,
                  decoration: BoxDecoration(color: option.previewCanvas, borderRadius: BorderRadius.circular(16), border: Border.all(color: option.borderColor)),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 54, height: 6, decoration: BoxDecoration(color: option.previewAccent, borderRadius: BorderRadius.circular(999))), const SizedBox(height: 8), Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: option.previewAccent.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(8))), const SizedBox(height: 8), Container(width: 90, height: 6, decoration: BoxDecoration(color: option.previewBar, borderRadius: BorderRadius.circular(999))), const SizedBox(height: 12), Expanded(child: Container(decoration: BoxDecoration(color: option.previewBar, borderRadius: BorderRadius.circular(12))))]),
                  ),
                ),
                const SizedBox(height: 12),
                if (isSelected) const _SelectedBadge(),
                if (isSelected) const SizedBox(height: 8),
                Text(option.title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isSelected ? Colors.white : AppColors.text(Theme.of(context).brightness))),
                const SizedBox(height: 6),
                Text(option.caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isSelected ? Colors.white.withValues(alpha: 0.72) : AppColors.subtext(Theme.of(context).brightness))),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
      child: Text('Currently selected', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white)),
    );
  }
}

class _CustomizationPanel extends StatelessWidget {
  const _CustomizationPanel({required this.accentColor, required this.currentFontFamily, required this.sectionOrder, required this.accentChoices, required this.fontFamilies, required this.onAccentSelected, required this.onFontSelected, required this.onReorder});

  final Color accentColor;
  final String currentFontFamily;
  final List<String> sectionOrder;
  final List<Color> accentChoices;
  final List<String> fontFamilies;
  final ValueChanged<Color> onAccentSelected;
  final ValueChanged<String> onFontSelected;
  final ValueChanged<List<String>> onReorder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Accent color', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [for (final color in accentChoices) _ColorDot(color: color, selected: color.value == accentColor.value, onTap: () => onAccentSelected(color))]),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          value: fontFamilies.contains(currentFontFamily) ? currentFontFamily : fontFamilies.first,
          decoration: const InputDecoration(labelText: 'Font family'),
          items: fontFamilies.map((family) => DropdownMenuItem(value: family, child: Text(family))).toList(),
          onChanged: (value) {
            if (value != null) {
              onFontSelected(value);
            }
          },
        ),
        const SizedBox(height: 20),
        Text('Section order', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sectionOrder.length,
          buildDefaultDragHandles: false,
          onReorder: (oldIndex, newIndex) {
            final updated = [...sectionOrder];
            if (newIndex > oldIndex) {
              newIndex -= 1;
            }
            final moved = updated.removeAt(oldIndex);
            updated.insert(newIndex, moved);
            onReorder(updated);
          },
          itemBuilder: (context, index) {
            final section = sectionOrder[index];
            return Container(
              key: ValueKey(section),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(color: AppColors.surfaceMuted(Theme.of(context).brightness), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.stroke(Theme.of(context).brightness))),
              child: Row(children: [Expanded(child: Text(_sectionLabel(section))), ReorderableDragStartListener(index: index, child: const Icon(LucideIcons.gripVertical, size: 18))]),
            );
          },
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 2)),
      ),
    );
  }
}

class _ExportAction extends StatelessWidget {
  const _ExportAction({required this.icon, required this.label, required this.onTap, this.filled = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = filled
        ? ElevatedButton.icon(onPressed: onTap, icon: Icon(icon), label: Text(label))
        : OutlinedButton.icon(onPressed: onTap, icon: Icon(icon), label: Text(label));
    return SizedBox(width: 220, child: child);
  }
}

class _CvPreviewDocument extends StatelessWidget {
  const _CvPreviewDocument({required this.template, required this.accentColor, required this.fontFamily, required this.sectionOrder, required this.document});

  final CvTemplateOption template;
  final Color accentColor;
  final String fontFamily;
  final List<String> sectionOrder;
  final Map<String, dynamic> document;

  @override
  Widget build(BuildContext context) {
    final heading = _font(fontFamily, const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1.1, color: Colors.black));
    final sectionHeading = _font(fontFamily, TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.9, color: accentColor));
    final body = _font(fontFamily, TextStyle(fontSize: template.layout == CvTemplateLayout.compact ? 10.5 : 11.4, height: 1.45, color: template.textColor));

    return Container(
      padding: EdgeInsets.all(template.layout == CvTemplateLayout.compact ? 24 : 30),
      decoration: BoxDecoration(color: template.background, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 26, offset: const Offset(0, 18))]),
      child: switch (template.layout) {
        CvTemplateLayout.techSidebar => _buildTechLayout(heading, sectionHeading, body),
        CvTemplateLayout.executive => _buildExecutiveLayout(heading, sectionHeading, body),
        _ => _buildStandardLayout(heading, sectionHeading, body),
      },
    );
  }

  Widget _buildStandardLayout(TextStyle heading, TextStyle sectionHeading, TextStyle body) {
    final sections = _orderedSections(sectionHeading, body);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_PreviewHeader(document: document, heading: heading, body: body, accentColor: accentColor, centered: template.layout == CvTemplateLayout.executive), const SizedBox(height: 22), ...sections]);
  }

  Widget _buildExecutiveLayout(TextStyle heading, TextStyle sectionHeading, TextStyle body) {
    final sections = _orderedSections(sectionHeading, body);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_PreviewHeader(document: document, heading: heading.copyWith(fontSize: 32), body: body, accentColor: accentColor, centered: true), const SizedBox(height: 24), ...sections]);
  }

  Widget _buildTechLayout(TextStyle heading, TextStyle sectionHeading, TextStyle body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 148,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Contact', style: sectionHeading),
                const SizedBox(height: 12),
                for (final item in (document['contact'] as List<dynamic>).take(4)) ...[Text(item.toString(), style: body.copyWith(fontSize: 10.5)), const SizedBox(height: 8)],
                const SizedBox(height: 10),
                Text('Skills', style: sectionHeading),
                const SizedBox(height: 12),
                for (final item in (document['skills'] as List<dynamic>).take(6)) ...[Text('• ${item.toString()}', style: body.copyWith(fontSize: 10.5)), const SizedBox(height: 6)],
              ],
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_PreviewHeader(document: document, heading: heading.copyWith(fontSize: 28), body: body, accentColor: accentColor), const SizedBox(height: 22), ..._orderedSections(sectionHeading, body, exclude: const ['skills'])]),
        ),
      ],
    );
  }

  List<Widget> _orderedSections(TextStyle sectionHeading, TextStyle body, {List<String> exclude = const []}) {
    final allowed = sectionOrder.where((section) => !exclude.contains(section));
    final widgets = <Widget>[];
    for (final section in allowed) {
      widgets.add(_PreviewSection(title: _sectionLabel(section), content: _sectionContent(section), titleStyle: sectionHeading, bodyStyle: body, accentColor: accentColor));
      widgets.add(const SizedBox(height: 16));
    }
    if (widgets.isNotEmpty) {
      widgets.removeLast();
    }
    return widgets;
  }

  List<String> _sectionContent(String section) {
    return switch (section) {
      'summary' => [document['summary'].toString()],
      'skills' => (document['skills'] as List<dynamic>).map((e) => e.toString()).toList(),
      'experience' => (document['experience'] as List<dynamic>).map((e) => e.toString()).toList(),
      'education' => (document['education'] as List<dynamic>).map((e) => e.toString()).toList(),
      'projects' => (document['projects'] as List<dynamic>).map((e) => e.toString()).toList(),
      _ => const [],
    };
  }

  TextStyle _font(String family, TextStyle style) {
    return switch (family) {
      'Poppins' => GoogleFonts.poppins(textStyle: style),
      'Roboto' => GoogleFonts.roboto(textStyle: style),
      'Playfair Display' => GoogleFonts.playfairDisplay(textStyle: style),
      _ => GoogleFonts.inter(textStyle: style),
    };
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.document, required this.heading, required this.body, required this.accentColor, this.centered = false});

  final Map<String, dynamic> document;
  final TextStyle heading;
  final TextStyle body;
  final Color accentColor;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final alignment = centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(document['name'].toString(), textAlign: centered ? TextAlign.center : TextAlign.left, style: heading),
        const SizedBox(height: 6),
        Text(document['title'].toString(), textAlign: centered ? TextAlign.center : TextAlign.left, style: body.copyWith(fontWeight: FontWeight.w600, color: accentColor)),
        const SizedBox(height: 10),
        Wrap(
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          spacing: 8,
          runSpacing: 8,
          children: [for (final item in (document['contact'] as List<dynamic>).take(5)) _PreviewTag(text: item.toString(), body: body, accentColor: accentColor)],
        ),
      ],
    );
  }
}

class _PreviewTag extends StatelessWidget {
  const _PreviewTag({required this.text, required this.body, required this.accentColor});

  final String text;
  final TextStyle body;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: body.copyWith(fontSize: 10.4)),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.title, required this.content, required this.titleStyle, required this.bodyStyle, required this.accentColor});

  final String title;
  final List<String> content;
  final TextStyle titleStyle;
  final TextStyle bodyStyle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: double.infinity, padding: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: accentColor.withValues(alpha: 0.35)))) , child: Text(title.toUpperCase(), style: titleStyle)),
        const SizedBox(height: 10),
        for (final item in content) ...[Text(item, style: bodyStyle), const SizedBox(height: 8)],
      ],
    );
  }
}

String _sectionLabel(String section) {
  return switch (section) {
    'summary' => 'Summary',
    'skills' => 'Skills',
    'experience' => 'Experience',
    'education' => 'Education',
    'projects' => 'Projects',
    _ => section,
  };
}
