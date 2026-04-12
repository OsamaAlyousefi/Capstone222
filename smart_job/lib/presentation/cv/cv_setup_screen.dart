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
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {
    'identity': GlobalKey(),
    'skills': GlobalKey(),
    'experience': GlobalKey(),
    'education': GlobalKey(),
    'projects': GlobalKey(),
  };
  String? _lastJumpedSection;

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
    _scrollController.dispose();
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
    final requestedSection = GoRouterState.of(context).uri.queryParameters['section'];

    if (requestedSection != null && requestedSection != _lastJumpedSection) {
      _lastJumpedSection = requestedSection;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetContext = _sectionKeys[requestedSection]?.currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            alignment: 0.08,
          );
        }
      });
    }

    return Scaffold(
      body: SmartJobBackground(
        child: SmartJobScrollPage(
          controller: _scrollController,
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
                        if (requestedSection != null)
                          SmartJobMetricPill(
                            label: 'jumped to',
                            value: _sectionLabel(requestedSection),
                          ),
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
                    Container(
                      key: _sectionKeys['identity'],
                      child: TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full name')),
                    ),
                    const SizedBox(height: 14),
                    TextField(controller: _headlineController, decoration: const InputDecoration(labelText: 'Headline')),
                    const SizedBox(height: 14),
                    TextField(controller: _taglineController, decoration: const InputDecoration(labelText: 'Tagline')),
                    const SizedBox(height: 14),
                    Container(
                      key: _sectionKeys['skills'],
                      child: TextField(controller: _skillsController, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Skills', helperText: 'Separate skills with commas.')),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      key: _sectionKeys['experience'],
                      child: TextField(controller: _experienceController, minLines: 4, maxLines: 7, decoration: const InputDecoration(labelText: 'Experience', helperText: 'Use blank lines to separate entries.')),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      key: _sectionKeys['education'],
                      child: TextField(controller: _educationController, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Education', helperText: 'Use blank lines to separate entries.')),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      key: _sectionKeys['projects'],
                      child: TextField(controller: _projectsController, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Projects', helperText: 'Use blank lines to separate entries.')),
                    ),
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
    final isOnboardingBuilderFlow = !profile.hasCompletedOnboarding;

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

    if (isOnboardingBuilderFlow) {
      controller.finalizeBuilderOnboarding();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOnboardingBuilderFlow
                ? 'CV draft created. Welcome to SmartJob.'
                : 'CV content updated.',
          ),
        ),
      );
      context.go(isOnboardingBuilderFlow ? AppRoute.main : AppRoute.cv);
    }
  }

  List<String> _commaSeparated(String value) {
    return value.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
  }

  List<String> _multiParagraph(String value) {
    return value.split(RegExp(r'\n\s*\n')).map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
  }

  String _sectionLabel(String section) {
    switch (section) {
      case 'skills':
        return 'Skills';
      case 'experience':
        return 'Experience';
      case 'education':
        return 'Education';
      case 'projects':
        return 'Projects';
      default:
        return 'Identity';
    }
  }
}
