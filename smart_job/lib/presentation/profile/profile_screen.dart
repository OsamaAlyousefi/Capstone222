import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../application/controllers/auth_controller.dart';
import '../../application/controllers/smart_job_controller.dart';
import '../../domain/models/job.dart';
import '../../domain/models/profile.dart';
import '../../router/app_router.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_data_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/smart_job_studio_theme.dart';
import '../shared/widgets/smart_job_ui.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = true;
  String? _error;
  UserProfile? _remoteProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await SupabaseDataService.fetchProfile(
        ref.read(smartJobControllerProvider).profile,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _remoteProfile = profile;
        _error = null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartJobControllerProvider);
    final profile = _remoteProfile ?? state.profile;
    final cv = profile.cvInsight;
    final studioTheme = Theme.of(context).extension<SmartJobStudioTheme>()!;
    final applicationsSent = state.applications.length;
    final profileStrength =
        ((cv.completionScore + cv.atsScore + cv.keywordMatchScore) / 3).round();
    final savedJobs = state.jobs.where((job) => job.isSaved).toList();
    final matchedSavedJobs = savedJobs.where((job) => job.matchScore >= 0.75).length;
    final savedJobMatch = savedJobs.isEmpty
        ? cv.keywordMatchScore
        : ((matchedSavedJobs / savedJobs.length) * 100).round();

    if (_isLoading && _remoteProfile == null && state.profile.email.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _remoteProfile == null && state.profile.email.isEmpty) {
      return Center(child: Text('Error: $_error'));
    }

    return SmartJobScrollPage(
      maxWidth: 1320,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 160),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1040;
          final sidebar = _ProfileSidebar(
            profile: profile,
            applicationsSent: applicationsSent,
            profileStrength: profileStrength,
            cvScore: cv.atsScore,
            studioTheme: studioTheme,
            onEditProfile: () => _showEditProfileSheet(context, ref),
            onViewPublicProfile: () => _showMessage(
              context,
              profile.publicProfileEnabled
                  ? 'Public profile preview is ready for a future web view.'
                  : 'Turn on public profile first to preview your public page.',
            ),
            onDownloadCv: () => context.go(AppRoute.cv),
            onLogout: () async {
              await AuthService.signOut();
              if (!context.mounted) {
                return;
              }
              ref.read(authControllerProvider.notifier).signOut();
              ref.read(smartJobControllerProvider.notifier).resetForLogout();
              context.go(AppRoute.login);
            },
            onDeleteAccount: () async {
              await AuthService.signOut();
              if (!context.mounted) {
                return;
              }
              ref.read(authControllerProvider.notifier).signOut();
              ref.read(smartJobControllerProvider.notifier).deleteAccount();
              context.go(AppRoute.login);
            },
          );

          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionShell(
                title: 'Personal Information',
                subtitle:
                    'Your professional identity, links, and recruiter-facing contact details.',
                trailing: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showEditProfileSheet(context, ref),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit details'),
                    ),
                    TextButton(
                      onPressed: () => _showMessage(
                        context,
                        'Password reset link sent in prototype mode.',
                      ),
                      child: const Text('Reset password'),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, sectionConstraints) {
                    final columns = sectionConstraints.maxWidth >= 860 ? 3 : 2;
                    final fieldItems = [
                      _ProfileFieldData(icon: LucideIcons.mail, label: 'Email', value: profile.email),
                      _ProfileFieldData(icon: LucideIcons.phone, label: 'Phone', value: profile.phoneNumber),
                      _ProfileFieldData(icon: LucideIcons.mapPin, label: 'Location', value: profile.location),
                      _ProfileFieldData(icon: LucideIcons.linkedin, label: 'LinkedIn', value: profile.linkedInUrl),
                      _ProfileFieldData(icon: LucideIcons.github, label: 'GitHub / Portfolio', value: profile.portfolioUrl),
                      _ProfileFieldData(icon: LucideIcons.globe2, label: 'Website', value: profile.websiteUrl),
                    ];

                    return GridView.builder(
                      itemCount: fieldItems.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: sectionConstraints.maxWidth >= 860 ? 1.6 : 1.35,
                      ),
                      itemBuilder: (context, index) => _InfoFieldTile(data: fieldItems[index]),
                    );
                  },
                ),
              ).animate().fade().slideY(begin: 0.04),
              const SizedBox(height: 24),
              _SectionShell(
                title: 'Job Preferences',
                subtitle:
                    'Shape the types of roles, locations, and alerts SmartJob prioritizes for you.',
                trailing: TextButton.icon(
                  onPressed: () => _showJobPreferencesSheet(context, ref),
                  icon: const Icon(LucideIcons.slidersHorizontal, size: 16),
                  label: const Text('Adjust preferences'),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PreferenceCluster(
                      title: 'Desired roles',
                      subtitle: 'SmartJob will rank these roles first in your feed.',
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final role in profile.jobPreferences.targetRoles) Chip(label: Text(role)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, preferenceConstraints) {
                        final stacked = preferenceConstraints.maxWidth < 860;
                        final details = _PreferenceCluster(
                          title: 'Role setup',
                          subtitle: 'Employment type, work mode, salary, and mobility.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PreferenceChipRow(
                                label: 'Employment type',
                                values: profile.jobPreferences.preferredJobTypes.map(jobTypeLabel).toList(),
                              ),
                              const SizedBox(height: 14),
                              _PreferenceChipRow(
                                label: 'Work mode',
                                values: profile.jobPreferences.preferredWorkModes.map(workModeLabel).toList(),
                              ),
                              const SizedBox(height: 14),
                              _PreferenceChipRow(
                                label: 'Preferred locations',
                                values: profile.jobPreferences.preferredLocations,
                              ),
                              const SizedBox(height: 18),
                              _SliderSummary(
                                value: profile.jobPreferences.salaryExpectation,
                                label: profile.jobPreferences.salaryRange,
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _BooleanTag(label: 'Work authorization', enabled: profile.jobPreferences.hasWorkAuthorization),
                                  _BooleanTag(label: 'Open to relocation', enabled: profile.jobPreferences.openToRelocation),
                                ],
                              ),
                            ],
                          ),
                        );
                        final alerts = _JobAlertCard(profile: profile);

                        if (stacked) {
                          return Column(
                            children: [details, const SizedBox(height: 16), alerts],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: details),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: alerts),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ).animate().fade(delay: 80.ms),
              const SizedBox(height: 24),
              _SectionShell(
                title: 'Professional Details',
                subtitle:
                    'Skills, experience, and education that feed your CV and improve job match scores.',
                trailing: TextButton.icon(
                  onPressed: () => context.go(AppRoute.cvSetup),
                  icon: const Icon(LucideIcons.penTool, size: 16),
                  label: const Text('Edit in CV builder'),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SkillsCluster(
                      skills: profile.skills,
                      onAdd: () => _showAddEntrySheet(
                        context,
                        ref,
                        CvCollectionSection.skills,
                        hint: 'e.g. Flutter, Python, Figma',
                      ),
                      onRemove: (index) => ref
                          .read(smartJobControllerProvider.notifier)
                          .removeProfileEntry(
                            section: CvCollectionSection.skills,
                            index: index,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _EntryCluster(
                      title: 'Experience',
                      icon: LucideIcons.briefcase,
                      entries: profile.experience,
                      emptyMessage:
                          'No experience added yet. Tap + Add to start building your work history.',
                      onAdd: () => _showAddEntrySheet(
                        context,
                        ref,
                        CvCollectionSection.experience,
                        hint:
                            'e.g. Flutter Developer at Acme Corp, 2023 – Present',
                      ),
                      onRemove: (index) => ref
                          .read(smartJobControllerProvider.notifier)
                          .removeProfileEntry(
                            section: CvCollectionSection.experience,
                            index: index,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _EntryCluster(
                      title: 'Education',
                      icon: LucideIcons.graduationCap,
                      entries: profile.education,
                      emptyMessage:
                          'No education entries yet. Tap + Add to add your qualifications.',
                      onAdd: () => _showAddEntrySheet(
                        context,
                        ref,
                        CvCollectionSection.education,
                        hint: 'e.g. BSc Computer Science, UAE University, 2026',
                      ),
                      onRemove: (index) => ref
                          .read(smartJobControllerProvider.notifier)
                          .removeProfileEntry(
                            section: CvCollectionSection.education,
                            index: index,
                          ),
                    ),
                  ],
                ),
              ).animate().fade(delay: 120.ms),
              const SizedBox(height: 24),
              _SectionShell(
                title: 'Career Insights',
                subtitle:
                    'A cleaner snapshot of how strong your profile looks to recruiters and matching systems.',
                child: LayoutBuilder(
                  builder: (context, sectionConstraints) {
                    final columns = sectionConstraints.maxWidth >= 980
                        ? 4
                        : sectionConstraints.maxWidth >= 640
                            ? 2
                            : 1;
                    final cards = [
                      _InsightCardData(
                        title: 'Profile strength',
                        value: '$profileStrength%',
                        subtitle: 'Completeness across key sections',
                        color: AppColors.teal,
                        progress: profileStrength / 100,
                      ),
                      _InsightCardData(
                        title: 'ATS readiness',
                        value: '${cv.atsScore}',
                        subtitle: 'Parsing and recruiter readability',
                        color: AppColors.info,
                        progress: cv.atsScore / 100,
                      ),
                      _InsightCardData(
                        title: 'Saved-job fit',
                        value: '$savedJobMatch%',
                        subtitle: 'Alignment against bookmarked roles',
                        color: AppColors.sand,
                        progress: savedJobMatch / 100,
                      ),
                      _InsightCardData(
                        title: 'Skills to add',
                        value: '${cv.missingKeywords.length}',
                        subtitle: cv.missingKeywords.isEmpty
                            ? 'No urgent gaps detected'
                            : cv.missingKeywords.join(', '),
                        color: AppColors.coral,
                        progress: cv.missingKeywords.isEmpty ? 1 : 0.65,
                      ),
                    ];

                    return GridView.builder(
                      itemCount: cards.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: columns == 1 ? 2.2 : 1.18,
                      ),
                      itemBuilder: (context, index) => _InsightMiniCard(data: cards[index]),
                    );
                  },
                ),
              ).animate().fade(delay: 140.ms),
              const SizedBox(height: 24),
              _SectionShell(
                title: 'Security & Privacy',
                subtitle:
                    'Appearance, visibility, exports, and support controls in one place.',
                child: LayoutBuilder(
                  builder: (context, sectionConstraints) {
                    final stacked = sectionConstraints.maxWidth < 920;
                    final appearance = _PreferenceCluster(
                      title: 'Appearance',
                      subtitle: 'Choose how SmartJob looks across your devices.',
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _ThemeChip(
                            label: 'System',
                            selected: profile.themeMode == ThemeMode.system,
                            onTap: () => ref.read(smartJobControllerProvider.notifier).updateThemeMode(ThemeMode.system),
                          ),
                          _ThemeChip(
                            label: 'Light',
                            selected: profile.themeMode == ThemeMode.light,
                            onTap: () => ref.read(smartJobControllerProvider.notifier).updateThemeMode(ThemeMode.light),
                          ),
                          _ThemeChip(
                            label: 'Dark',
                            selected: profile.themeMode == ThemeMode.dark,
                            onTap: () => ref.read(smartJobControllerProvider.notifier).updateThemeMode(ThemeMode.dark),
                          ),
                        ],
                      ),
                    );
                    final privacy = _PreferenceCluster(
                      title: 'Privacy',
                      subtitle: 'Control what SmartJob exposes on public surfaces.',
                      child: Column(
                        children: [
                          SwitchListTile.adaptive(
                            value: profile.publicProfileEnabled,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Public profile'),
                            subtitle: const Text('Allow SmartJob to generate a shareable public profile.'),
                            onChanged: ref.read(smartJobControllerProvider.notifier).updatePublicProfileVisibility,
                          ),
                          SwitchListTile.adaptive(
                            value: profile.hideContactInfo,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Hide contact info'),
                            subtitle: const Text('Mask phone and email on public-facing profile previews.'),
                            onChanged: ref.read(smartJobControllerProvider.notifier).updateHideContactInfo,
                          ),
                          SwitchListTile.adaptive(
                            value: profile.privacyModeEnabled,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Privacy mode'),
                            subtitle: const Text('Reduce visibility of profile activity across recommendation surfaces.'),
                            onChanged: ref.read(smartJobControllerProvider.notifier).updatePrivacyMode,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _showMessage(context, 'Profile export bundle is queued in prototype mode.'),
                            icon: const Icon(LucideIcons.download),
                            label: const Text('Download my data'),
                          ),
                        ],
                      ),
                    );
                    final support = _PreferenceCluster(
                      title: 'Support',
                      subtitle: 'Fast links for help and support contact.',
                      child: Column(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _showMessage(context, 'Help center articles will open here in a future build.'),
                            icon: const Icon(Icons.help_outline),
                            label: const Text('Help center'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _showMessage(context, 'Support email drafted to support@smartjob.app.'),
                            icon: const Icon(LucideIcons.mail),
                            label: const Text('support@smartjob.app'),
                          ),
                        ],
                      ),
                    );

                    if (stacked) {
                      return Column(
                        children: [appearance, const SizedBox(height: 16), privacy, const SizedBox(height: 16), support],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: appearance),
                        const SizedBox(width: 16),
                        Expanded(child: privacy),
                        const SizedBox(width: 16),
                        Expanded(child: support),
                      ],
                    );
                  },
                ),
              ).animate().fade(delay: 200.ms),
            ],
          );

          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [sidebar, const SizedBox(height: 24), content],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 320, child: sidebar),
              const SizedBox(width: 24),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditProfileSheet(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(smartJobControllerProvider).profile;
    final fullNameController = TextEditingController(text: profile.fullName);
    final headlineController = TextEditingController(text: profile.headline);
    final taglineController = TextEditingController(text: profile.tagline);
    final emailController = TextEditingController(text: profile.email);
    final phoneController = TextEditingController(text: profile.phoneNumber);
    final locationController = TextEditingController(text: profile.location);
    final linkedInController = TextEditingController(text: profile.linkedInUrl);
    final portfolioController = TextEditingController(text: profile.portfolioUrl);
    final websiteController = TextEditingController(text: profile.websiteUrl);

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
          child: SmartJobPanel(
            radius: 24,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SmartJobSectionHeader(
                    title: 'Edit profile workspace',
                    subtitle: 'Update the details SmartJob uses across your account and CV.',
                  ),
                  const SizedBox(height: 18),
                  TextField(controller: fullNameController, decoration: const InputDecoration(labelText: 'Full name')),
                  const SizedBox(height: 12),
                  TextField(controller: headlineController, decoration: const InputDecoration(labelText: 'Job title / headline')),
                  const SizedBox(height: 12),
                  TextField(controller: taglineController, decoration: const InputDecoration(labelText: 'Short tagline')),
                  const SizedBox(height: 12),
                  TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 12),
                  TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone number')),
                  const SizedBox(height: 12),
                  TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Location')),
                  const SizedBox(height: 12),
                  TextField(controller: linkedInController, decoration: const InputDecoration(labelText: 'LinkedIn')),
                  const SizedBox(height: 12),
                  TextField(controller: portfolioController, decoration: const InputDecoration(labelText: 'GitHub / Portfolio')),
                  const SizedBox(height: 12),
                  TextField(controller: websiteController, decoration: const InputDecoration(labelText: 'Website')),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: () async {
                      ref.read(smartJobControllerProvider.notifier).updateProfileWorkspace(
                            fullName: fullNameController.text.trim(),
                            headline: headlineController.text.trim(),
                            tagline: taglineController.text.trim(),
                            email: emailController.text.trim(),
                            phoneNumber: phoneController.text.trim(),
                            location: locationController.text.trim(),
                            linkedInUrl: linkedInController.text.trim(),
                            portfolioUrl: portfolioController.text.trim(),
                            websiteUrl: websiteController.text.trim(),
                          );
                      try {
                        await SupabaseDataService.updateProfileWorkspace(
                          fullName: fullNameController.text.trim(),
                          headline: headlineController.text.trim(),
                          phoneNumber: phoneController.text.trim(),
                          location: locationController.text.trim(),
                          linkedInUrl: linkedInController.text.trim(),
                          portfolioUrl: portfolioController.text.trim(),
                          websiteUrl: websiteController.text.trim(),
                        );
                        if (mounted) {
                          setState(() {
                            _remoteProfile = ref.read(smartJobControllerProvider).profile;
                            _error = null;
                          });
                        }
                      } catch (error) {
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $error')),
                        );
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('Save workspace profile'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showJobPreferencesSheet(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(smartJobControllerProvider).profile;
    final roleController = TextEditingController(text: profile.jobPreferences.targetRoles.join(', '));
    final locationsController = TextEditingController(text: profile.jobPreferences.preferredLocations.join(', '));
    var salaryExpectation = profile.jobPreferences.salaryExpectation.toDouble();
    final selectedJobTypes = {...profile.jobPreferences.preferredJobTypes};
    final selectedWorkModes = {...profile.jobPreferences.preferredWorkModes};
    var hasWorkAuthorization = profile.jobPreferences.hasWorkAuthorization;
    var openToRelocation = profile.jobPreferences.openToRelocation;
    var wantsNotifications = profile.jobPreferences.wantsNotifications;
    var alertFrequency = profile.jobPreferences.emailFrequency;
    var pushEnabled = profile.jobPreferences.pushNotificationsEnabled;
    var emailEnabled = profile.jobPreferences.emailNotificationsEnabled;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
              child: SmartJobPanel(
                radius: 24,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SmartJobSectionHeader(
                        title: 'Tune job preferences',
                        subtitle: 'Shape what SmartJob recommends and how often it reaches out.',
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: roleController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Desired roles', hintText: 'Flutter Developer, Product Designer'),
                      ),
                      const SizedBox(height: 12),
                      Text('Employment type', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final type in [JobType.internship, JobType.partTime, JobType.fullTime, JobType.contract])
                            FilterChip(
                              selected: selectedJobTypes.contains(type),
                              label: Text(jobTypeLabel(type)),
                              onSelected: (selected) {
                                setModalState(() {
                                  if (selected) {
                                    selectedJobTypes.add(type);
                                  } else {
                                    selectedJobTypes.remove(type);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('Work mode', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final mode in WorkMode.values)
                            FilterChip(
                              selected: selectedWorkModes.contains(mode),
                              label: Text(workModeLabel(mode)),
                              onSelected: (selected) {
                                setModalState(() {
                                  if (selected) {
                                    selectedWorkModes.add(mode);
                                  } else {
                                    selectedWorkModes.remove(mode);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: locationsController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Preferred locations', hintText: 'Dubai, Remote, Abu Dhabi'),
                      ),
                      const SizedBox(height: 18),
                      Text('Salary expectation', style: Theme.of(context).textTheme.headlineMedium),
                      Slider(
                        value: salaryExpectation,
                        min: 2,
                        max: 20,
                        divisions: 18,
                        label: _salaryRangeLabel(salaryExpectation.round()),
                        onChanged: (value) => setModalState(() => salaryExpectation = value),
                      ),
                      Text(
                        _salaryRangeLabel(salaryExpectation.round()),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.subtext(Theme.of(context).brightness)),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(value: hasWorkAuthorization, contentPadding: EdgeInsets.zero, title: const Text('Authorized to work'), onChanged: (value) => setModalState(() => hasWorkAuthorization = value)),
                      SwitchListTile.adaptive(value: openToRelocation, contentPadding: EdgeInsets.zero, title: const Text('Open to relocation'), onChanged: (value) => setModalState(() => openToRelocation = value)),
                      const Divider(height: 30),
                      SwitchListTile.adaptive(value: wantsNotifications, contentPadding: EdgeInsets.zero, title: const Text('Job alerts'), subtitle: const Text('Receive recommendations and reminder alerts.'), onChanged: (value) => setModalState(() => wantsNotifications = value)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<AlertFrequency>(
                        initialValue: alertFrequency,
                        decoration: const InputDecoration(labelText: 'Email frequency'),
                        items: AlertFrequency.values.map((frequency) => DropdownMenuItem(value: frequency, child: Text(_alertFrequencyLabel(frequency)))).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => alertFrequency = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(value: pushEnabled, contentPadding: EdgeInsets.zero, title: const Text('Push notifications'), onChanged: (value) => setModalState(() => pushEnabled = value)),
                      SwitchListTile.adaptive(value: emailEnabled, contentPadding: EdgeInsets.zero, title: const Text('Email notifications'), onChanged: (value) => setModalState(() => emailEnabled = value)),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: () async {
                          final salary = salaryExpectation.round();
                          ref.read(smartJobControllerProvider.notifier).updateJobPreferences(
                                targetRoles: roleController.text.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList(),
                                preferredLocations: locationsController.text.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList(),
                                preferredJobTypes: selectedJobTypes.toList(),
                                preferredWorkModes: selectedWorkModes.toList(),
                                salaryExpectation: salary,
                                salaryRange: _salaryRangeLabel(salary),
                                hasWorkAuthorization: hasWorkAuthorization,
                                openToRelocation: openToRelocation,
                                wantsNotifications: wantsNotifications,
                                emailFrequency: alertFrequency,
                                pushNotificationsEnabled: pushEnabled,
                                emailNotificationsEnabled: emailEnabled,
                              );
                          try {
                            await SupabaseDataService.updateJobPreferences(
                              targetRoles: roleController.text.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList(),
                              preferredJobTypes: selectedJobTypes.toList(),
                              preferredWorkModes: selectedWorkModes.toList(),
                              preferredLocations: locationsController.text.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList(),
                              emailFrequency: alertFrequency,
                              pushNotificationsEnabled: pushEnabled,
                              emailNotificationsEnabled: emailEnabled,
                            );
                            if (mounted) {
                              setState(() {
                                _remoteProfile = ref.read(smartJobControllerProvider).profile;
                                _error = null;
                              });
                            }
                          } catch (error) {
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $error')),
                            );
                          }
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: const Text('Save job preferences'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddEntrySheet(
    BuildContext context,
    WidgetRef ref,
    CvCollectionSection section, {
    String hint = '',
  }) async {
    final controller = TextEditingController();
    final isSkill = section == CvCollectionSection.skills;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(ctx).bottom + 16,
          ),
          child: SmartJobPanel(
            radius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SmartJobSectionHeader(
                  title: 'Add ${section.label}',
                  subtitle: 'Type the entry and tap Add to save it to your profile.',
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: isSkill ? 1 : 3,
                  decoration: InputDecoration(
                    labelText: hint.isEmpty ? section.label : hint,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final value = controller.text.trim();
                          if (value.isNotEmpty) {
                            ref
                                .read(smartJobControllerProvider.notifier)
                                .addProfileEntry(section, value);
                          }
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

// ─────────────────────────────────────────────────────────────────
// Professional Details widgets
// ─────────────────────────────────────────────────────────────────

class _SkillsCluster extends StatelessWidget {
  const _SkillsCluster({
    required this.skills,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> skills;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return _PreferenceCluster(
      title: 'Skills',
      subtitle: 'Technical and soft skills that appear on your CV and power match scoring.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (skills.isEmpty)
            Text(
              'No skills added yet. Tap + Add skill to get started.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.subtext(brightness),
                  ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < skills.length; i++)
                  Chip(
                    label: Text(skills[i]),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                    onDeleted: () => onRemove(i),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(LucideIcons.plus, size: 14),
            label: const Text('Add skill'),
          ),
        ],
      ),
    );
  }
}

class _EntryCluster extends StatelessWidget {
  const _EntryCluster({
    required this.title,
    required this.icon,
    required this.entries,
    required this.emptyMessage,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final IconData icon;
  final List<String> entries;
  final String emptyMessage;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return _PreferenceCluster(
      title: title,
      subtitle: 'Used in your live CV and for ATS keyword matching.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                emptyMessage,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.subtext(brightness),
                    ),
              ),
            )
          else
            for (var i = 0; i < entries.length; i++) ...[
              _ProfileEntryRow(
                text: entries[i],
                icon: icon,
                onDelete: () => onRemove(i),
              ),
              if (i < entries.length - 1)
                Divider(
                  height: 1,
                  color: AppColors.stroke(brightness),
                ),
            ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(LucideIcons.plus, size: 14),
            label: Text('Add $title'),
          ),
        ],
      ),
    );
  }
}

class _ProfileEntryRow extends StatelessWidget {
  const _ProfileEntryRow({
    required this.text,
    required this.icon,
    required this.onDelete,
  });

  final String text;
  final IconData icon;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                LucideIcons.trash2,
                size: 14,
                color: AppColors.subtext(brightness),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSidebar extends StatelessWidget {
  const _ProfileSidebar({required this.profile, required this.applicationsSent, required this.profileStrength, required this.cvScore, required this.studioTheme, required this.onEditProfile, required this.onViewPublicProfile, required this.onDownloadCv, required this.onLogout, required this.onDeleteAccount});

  final UserProfile profile;
  final int applicationsSent;
  final int profileStrength;
  final int cvScore;
  final SmartJobStudioTheme studioTheme;
  final VoidCallback onEditProfile;
  final VoidCallback onViewPublicProfile;
  final VoidCallback onDownloadCv;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [studioTheme.sidebarGradientTop, studioTheme.sidebarGradientBottom], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: studioTheme.glassBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 30, offset: const Offset(0, 18))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 108,
              height: 108,
              alignment: Alignment.center,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.teal, AppColors.info], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Text(profile.photoLabel, style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 18),
          Text(profile.fullName, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 6),
          Text(profile.jobPreferences.targetRoles.isEmpty ? profile.headline : profile.jobPreferences.targetRoles.first, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(profile.tagline.isEmpty ? profile.headline : profile.tagline, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.subtext(Theme.of(context).brightness))),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _SidebarStatTile(label: 'Applications', value: '$applicationsSent')),
              const SizedBox(width: 12),
              Expanded(child: _SidebarStatTile(label: 'Strength', value: '$profileStrength%')),
              const SizedBox(width: 12),
              Expanded(child: _SidebarStatTile(label: 'CV score', value: '$cvScore')),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(onPressed: onEditProfile, icon: const Icon(Icons.edit_outlined), label: const Text('Edit Profile')),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: onViewPublicProfile, icon: const Icon(Icons.public), label: const Text('View Public Profile')),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: onDownloadCv, icon: const Icon(LucideIcons.download), label: const Text('Download CV')),
          const SizedBox(height: 28),
          Text('Danger zone', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Account-level actions stay tucked away here.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.subtext(Theme.of(context).brightness))),
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: onLogout, icon: const Icon(LucideIcons.logOut), label: const Text('Logout')),
          const SizedBox(height: 8),
          TextButton.icon(onPressed: onDeleteAccount, icon: const Icon(LucideIcons.trash2, color: AppColors.danger), label: const Text('Delete account')),
        ],
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({required this.title, required this.subtitle, required this.child, this.trailing});

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final studioTheme = Theme.of(context).extension<SmartJobStudioTheme>()!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: studioTheme.glassPanel, borderRadius: BorderRadius.circular(24), border: Border.all(color: studioTheme.glassBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [SmartJobSectionHeader(title: title, subtitle: subtitle, trailing: trailing), const SizedBox(height: 20), child],
      ),
    );
  }
}

class _SidebarStatTile extends StatelessWidget {
  const _SidebarStatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface(Theme.of(context).brightness).withValues(alpha: 0.42), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.stroke(Theme.of(context).brightness))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 4), Text(label, style: Theme.of(context).textTheme.bodySmall)]),
    );
  }
}

