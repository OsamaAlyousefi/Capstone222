import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../application/controllers/smart_job_controller.dart';
import '../../domain/models/profile.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../shared/widgets/smart_job_ui.dart';
import 'widgets/cv_builder_config.dart';
import 'widgets/cv_builder_widgets.dart';

class CVScreen extends ConsumerWidget {
  const CVScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(
      smartJobControllerProvider.select((state) => state.profile),
    );
    final cv = profile.cvInsight;
    final template = cvTemplateOptions.firstWhere(
      (option) => option.title == cv.selectedTemplate,
      orElse: () => cvTemplateOptions.first,
    );
    final completedSections = requiredCvSections
        .where((section) => _isSectionComplete(profile, section))
        .length;

    return SmartJobScrollPage(
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
                          SmartJobHeroLabel(label: profile.hasUploadedCv ? 'Uploaded CV' : 'Generated CV'),
                          const SizedBox(height: 16),
                          Text(
                            profile.hasUploadedCv
                                ? 'Your uploaded CV is now connected to SmartJob.'
                                : 'Your CV is generated from the builder data you completed during onboarding.',
                            style: Theme.of(context).textTheme.displayMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            profile.hasUploadedCv
                                ? 'Use this page to review the uploaded file details, scoring insights, and template options tied to your resume.'
                                : 'Use this page to preview the final document, change templates, and review the sections SmartJob assembled for you.',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppColors.subtext(Theme.of(context).brightness),
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SmartJobAvatar(label: profile.photoLabel, size: 60),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SmartJobMetricPill(
                      label: 'template',
                      value: cv.selectedTemplate,
                      icon: LucideIcons.layoutTemplate,
                    ),
                    SmartJobMetricPill(
                      label: 'sections complete',
                      value: '$completedSections/${requiredCvSections.length}',
                      icon: LucideIcons.layoutGrid,
                    ),
                    SmartJobMetricPill(
                      label: 'autosave',
                      value: cv.lastUpdatedLabel,
                      icon: LucideIcons.save,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (profile.hasUploadedCv)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showMessage(
                        context,
                        'Your uploaded CV is connected, but full document export is still pending.',
                      ),
                      icon: const Icon(LucideIcons.fileOutput),
                      label: const Text('Export preview'),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.go(AppRoute.cvSetup),
                          icon: const Icon(LucideIcons.penTool),
                          label: const Text('Edit builder data'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showMessage(
                            context,
                            'PDF export stays mocked in this prototype, but your generated CV is ready to preview.',
                          ),
                          icon: const Icon(LucideIcons.fileOutput),
                          label: const Text('Export preview'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ).animate().fade().slideY(begin: 0.04),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final tiles = [
                SmartJobProgressPill(
                  value: cv.completionScore,
                  total: 100,
                  label: 'CV completion',
                  color: AppColors.midnight,
                  helpMessage:
                      'Measures how complete your generated CV is across the core sections recruiters expect to see.',
                ),
                SmartJobProgressPill(
                  value: cv.atsScore,
                  total: 100,
                  label: 'ATS score',
                  color: AppColors.teal,
                  helpMessage:
                      'Estimates readability, structure, and keyword readiness for applicant tracking systems.',
                ),
                SmartJobProgressPill(
                  value: cv.keywordMatchScore,
                  total: 100,
                  label: 'Keyword match',
                  color: AppColors.sand,
                  helpMessage:
                      'Shows how well your generated CV aligns with the roles you selected during onboarding.',
                ),
              ];

              if (constraints.maxWidth >= 920) {
                return Row(
                  children: [
                    for (var index = 0; index < tiles.length; index++) ...[
                      Expanded(child: tiles[index]),
                      if (index < tiles.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                );
              }

              return Column(
                children: [
                  for (var index = 0; index < tiles.length; index++) ...[
                    tiles[index],
                    if (index < tiles.length - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          CvTemplateGallery(
            selectedTemplate: cv.selectedTemplate,
            onSelect: (templateName) {
              ref.read(smartJobControllerProvider.notifier).updateCvTemplate(templateName);
              _showMessage(context, 'Template updated to $templateName.');
            },
          ).animate().fade(delay: 80.ms),
          const SizedBox(height: 20),
          CvPreviewPanel(profile: profile, template: template)
              .animate()
              .fade(delay: 120.ms),
          const SizedBox(height: 20),
          CvGeneratedPersonalInfoSection(
            profile: profile,
            onRefreshData: () => context.go(AppRoute.cvSetup),
          ),
          const SizedBox(height: 16),
          CvGeneratedChipSectionCard(
            icon: LucideIcons.sparkles,
            title: 'Skills',
            subtitle: 'These keywords were pulled from your builder data.',
            suggestion:
                'If a role calls for different tools or strengths, edit your builder data and regenerate the draft.',
            emptyTitle: 'No skills added yet',
            emptyMessage:
                'Open the builder again and add the tools, platforms, and strengths you want SmartJob to emphasize.',
            values: profile.skills,
          ),
          const SizedBox(height: 16),
          for (final section in orderedCvSections) ...[
            if (section == CvCollectionSection.languages ||
                section == CvCollectionSection.interests)
              CvGeneratedChipSectionCard(
                icon: cvSectionConfigs[section]!.icon,
                title: cvSectionConfigs[section]!.title,
                subtitle: cvSectionConfigs[section]!.subtitle,
                suggestion: cvSectionConfigs[section]!.suggestion,
                emptyTitle: cvSectionConfigs[section]!.emptyTitle,
                emptyMessage: cvSectionConfigs[section]!.emptyMessage,
                values: profile.entriesFor(section),
              )
            else
              CvGeneratedSectionCard(
                config: cvSectionConfigs[section]!,
                entries: profile.entriesFor(section),
              ),
            const SizedBox(height: 16),
          ],
          SmartJobPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SmartJobSectionHeader(
                  title: 'SmartJob insights',
                  subtitle:
                      'The generated draft still highlights strengths, missing pieces, and where to improve next.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final strength in cv.highlightedStrengths) Chip(label: Text(strength)),
                  ],
                ),
                if (cv.missingSections.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Still missing',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final missing in cv.missingSections)
                        Chip(
                          backgroundColor: AppColors.coral.withValues(alpha: 0.12),
                          label: Text(missing),
                        ),
                    ],
                  ),
                ],
                if (cv.improvementTips.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Suggestions',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  for (final tip in cv.improvementTips) ...[
                    CvSuggestionRow(text: tip),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ).animate().fade(delay: 160.ms),
        ],
      ),
    );
  }

  bool _isSectionComplete(UserProfile profile, CvCollectionSection section) {
    if (section == CvCollectionSection.skills) {
      return profile.skills.isNotEmpty;
    }
    return profile.entriesFor(section).isNotEmpty;
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}



