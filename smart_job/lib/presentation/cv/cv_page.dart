import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
  static const _zoomLevels = [0.75, 1.0, 1.25];
  static const _accentChoices = [
    AppColors.midnight,
    AppColors.info,
    AppColors.teal,
    AppColors.sand,
    AppColors.coral,
  ];

  double _zoom = 1.0;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(
      smartJobControllerProvider.select((state) => state.profile),
    );
    final cv = profile.cvInsight;
    final studioTheme = Theme.of(context).extension<SmartJobStudioTheme>()!;
    final template = cvTemplateOptions.firstWhere(
      (item) => item.title == cv.selectedTemplate,
      orElse: () => cvTemplateOptions.first,
    );
    final accentColor = _hexToColor(cv.accentColorHex, template.defaultAccentColor);
    final parsedCompletion = ((cv.sectionOrder.length / defaultCvSectionOrder.length) * 100)
        .round()
        .clamp(35, 100);

    return Stack(
      children: [
        SmartJobScrollPage(
          maxWidth: 1380,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 210),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroCard(
                parsedCompletion: parsedCompletion,
                lastEditedLabel: _timeAgo(cv.lastEditedAtIso),
                onExport: () => _showMessage(context, 'PDF export will be connected next.'),
                onEditContent: () => context.go(AppRoute.cvSetup),
              ).animate().fade().slideY(begin: 0.04),
              const SizedBox(height: 20),
              _AnalyticsRow(cv: cv),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final previewCard = _StudioCard(
                    title: 'Live CV Preview',
                    subtitle: 'A polished A4 preview that updates instantly when the template, font, accent, or section order changes.',
                    trailing: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final zoomLevel in _zoomLevels)
                          ChoiceChip(
                            label: Text('${(zoomLevel * 100).round()}%'),
                            selected: _zoom == zoomLevel,
                            onSelected: (_) => setState(() => _zoom = zoomLevel),
                          ),
                      ],
                    ),
                    child: _PreviewPanel(
                      zoom: _zoom,
                      accentColor: accentColor,
                      fontFamily: cv.fontFamily,
                      template: template,
                      sectionOrder: cv.sectionOrder,
                      data: _previewData(profile),
                    ),
                  );

                  final sideColumn = Column(
                    children: [
                      _StudioCard(
                        title: 'Template Gallery',
                        subtitle: 'Switch between ATS-safe and more expressive layouts without leaving the studio.',
                        child: _TemplateGallery(
                          activeTemplate: cv.selectedTemplate,
                          onSelected: (templateOption) {
                            ref.read(smartJobControllerProvider.notifier).updateCvStudioCustomization(
                                  templateName: templateOption.title,
                                  accentColorHex: _colorToHex(templateOption.defaultAccentColor),
                                  fontFamily: templateOption.defaultFontFamily,
                                );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      _StudioCard(
                        title: 'Customization',
                        subtitle: 'Tune the accent color, font family, and section order for each application.',
                        trailing: _StatusPill(label: _timeAgo(cv.lastEditedAtIso), highlighted: true),
                        child: _CustomizationPanel(
                          accentColor: accentColor,
                          accentChoices: _accentChoices,
                          fontFamilies: _fontFamilies,
                          currentFontFamily: cv.fontFamily,
                          sectionOrder: cv.sectionOrder,
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
                          onReorder: (order) {
                            ref.read(smartJobControllerProvider.notifier).updateCvStudioCustomization(
                                  sectionOrder: order,
                                );
                          },
                        ),
                      ),
                    ],
                  );

                  if (constraints.maxWidth >= 1120) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: previewCard),
                        const SizedBox(width: 18),
                        Expanded(flex: 5, child: sideColumn),
                      ],
                    );
                  }

                  return Column(
                    children: [previewCard, const SizedBox(height: 18), sideColumn],
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
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: studioTheme.exportBar,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: studioTheme.glassBorder),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _BottomAction(
                        icon: Icons.picture_as_pdf_outlined,
                        label: 'Download PDF',
                        filled: true,
                        onTap: () => _showMessage(context, 'PDF export will be connected next.'),
                      ),
                      _BottomAction(
                        icon: Icons.description_outlined,
                        label: 'Download DOCX',
                        onTap: () => _showMessage(context, 'DOCX export is queued next.'),
                      ),
                      _BottomAction(
                        icon: Icons.link_outlined,
                        label: 'Share public link',
                        onTap: () => _showMessage(context, 'Public CV links will be enabled with backend sharing.'),
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

  Map<String, dynamic> _previewData(UserProfile profile) {
    return {
      'name': profile.fullName.isEmpty ? 'Your Name' : profile.fullName,
      'title': profile.headline.isEmpty ? 'Add your headline' : profile.headline,
      'summary': profile.cvInsight.parsedSummary,
      'contact': [
        if (!profile.hideContactInfo && profile.email.isNotEmpty) profile.email,
        if (!profile.hideContactInfo && profile.phoneNumber.isNotEmpty) profile.phoneNumber,
        if (profile.location.isNotEmpty) profile.location,
        if (profile.linkedInUrl.isNotEmpty) profile.linkedInUrl,
        if (profile.portfolioUrl.isNotEmpty) profile.portfolioUrl,
        if (profile.websiteUrl.isNotEmpty) profile.websiteUrl,
      ],
      'skills': profile.skills.isEmpty
          ? const ['Flutter', 'Dart', 'Firebase', 'REST APIs', 'Figma']
          : profile.skills,
      'experience': profile.experience.isEmpty
          ? const [
              'Built premium mobile product features with Flutter and Firebase while improving clarity, polish, and delivery speed.',
              'Worked with design and product stakeholders to ship structured user flows under short academic timelines.',
            ]
          : profile.experience,
      'education': profile.education.isEmpty
          ? const ['BSc in Computer Science, University, 2026']
          : profile.education,
      'projects': profile.projects.isEmpty
          ? const ['SmartJob capstone project focused on AI-assisted CV scoring, matching, and recruiter-ready exports.']
          : profile.projects,
    };
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
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  String _timeAgo(String isoString) {
    final editedAt = DateTime.tryParse(isoString);
    if (editedAt == null) {
      return 'Last edited just now';
    }
    final diff = DateTime.now().toUtc().difference(editedAt.toUtc());
    if (diff.inSeconds < 60) {
      return 'Last edited ${diff.inSeconds.clamp(1, 59)}s ago';
    }
    if (diff.inMinutes < 60) {
      return 'Last edited ${diff.inMinutes}m ago';
    }
    return 'Last edited ${diff.inHours}h ago';
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.parsedCompletion,
    required this.lastEditedLabel,
    required this.onExport,
    required this.onEditContent,
  });

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
              const _StatusPill(label: 'Uploaded âœ“'),
              const _StatusPill(label: 'Autosaved âœ“'),
              _StatusPill(label: 'Sections parsed $parsedCompletion%'),
              _StatusPill(label: lastEditedLabel, highlighted: true),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
              ),
              OutlinedButton.icon(
                onPressed: onEditContent,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit content'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalyticsRow extends StatelessWidget {
  const _AnalyticsRow({required this.cv});

  final CvInsight cv;

  @override
  Widget build(BuildContext context) {
    final cards = [
      SmartJobProgressPill(
        value: cv.completionScore,
        total: 100,
        label: 'CV completion',
        color: AppColors.midnight,
        helpMessage: 'Shows how complete the document is across the core resume sections.',
      ),
      SmartJobProgressPill(
        value: cv.atsScore,
        total: 100,
        label: 'ATS score',
        color: AppColors.teal,
        helpMessage: 'Estimates parser friendliness and overall structure quality for applicant tracking systems.',
      ),
      SmartJobProgressPill(
        value: cv.keywordMatchScore,
        total: 100,
        label: 'Keyword match',
        color: AppColors.sand,
        helpMessage: 'Compares your CV language against the roles and skills SmartJob is prioritizing.',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
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
    );
  }
}

class _StudioCard extends StatelessWidget {
  const _StudioCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final studioTheme = Theme.of(context).extension<SmartJobStudioTheme>()!;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: studioTheme.glassPanel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: studioTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartJobSectionHeader(title: title, subtitle: subtitle, trailing: trailing),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.teal.withValues(alpha: 0.16) : AppColors.surfaceMuted(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.stroke(Theme.of(context).brightness)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.zoom,
    required this.accentColor,
    required this.fontFamily,
    required this.template,
    required this.sectionOrder,
    required this.data,
  });

  final double zoom;
  final Color accentColor;
  final String fontFamily;
  final CvTemplateOption template;
  final List<String> sectionOrder;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final studioTheme = Theme.of(context).extension<SmartJobStudioTheme>()!;
    return Container(
      height: 940,
      decoration: BoxDecoration(
        color: studioTheme.glassStrong,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              child: Transform.scale(
                key: ValueKey('${template.title}-${accentColor.toARGB32()}-$fontFamily-${sectionOrder.join(',')}'),
                scale: zoom,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 720,
                  child: AspectRatio(
                    aspectRatio: 1 / 1.4142,
                    child: _ResumeDocument(
                      template: template,
                      accentColor: accentColor,
                      fontFamily: fontFamily,
                      sectionOrder: sectionOrder,
                      data: data,
                    ),
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

class _TemplateGallery extends StatelessWidget {
  const _TemplateGallery({required this.activeTemplate, required this.onSelected});

  final String activeTemplate;
  final ValueChanged<CvTemplateOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: cvTemplateOptions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.02,
      ),
      itemBuilder: (context, index) {
        final option = cvTemplateOptions[index];
        final isActive = option.title == activeTemplate;
        return InkWell(
          onTap: () => onSelected(option),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isActive ? option.previewAccent.withValues(alpha: 0.22) : AppColors.surfaceMuted(Theme.of(context).brightness).withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isActive ? option.previewAccent : AppColors.stroke(Theme.of(context).brightness)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 112,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: option.previewCanvas,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: option.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 52, height: 6, decoration: BoxDecoration(color: option.previewAccent, borderRadius: BorderRadius.circular(99))),
                      const SizedBox(height: 8),
                      Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: option.previewAccent.withValues(alpha: 0.78), borderRadius: BorderRadius.circular(8))),
                      const SizedBox(height: 8),
                      Container(width: 92, height: 6, decoration: BoxDecoration(color: option.previewBar, borderRadius: BorderRadius.circular(99))),
                      const SizedBox(height: 12),
                      Expanded(child: Container(decoration: BoxDecoration(color: option.previewBar, borderRadius: BorderRadius.circular(12)))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (isActive) const _StatusPill(label: 'Currently selected'),
                if (isActive) const SizedBox(height: 8),
                Text(option.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(option.caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.subtext(Theme.of(context).brightness))),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CustomizationPanel extends StatelessWidget {
  const _CustomizationPanel({
    required this.accentColor,
    required this.accentChoices,
    required this.fontFamilies,
    required this.currentFontFamily,
    required this.sectionOrder,
    required this.onAccentSelected,
    required this.onFontSelected,
    required this.onReorder,
  });

  final Color accentColor;
  final List<Color> accentChoices;
  final List<String> fontFamilies;
  final String currentFontFamily;
  final List<String> sectionOrder;
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
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final color in accentChoices)
              InkWell(
                onTap: () => onAccentSelected(color),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: color.toARGB32() == accentColor.toARGB32() ? Colors.white : Colors.transparent, width: 2),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: fontFamilies.contains(currentFontFamily) ? currentFontFamily : fontFamilies.first,
          decoration: const InputDecoration(labelText: 'Font family'),
          items: fontFamilies.map((family) => DropdownMenuItem<String>(value: family, child: Text(family))).toList(),
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
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted(Theme.of(context).brightness),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.stroke(Theme.of(context).brightness)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(_sectionLabel(section))),
                  ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_indicator)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.icon, required this.label, required this.onTap, this.filled = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final button = filled
        ? ElevatedButton.icon(onPressed: onTap, icon: Icon(icon), label: Text(label))
        : OutlinedButton.icon(onPressed: onTap, icon: Icon(icon), label: Text(label));
    return SizedBox(width: 220, child: button);
  }
}

class _ResumeDocument extends StatelessWidget {
  const _ResumeDocument({
    required this.template,
    required this.accentColor,
    required this.fontFamily,
    required this.sectionOrder,
    required this.data,
  });

  final CvTemplateOption template;
  final Color accentColor;
  final String fontFamily;
  final List<String> sectionOrder;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = _font(
      fontFamily,
      TextStyle(
        fontSize: template.layout == CvTemplateLayout.compact ? 10.8 : 11.6,
        height: 1.45,
        color: template.textColor,
      ),
    );
    final headingStyle = _font(
      fontFamily,
      TextStyle(
        fontSize: template.layout == CvTemplateLayout.executive ? 31 : 28,
        fontWeight: FontWeight.w700,
        height: 1.08,
        color: template.textColor,
      ),
    );
    final sectionTitleStyle = _font(
      fontFamily,
      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.9, color: accentColor),
    );

    return Container(
      padding: EdgeInsets.all(template.layout == CvTemplateLayout.compact ? 24 : 30),
      decoration: BoxDecoration(
        color: template.background,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 22, offset: const Offset(0, 16))],
      ),
      child: template.layout == CvTemplateLayout.techSidebar
          ? _buildTechLayout(headingStyle, sectionTitleStyle, bodyStyle)
          : _buildStandardLayout(headingStyle, sectionTitleStyle, bodyStyle),
    );
  }

  Widget _buildStandardLayout(TextStyle headingStyle, TextStyle sectionTitleStyle, TextStyle bodyStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DocumentHeader(
          data: data,
          headingStyle: headingStyle,
          bodyStyle: bodyStyle,
          accentColor: accentColor,
          centered: template.layout == CvTemplateLayout.executive,
        ),
        const SizedBox(height: 22),
        ..._orderedSections(sectionTitleStyle, bodyStyle),
      ],
    );
  }

  Widget _buildTechLayout(TextStyle headingStyle, TextStyle sectionTitleStyle, TextStyle bodyStyle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CONTACT', style: sectionTitleStyle),
                const SizedBox(height: 12),
                for (final item in (data['contact'] as List<dynamic>).take(5)) ...[
                  Text(item.toString(), style: bodyStyle.copyWith(fontSize: 10.4)),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                Text('SKILLS', style: sectionTitleStyle),
                const SizedBox(height: 12),
                for (final item in (data['skills'] as List<dynamic>).take(6)) ...[
                  Text('â€¢ ${item.toString()}', style: bodyStyle.copyWith(fontSize: 10.4)),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DocumentHeader(data: data, headingStyle: headingStyle, bodyStyle: bodyStyle, accentColor: accentColor),
              const SizedBox(height: 22),
              ..._orderedSections(sectionTitleStyle, bodyStyle, exclude: const ['skills']),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _orderedSections(TextStyle sectionTitleStyle, TextStyle bodyStyle, {List<String> exclude = const []}) {
    final widgets = <Widget>[];
    for (final section in sectionOrder.where((item) => !exclude.contains(item))) {
      widgets.add(_DocumentSection(title: _sectionLabel(section), items: _itemsFor(section), titleStyle: sectionTitleStyle, bodyStyle: bodyStyle, accentColor: accentColor));
      widgets.add(const SizedBox(height: 16));
    }
    if (widgets.isNotEmpty) {
      widgets.removeLast();
    }
    return widgets;
  }

  List<String> _itemsFor(String section) {
    return switch (section) {
      'summary' => [data['summary'].toString()],
      'skills' => (data['skills'] as List<dynamic>).map((item) => item.toString()).toList(),
      'experience' => (data['experience'] as List<dynamic>).map((item) => item.toString()).toList(),
      'education' => (data['education'] as List<dynamic>).map((item) => item.toString()).toList(),
      'projects' => (data['projects'] as List<dynamic>).map((item) => item.toString()).toList(),
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

class _DocumentHeader extends StatelessWidget {
  const _DocumentHeader({required this.data, required this.headingStyle, required this.bodyStyle, required this.accentColor, this.centered = false});

  final Map<String, dynamic> data;
  final TextStyle headingStyle;
  final TextStyle bodyStyle;
  final Color accentColor;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(data['name'].toString(), textAlign: centered ? TextAlign.center : TextAlign.left, style: headingStyle),
        const SizedBox(height: 6),
        Text(data['title'].toString(), textAlign: centered ? TextAlign.center : TextAlign.left, style: bodyStyle.copyWith(fontWeight: FontWeight.w600, color: accentColor)),
        const SizedBox(height: 10),
        Wrap(
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in (data['contact'] as List<dynamic>).take(6))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                child: Text(item.toString(), style: bodyStyle.copyWith(fontSize: 10.3)),
              ),
          ],
        ),
      ],
    );
  }
}

class _DocumentSection extends StatelessWidget {
  const _DocumentSection({required this.title, required this.items, required this.titleStyle, required this.bodyStyle, required this.accentColor});

  final String title;
  final List<String> items;
  final TextStyle titleStyle;
  final TextStyle bodyStyle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: accentColor.withValues(alpha: 0.32)))),
          child: Text(title.toUpperCase(), style: titleStyle),
        ),
        const SizedBox(height: 10),
        for (final item in items) ...[
          Text(item, style: bodyStyle),
          const SizedBox(height: 8),
        ],
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
