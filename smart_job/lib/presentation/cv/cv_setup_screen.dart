import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/controllers/smart_job_controller.dart';
import '../../domain/models/profile.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../shared/widgets/smart_job_ui.dart';

class CvSetupScreen extends ConsumerStatefulWidget {
  const CvSetupScreen({super.key});

  @override
  ConsumerState<CvSetupScreen> createState() => _CvSetupScreenState();
}

class _CvSetupScreenState extends ConsumerState<CvSetupScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _headlineController;
  late final TextEditingController _taglineController;
  late final TextEditingController _skillsController;
  late final TextEditingController _experienceController;
  late final TextEditingController _educationController;
  late final TextEditingController _projectsController;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(smartJobControllerProvider).profile;
    _nameController = TextEditingController(text: profile.fullName);
    _headlineController = TextEditingController(text: profile.headline);
    _taglineController = TextEditingController(text: profile.tagline);
    _skillsController = TextEditingController(text: profile.skills.join(', '));
    _experienceController = TextEditingController(text: profile.experience.join('\n\n'));
    _educationController = TextEditingController(text: profile.education.join('\n\n'));
    _projectsController = TextEditingController(text: profile.projects.join('\n\n'));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _headlineController.dispose();
    _taglineController.dispose();
    _skillsController.dispose();
    _experienceController.dispose();
    _educationController.dispose();
    _projectsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(smartJobControllerProvider.select((state) => state.profile));

    return Scaffold(
      body: SmartJobBackground(
        child: SmartJobScrollPage(
          maxWidth: 980,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SmartJobPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit CV Content', style: Theme.of(context).textTheme.displayMedium),
                    const SizedBox(height: 12),
                    Text(
                      'Refine the core content that feeds your live CV preview. Save once, then jump back into the studio.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.subtext(Theme.of(context).brightness),
                          ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SmartJobMetricPill(label: 'skills', value: '${profile.skills.length}'),
                        SmartJobMetricPill(label: 'experience', value: '${profile.experience.length}'),
                        SmartJobMetricPill(label: 'education', value: '${profile.education.length}'),
                        SmartJobMetricPill(label: 'projects', value: '${profile.projects.length}'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SmartJobPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full name')),
                    const SizedBox(height: 14),
                    TextField(controller: _headlineController, decoration: const InputDecoration(labelText: 'Headline')),
                    const SizedBox(height: 14),
                    TextField(controller: _taglineController, decoration: const InputDecoration(labelText: 'Tagline')),
                    const SizedBox(height: 14),
                    TextField(controller: _skillsController, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Skills', helperText: 'Separate skills with commas.')),
                    const SizedBox(height: 14),
                    TextField(controller: _experienceController, minLines: 4, maxLines: 7, decoration: const InputDecoration(labelText: 'Experience', helperText: 'Use blank lines to separate entries.')),
                    const SizedBox(height: 14),
                    TextField(controller: _educationController, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Education', helperText: 'Use blank lines to separate entries.')),
                    const SizedBox(height: 14),
                    TextField(controller: _projectsController, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Projects', helperText: 'Use blank lines to separate entries.')),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton(
                          onPressed: _save,
                          child: const Text('Save and return to studio'),
                        ),
                        OutlinedButton(
                          onPressed: () => context.go(AppRoute.cv),
                          child: const Text('Back to CV studio'),
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

  void _save() {
    final controller = ref.read(smartJobControllerProvider.notifier);
    final profile = ref.read(smartJobControllerProvider).profile;

    controller.updateProfileWorkspace(
      fullName: _nameController.text.trim(),
      headline: _headlineController.text.trim(),
      tagline: _taglineController.text.trim(),
      email: profile.email,
      phoneNumber: profile.phoneNumber,
      location: profile.location,
      linkedInUrl: profile.linkedInUrl,
      portfolioUrl: profile.portfolioUrl,
      websiteUrl: profile.websiteUrl,
    );
    controller.replaceProfileSectionEntries(
      section: CvCollectionSection.skills,
      values: _commaSeparated(_skillsController.text),
    );
    controller.replaceProfileSectionEntries(
      section: CvCollectionSection.experience,
      values: _multiParagraph(_experienceController.text),
    );
    controller.replaceProfileSectionEntries(
      section: CvCollectionSection.education,
      values: _multiParagraph(_educationController.text),
    );
    controller.replaceProfileSectionEntries(
      section: CvCollectionSection.projects,
      values: _multiParagraph(_projectsController.text),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CV content updated.')),
      );
      context.go(AppRoute.cv);
    }
  }

  List<String> _commaSeparated(String value) {
    return value.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
  }

  List<String> _multiParagraph(String value) {
    return value.split(RegExp(r'\n\s*\n')).map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
  }
}