class _ProfileFieldData {
  const _ProfileFieldData({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;
}

class _InfoFieldTile extends StatelessWidget {
  const _InfoFieldTile({required this.data});

  final _ProfileFieldData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surfaceMuted(Theme.of(context).brightness).withValues(alpha: 0.72), borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.stroke(Theme.of(context).brightness))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)), child: Icon(data.icon, size: 18, color: AppColors.teal)),
          const SizedBox(height: 14),
          Text(data.label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(data.value.trim().isEmpty ? 'Not added yet' : data.value, maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _PreferenceCluster extends StatelessWidget {
  const _PreferenceCluster({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surfaceMuted(Theme.of(context).brightness).withValues(alpha: 0.58), borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.stroke(Theme.of(context).brightness))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 6), Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.subtext(Theme.of(context).brightness))), const SizedBox(height: 14), child]),
    );
  }
}

class _PreferenceChipRow extends StatelessWidget {
  const _PreferenceChipRow({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 8), Wrap(spacing: 10, runSpacing: 10, children: [for (final value in values) Chip(label: Text(value))])]);
  }
}

class _SliderSummary extends StatelessWidget {
  const _SliderSummary({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Salary expectation', style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 8), LinearProgressIndicator(value: value / 20, minHeight: 8, borderRadius: BorderRadius.circular(999), backgroundColor: AppColors.surface(Theme.of(context).brightness), valueColor: const AlwaysStoppedAnimation<Color>(AppColors.teal)), const SizedBox(height: 10), Text(label, style: Theme.of(context).textTheme.bodyLarge)]);
  }
}

class _BooleanTag extends StatelessWidget {
  const _BooleanTag({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: enabled ? AppColors.teal.withValues(alpha: 0.14) : AppColors.surface(Theme.of(context).brightness), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.stroke(Theme.of(context).brightness))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(enabled ? LucideIcons.badgeCheck : LucideIcons.minusCircle, size: 16, color: enabled ? AppColors.teal : AppColors.subtext(Theme.of(context).brightness)), const SizedBox(width: 8), Text(label, style: Theme.of(context).textTheme.bodySmall)]),
    );
  }
}
class _JobAlertCard extends StatelessWidget {
  const _JobAlertCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return _PreferenceCluster(
      title: 'Job Alert Settings',
      subtitle: 'How and when SmartJob reaches out with matching roles.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BooleanTag(label: profile.jobPreferences.wantsNotifications ? 'Alerts on' : 'Alerts paused', enabled: profile.jobPreferences.wantsNotifications),
          const SizedBox(height: 14),
          _InfoLine(icon: LucideIcons.mailOpen, label: 'Email frequency', value: _alertFrequencyLabel(profile.jobPreferences.emailFrequency)),
          const SizedBox(height: 10),
          _InfoLine(icon: LucideIcons.bell, label: 'Push alerts', value: profile.jobPreferences.pushNotificationsEnabled ? 'Enabled' : 'Disabled'),
          const SizedBox(height: 10),
          _InfoLine(icon: LucideIcons.mail, label: 'Email alerts', value: profile.jobPreferences.emailNotificationsEnabled ? 'Enabled' : 'Disabled'),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(children: [Icon(icon, size: 16, color: AppColors.teal), const SizedBox(width: 10), Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)), Text(value, style: Theme.of(context).textTheme.bodyMedium)]);
  }
}

