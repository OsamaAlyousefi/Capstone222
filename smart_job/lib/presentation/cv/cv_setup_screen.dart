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

class CvSetupScreen extends ConsumerWidget {
  const CvSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(
      smartJobControllerProvider.select((state) => state.profile),
    );
    final cv = profile.cvInsight;
    final completedSections = requiredCvSections
        .where((section) => _isSectionComplete(profile, section))
        .length;

    return Scaffold(
      body: SmartJobBackground(
        child: SmartJobScrollPage(
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
                              const SmartJobHeroLabel(label: 'Build a new CV'),
                              const SizedBox(height: 16),
                              Text(
                                'Add your details once and let SmartJob turn them into a structured CV draft.',
                                style: Theme.of(context).textTheme.displayMedium,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'This setup happens before you enter the main app. When you generate the CV, onboarding is completed and SmartJob will take you to your CV workspace.',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: AppColors.subtext(
                                        Theme.of(context).brightness,
                                      ),
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
                          label: 'sections complete',
                          value: '$completedSections/${requiredCvSections.length}',
                          icon: LucideIcons.layoutGrid,
                        ),
                        SmartJobMetricPill(
                          label: 'autosave',
                          value: cv.lastUpdatedLabel,
                          icon: LucideIcons.save,
                        ),
                        SmartJobMetricPill(
                          label: 'status',
                          value: 'Onboarding',
                          icon: LucideIcons.sparkles,
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fade().slideY(begin: 0.04),
              const SizedBox(height: 20),
              CvPersonalInfoSection(
                profile: profile,
                onEdit: () => _showPersonalInfoEditor(context, ref, profile),
              ),
              const SizedBox(height: 16),
              CvChipSectionCard(
                icon: LucideIcons.sparkles,
                title: 'Skills',
                subtitle: 'Add the tools, platforms, and strengths you want recruiters to notice first.',
                suggestion:
                    'Use exact terms from job descriptions, especially frameworks, tools, and collaboration strengths.',
                emptyTitle: 'No skills added yet',
                emptyMessage:
                    'Start with five core strengths like Flutter, Firebase, Design Systems, Figma, or Testing.',
                values: profile.skills,
                onAdd: () => _showChipEditor(
                  context,
                  ref,
                  section: CvCollectionSection.skills,
                  title: 'Add skills',
                ),
                onDelete: (value) {
                  final index = profile.skills.indexOf(value);
                  ref.read(smartJobControllerProvider.notifier).removeProfileEntry(
                        section: CvCollectionSection.skills,
                        index: index,
                      );
                  _showMessage(context, 'Skill removed.');
                },
              ),
              const SizedBox(height: 16),
              for (final section in orderedCvSections) ...[
                if (section == CvCollectionSection.languages ||
                    section == CvCollectionSection.interests)
                  CvChipSectionCard(
                    icon: cvSectionConfigs[section]!.icon,
                    title: cvSectionConfigs[section]!.title,
                    subtitle: cvSectionConfigs[section]!.subtitle,
                    suggestion: cvSectionConfigs[section]!.suggestion,
                    emptyTitle: cvSectionConfigs[section]!.emptyTitle,
                    emptyMessage: cvSectionConfigs[section]!.emptyMessage,
                    values: profile.entriesFor(section),
                    onAdd: () => _showChipEditor(
                      context,
                      ref,
                      section: section,
                      title: 'Add ${cvSectionConfigs[section]!.title.toLowerCase()}',
                    ),
                    onDelete: (value) {
                      final index = profile.entriesFor(section).indexOf(value);
                      ref.read(smartJobControllerProvider.notifier).removeProfileEntry(
                            section: section,
                            index: index,
                          );
                      _showMessage(context, '${cvSectionConfigs[section]!.title} updated.');
                    },
                  )
                else
                  CvBuilderSectionCard(
                    config: cvSectionConfigs[section]!,
                    entries: profile.entriesFor(section),
                    onAdd: () => _showEntryEditor(
                      context,
                      ref,
                      section: section,
                      config: cvSectionConfigs[section]!,
                    ),
                    onEdit: (index, currentValue) => _showEntryEditor(
                      context,
                      ref,
                      section: section,
                      config: cvSectionConfigs[section]!,
                      currentValue: currentValue,
                      index: index,
                    ),
                    onDelete: (index) {
                      ref.read(smartJobControllerProvider.notifier).removeProfileEntry(
                            section: section,
                            index: index,
                          );
                      _showMessage(context, '${cvSectionConfigs[section]!.title} updated.');
                    },
                  ),
                const SizedBox(height: 16),
              ],
              SmartJobPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SmartJobSectionHeader(
                      title: 'Ready to generate?',
                      subtitle:
                          'When you generate the CV, SmartJob marks onboarding as complete and opens your CV workspace.',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.go(AppRoute.onboarding),
                            child: const Text('Back'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _generateCv(context, ref, profile),
                            icon: const Icon(LucideIcons.fileCheck2),
                            label: const Text('Generate CV'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSectionComplete(UserProfile profile, CvCollectionSection section) {
    if (section == CvCollectionSection.skills) {
      return profile.skills.isNotEmpty;
    }
    return profile.entriesFor(section).isNotEmpty;
  }

  void _generateCv(BuildContext context, WidgetRef ref, UserProfile profile) {
    final hasCoreIdentity =
        profile.fullName.trim().isNotEmpty &&
        profile.email.trim().isNotEmpty &&
        profile.headline.trim().isNotEmpty;
    final hasProof =
        profile.skills.isNotEmpty ||
        profile.experience.isNotEmpty ||
        profile.projects.isNotEmpty;

    if (!hasCoreIdentity || !hasProof) {
      _showMessage(
        context,
        'Add your name, email, headline, and at least one skill, project, or experience entry first.',
      );
      return;
    }

    ref.read(smartJobControllerProvider.notifier).finalizeBuilderOnboarding();
    context.go(AppRoute.cv);
  }

  Future<void> _showPersonalInfoEditor(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    final nameController = TextEditingController(text: profile.fullName);
    final headlineController = TextEditingController(text: profile.headline);
    final emailController = TextEditingController(text: profile.email);
    final phoneController = TextEditingController(text: profile.phoneNumber);
    final locationController = TextEditingController(text: profile.location);

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
          ),
          child: SmartJobPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SmartJobSectionHeader(
                  title: 'Edit personal info',
                  subtitle: 'These details appear at the top of your generated CV.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: headlineController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Professional summary'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.read(smartJobControllerProvider.notifier).updateProfileIdentity(
                          fullName: nameController.text.trim(),
                          headline: headlineController.text.trim(),
                          email: emailController.text.trim(),
                          phoneNumber: phoneController.text.trim(),
                          location: locationController.text.trim(),
                        );
                    Navigator.of(sheetContext).pop();
                    _showMessage(context, 'Personal info autosaved.');
                  },
                  child: const Text('Save details'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEntryEditor(
    BuildContext context,
    WidgetRef ref, {
    required CvCollectionSection section,
    required CvSectionConfig config,
    String? currentValue,
    int? index,
  }) async {
    final controller = TextEditingController(text: currentValue ?? '');
    final isEditing = currentValue != null && index != null;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
          ),
          child: SmartJobPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SmartJobSectionHeader(
                  title: isEditing ? 'Edit ${config.title}' : 'Add ${config.title}',
                  subtitle: config.editorHint,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: config.maxLines,
                  decoration: InputDecoration(
                    labelText: config.fieldLabel,
                    hintText: config.placeholder,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isEmpty) {
                      return;
                    }

                    if (isEditing) {
                      ref.read(smartJobControllerProvider.notifier).updateProfileEntry(
                            section: section,
                            index: index,
                            value: value,
                          );
                    } else {
                      ref.read(smartJobControllerProvider.notifier).addProfileEntry(section, value);
                    }
                    Navigator.of(sheetContext).pop();
                    _showMessage(context, '${config.title} ${isEditing ? 'saved' : 'added'}.');
                  },
                  child: Text(isEditing ? 'Save changes' : 'Add entry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showChipEditor(
    BuildContext context,
    WidgetRef ref, {
    required CvCollectionSection section,
    required String title,
  }) async {
    final controller = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
          ),
          child: SmartJobPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SmartJobSectionHeader(
                  title: title,
                  subtitle: 'Add one or more values separated by commas.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Values',
                    hintText: 'Flutter, Firebase, Product thinking',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final values = controller.text
                        .split(',')
                        .map((value) => value.trim())
                        .where((value) => value.isNotEmpty);

                    for (final value in values) {
                      ref.read(smartJobControllerProvider.notifier).addProfileEntry(section, value);
                    }

                    Navigator.of(sheetContext).pop();
                    _showMessage(context, '$title updated.');
                  },
                  child: const Text('Add values'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
