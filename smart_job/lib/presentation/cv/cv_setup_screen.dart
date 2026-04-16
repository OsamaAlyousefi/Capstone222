import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../application/controllers/smart_job_controller.dart';
import '../../domain/models/profile.dart';
import '../../router/app_router.dart';
import '../../services/groq_cv_service.dart';
import '../../theme/app_colors.dart';
import '../shared/widgets/smart_job_ui.dart';

class CvSetupScreen extends ConsumerStatefulWidget {
  const CvSetupScreen({super.key});

  @override
  ConsumerState<CvSetupScreen> createState() => _CvSetupScreenState();
}

class _CvSetupScreenState extends ConsumerState<CvSetupScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _paragraphController = TextEditingController();

  // Editable fields — populated by AI, then user can review before saving.
  late final TextEditingController _nameController;
  late final TextEditingController _headlineController;
  late final TextEditingController _taglineController;
  late final TextEditingController _skillsController;
  late final TextEditingController _experienceController;
  late final TextEditingController _educationController;
  late final TextEditingController _projectsController;

  bool _isGenerating = false;
  bool _hasGenerated = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(smartJobControllerProvider).profile;
    _nameController = TextEditingController(text: profile.fullName);
    _headlineController = TextEditingController(text: profile.headline);
    _taglineController = TextEditingController(text: profile.tagline);
    _skillsController =
        TextEditingController(text: profile.skills.join(', '));
    _experienceController =
        TextEditingController(text: profile.experience.join('\n\n'));
    _educationController =
        TextEditingController(text: profile.education.join('\n\n'));
    _projectsController =
        TextEditingController(text: profile.projects.join('\n\n'));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _paragraphController.dispose();
    _nameController.dispose();
    _headlineController.dispose();
    _taglineController.dispose();
    _skillsController.dispose();
    _experienceController.dispose();
    _educationController.dispose();
    _projectsController.dispose();
    super.dispose();
  }

  // ── AI generation ──────────────────────────────────────────────────────

  Future<void> _generate() async {
    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final result = await GroqCvService.generateCvFromText(
        _paragraphController.text.trim(),
      );
      if (!mounted) return;

      _nameController.text = result.fullName;
      _headlineController.text = result.headline;
      _taglineController.text = result.tagline;
      _skillsController.text = result.skills.join(', ');
      _experienceController.text = result.experience.join('\n\n');
      _educationController.text = result.education.join('\n\n');
      _projectsController.text = result.projects.join('\n\n');

      setState(() {
        _hasGenerated = true;
        _isGenerating = false;
      });

      // Scroll down to show the generated fields.
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isGenerating = false;
      });
    }
  }

  // ── Save (same logic as before) ────────────────────────────────────────

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

  // ── Helpers ─────────────────────────────────────────────────────────────

  List<String> _commaSeparated(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<String> _multiParagraph(String value) {
    return value
        .split(RegExp(r'\n\s*\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;
    final charCount = _paragraphController.text.length;
    final canGenerate = charCount >= 100 && !_isGenerating;

    return Scaffold(
      body: SmartJobBackground(
        child: SmartJobScrollPage(
          controller: _scrollController,
          maxWidth: 980,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header ────────────────────────────────────────
              SmartJobPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI CV Builder',
                                style: textTheme.displayMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Describe your background in one paragraph and let AI structure your CV automatically.',
                                style: textTheme.bodyLarge?.copyWith(
                                  color: AppColors.subtext(brightness),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.midnight, AppColors.teal],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            LucideIcons.sparkles,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fade().slideY(begin: 0.04),

              const SizedBox(height: 20),

              // ─── Paragraph input ───────────────────────────────
              SmartJobPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SmartJobSectionHeader(
                      title: 'Tell us about yourself',
                      subtitle:
                          'Write a paragraph covering your name, role, skills, experience, education, and projects. Minimum 100 characters.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _paragraphController,
                      minLines: 8,
                      maxLines: 20,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText:
                            'Example: My name is Sara Ahmed. I am a Flutter developer '
                            'with 3 years of experience. I worked at TechCorp as a '
                            'mobile engineer from 2021 to 2024, building e-commerce '
                            'and fintech apps. I graduated from UAE University with a '
                            'BSc in Computer Science in 2021. My skills include Dart, '
                            'Flutter, Firebase, REST APIs, and UI/UX design. I built '
                            'a project called ShopEase, a full-stack e-commerce app '
                            'with payment integration...',
                        hintMaxLines: 8,
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          '$charCount characters',
                          style: textTheme.bodySmall?.copyWith(
                            color: charCount >= 100
                                ? AppColors.teal
                                : AppColors.subtext(brightness),
                            fontWeight: charCount >= 100
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        if (charCount < 100) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(${100 - charCount} more needed)',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.subtext(brightness),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (charCount >= 100)
                          Icon(LucideIcons.checkCircle2,
                              size: 16, color: AppColors.teal),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Error display
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.alertTriangle,
                                size: 16, color: AppColors.danger),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Generate button
                    ElevatedButton.icon(
                      onPressed: canGenerate ? _generate : null,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(LucideIcons.sparkles),
                      label: Text(
                        _isGenerating
                            ? 'Generating CV...'
                            : _hasGenerated
                                ? 'Regenerate with AI'
                                : 'Generate CV with AI',
                      ),
                    ),
                  ],
                ),
              ).animate().fade(delay: 80.ms),

              const SizedBox(height: 20),

              // ─── Generated fields (review & edit) ──────────────
              SmartJobPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SmartJobSectionHeader(
                      title: _hasGenerated
                          ? 'Review & edit your CV'
                          : 'CV fields',
                      subtitle: _hasGenerated
                          ? 'AI filled these out. Edit anything before saving.'
                          : 'These will be populated after AI generation, or fill them manually.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration:
                          const InputDecoration(labelText: 'Full name'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _headlineController,
                      decoration:
                          const InputDecoration(labelText: 'Headline'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _taglineController,
                      decoration:
                          const InputDecoration(labelText: 'Tagline'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _skillsController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Skills',
                        helperText: 'Separate skills with commas.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _experienceController,
                      minLines: 4,
                      maxLines: 7,
                      decoration: const InputDecoration(
                        labelText: 'Experience',
                        helperText:
                            'Use blank lines to separate entries.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _educationController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Education',
                        helperText:
                            'Use blank lines to separate entries.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _projectsController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Projects',
                        helperText:
                            'Use blank lines to separate entries.',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton(
                          onPressed: _save,
                          child:
                              const Text('Save and return to studio'),
                        ),
                        OutlinedButton(
                          onPressed: () => context.go(AppRoute.cv),
                          child: const Text('Back to CV studio'),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fade(delay: 160.ms),
            ],
          ),
        ),
      ),
    );
  }
}