class _InsightCardData {
  const _InsightCardData({required this.title, required this.value, required this.subtitle, required this.color, required this.progress});

  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final double progress;
}

class _InsightMiniCard extends StatelessWidget {
  const _InsightMiniCard({required this.data});

  final _InsightCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surfaceMuted(Theme.of(context).brightness).withValues(alpha: 0.62), borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.stroke(Theme.of(context).brightness))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.title, style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Text(data.value, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Text(data.subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.subtext(Theme.of(context).brightness))),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: data.progress.clamp(0.0, 1.0), minHeight: 8, backgroundColor: AppColors.surface(Theme.of(context).brightness), valueColor: AlwaysStoppedAnimation<Color>(data.color)),
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SmartJobFilterChip(label: label, selected: selected, onTap: onTap);
  }
}

String _salaryRangeLabel(int salaryExpectation) {
  final lower = (salaryExpectation - 2).clamp(1, 18);
  // ignore: prefer_interpolation_to_compose_strings
  return '\$' + lower.toString() + 'k-\$' + salaryExpectation.toString() + 'k / month';
}

String _alertFrequencyLabel(AlertFrequency frequency) {
  return switch (frequency) {
    AlertFrequency.instant => 'Instant',
    AlertFrequency.daily => 'Daily',
    AlertFrequency.weekly => 'Weekly',
  };
}
