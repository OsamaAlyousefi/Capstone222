import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/smart_job_repository.dart';
import '../../domain/models/application.dart';
import '../../domain/models/job.dart';
import '../../domain/models/message.dart';
import '../../domain/models/profile.dart';


class SmartJobState {
  const SmartJobState({
    required this.profile,
    required this.jobs,
    required this.applications,
    required this.messages,
    required this.searchQuery,
    required this.selectedLocation,
    required this.selectedJobType,
    required this.selectedWorkMode,
    required this.selectedExperienceLevel,
    required this.selectedSalaryRange,
    required this.selectedInboxFilter,
  });

  final UserProfile profile;
  final List<Job> jobs;
  final List<JobApplication> applications;
  final List<InboxMessage> messages;
  final String searchQuery;
  final String selectedLocation;
  final JobType? selectedJobType;
  final WorkMode? selectedWorkMode;
  final ExperienceLevel? selectedExperienceLevel;
  final String selectedSalaryRange;
  final MessageFilter selectedInboxFilter;

  SmartJobState copyWith({
    UserProfile? profile,
    List<Job>? jobs,
    List<JobApplication>? applications,
    List<InboxMessage>? messages,
    String? searchQuery,
    String? selectedLocation,
    JobType? selectedJobType,
    bool clearSelectedJobType = false,
    WorkMode? selectedWorkMode,
    bool clearSelectedWorkMode = false,
    ExperienceLevel? selectedExperienceLevel,
    bool clearSelectedExperienceLevel = false,
    String? selectedSalaryRange,
    MessageFilter? selectedInboxFilter,
  }) {
    return SmartJobState(
      profile: profile ?? this.profile,
      jobs: jobs ?? this.jobs,
      applications: applications ?? this.applications,
      messages: messages ?? this.messages,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedLocation: selectedLocation ?? this.selectedLocation,
      selectedJobType:
          clearSelectedJobType ? null : selectedJobType ?? this.selectedJobType,
      selectedWorkMode: clearSelectedWorkMode
          ? null
          : selectedWorkMode ?? this.selectedWorkMode,
      selectedExperienceLevel: clearSelectedExperienceLevel
          ? null
          : selectedExperienceLevel ?? this.selectedExperienceLevel,
      selectedSalaryRange: selectedSalaryRange ?? this.selectedSalaryRange,
      selectedInboxFilter: selectedInboxFilter ?? this.selectedInboxFilter,
    );
  }
}

class SmartJobController extends Notifier<SmartJobState> {
  @override
  SmartJobState build() {
    final repository = ref.read(smartJobRepositoryProvider);
    final sessionEmail = repository.currentSessionEmail();
    if (sessionEmail != null) {
      return _buildStateForAccount(
        repository.loadOrCreateAccount(email: sessionEmail),
      );
    }
    return _buildStateForAccount(repository.initialAccount());
  }

  void registerAccount({
    required String fullName,
    required String email,
  }) {
    final repository = ref.read(smartJobRepositoryProvider);
    final account = repository.createAccount(
      fullName: fullName,
      email: email,
      themeMode: state.profile.themeMode,
    );
    state = _buildStateForAccount(account);
  }

  void loadAccountForLogin(String email) {
    final repository = ref.read(smartJobRepositoryProvider);
    final account = repository.loadOrCreateAccount(
      email: email,
      themeMode: state.profile.themeMode,
    );
    state = _buildStateForAccount(account);
  }

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void setLocationFilter(String value) {
    state = state.copyWith(selectedLocation: value);
  }

  void toggleJobType(JobType type) {
    if (state.selectedJobType == type) {
      state = state.copyWith(clearSelectedJobType: true);
      return;
    }
    state = state.copyWith(selectedJobType: type);
  }

  void toggleWorkMode(WorkMode workMode) {
    if (state.selectedWorkMode == workMode) {
      state = state.copyWith(clearSelectedWorkMode: true);
      return;
    }
    state = state.copyWith(selectedWorkMode: workMode);
  }

  void toggleExperienceLevel(ExperienceLevel level) {
    if (state.selectedExperienceLevel == level) {
      state = state.copyWith(clearSelectedExperienceLevel: true);
      return;
    }
    state = state.copyWith(selectedExperienceLevel: level);
  }

  void setSalaryRange(String value) {
    state = state.copyWith(selectedSalaryRange: value);
  }

  void toggleSaveJob(String jobId) {
    _persistAccount(
      jobs: [
        for (final job in state.jobs)
          if (job.id == jobId)
            job.copyWith(isSaved: !job.isSaved)
          else
            job,
      ],
    );
  }

  void setJobFeedback(String jobId, JobFeedback feedback) {
    _persistAccount(
      jobs: [
        for (final job in state.jobs)
          if (job.id == jobId)
            job.copyWith(feedback: feedback)
          else
            job,
      ],
    );
  }

  void easyApply(Job job) {
    final alreadyExists = state.applications.any((app) => app.jobId == job.id);
    if (alreadyExists) {
      return;
    }

    final newApplication = JobApplication(
      id: 'app_${state.applications.length + 1}',
      jobId: job.id,
      role: job.title,
      company: job.companyName,
      location: job.location,
      status: ApplicationStatus.pending,
      source: job.source,
      logoLabel: job.logoLabel,
      appliedLabel: 'Applied just now',
      note: 'Your SmartJob profile and CV were shared with the recruiter.',
      timeline: const [
        ApplicationTimelineEvent(
          label: 'Application sent',
          caption: 'Shared instantly through SmartJob Easy Apply.',
          dateLabel: 'Now',
          isComplete: true,
        ),
        ApplicationTimelineEvent(
          label: 'Awaiting recruiter update',
          caption: 'We will sync new inbox messages here.',
          dateLabel: 'Live',
          isComplete: false,
        ),
      ],
    );

    final ackMessage = InboxMessage(
      id: 'msg_${state.messages.length + 1}',
      senderName: 'Talent Team',
      senderCompany: job.companyName,
      subject: 'Application received for ${job.title}',
      preview:
          'We received your application through SmartJob and will review it shortly.',
      body:
          'Hello ${state.profile.fullName},\n\nWe received your application for ${job.title}. Our team will review it shortly and you will see status updates in your SmartJob inbox.\n\nRegards,\n${job.companyName} Talent Team',
      timeLabel: 'Now',
      type: MessageType.update,
      applicationId: newApplication.id,
      isUnread: true,
    );

    _persistAccount(
      jobs: [
        for (final currentJob in state.jobs)
          if (currentJob.id == job.id)
            currentJob.copyWith(
              feedback: JobFeedback.interested,
              isSaved: false,
            )
          else
            currentJob,
      ],
      applications: [newApplication, ...state.applications],
      messages: [ackMessage, ...state.messages],
    );
  }

  void setInboxFilter(MessageFilter filter) {
    state = state.copyWith(selectedInboxFilter: filter);
  }

  void markMessageRead(String messageId) {
    _persistAccount(
      messages: [
        for (final message in state.messages)
          if (message.id == messageId)
            message.copyWith(isUnread: false)
          else
            message,
      ],
    );
  }

  void updateThemeMode(ThemeMode mode) {
    _updateProfile(
      (profile) => profile.copyWith(themeMode: mode),
      autosaveLabel: 'Appearance saved just now',
    );
  }

  void updateNotificationPreference(bool enabled) {
    _updateProfile(
      (profile) => profile.copyWith(
        notificationsEnabled: enabled,
        jobPreferences: profile.jobPreferences.copyWith(
          wantsNotifications: enabled,
        ),
      ),
      autosaveLabel: 'Notification preferences updated',
    );
  }

  void updatePrivacyMode(bool enabled) {
    _updateProfile(
      (profile) => profile.copyWith(privacyModeEnabled: enabled),
      autosaveLabel: 'Privacy mode updated',
    );
  }

  void updateCvTemplate(String templateName) {
    _updateProfile(
      (profile) => profile.copyWith(
        cvInsight: profile.cvInsight.copyWith(
          selectedTemplate: templateName,
        ),
      ),
      autosaveLabel: 'Template changed just now',
    );
  }

  void updateHeadline(String headline) {
    _updateProfile(
      (profile) => profile.copyWith(headline: headline),
      autosaveLabel: 'Headline autosaved',
    );
  }

  void completeOnboardingFromUpload({
    required String fileName,
    required List<String> targetRoles,
    required List<String> preferredLocations,
    String remoteStoragePath = '',
  }) {
    _updateProfile(
      (profile) => profile.copyWith(
        hasCompletedOnboarding: true,
        hasUploadedCv: true,
        jobPreferences: profile.jobPreferences.copyWith(
          targetRoles: targetRoles,
          preferredLocations: preferredLocations,
        ),
        cvInsight: profile.cvInsight.copyWith(
          fileName: fileName,
          remoteStoragePath: remoteStoragePath,
          parsedSummary: remoteStoragePath.isNotEmpty
              ? '$fileName is uploaded to your SmartJob cloud storage and connected to this account.'
              : '$fileName is now connected to your SmartJob account. Review the suggestions below and keep refining your strongest sections.',
          highlightedStrengths: remoteStoragePath.isNotEmpty
              ? const [
                  'Real CV upload connected',
                  'Cloud backup enabled',
                  'Ready for AI scoring and export',
                ]
              : const [
                  'Real CV upload connected',
                  'Strong role alignment detected',
                  'Ready for AI scoring and export',
                ],
          missingKeywords: const [
            'State management',
            'Product metrics',
            'Cross-functional delivery',
          ],
        ),
      ),
      autosaveLabel:
          remoteStoragePath.isNotEmpty ? 'CV uploaded and synced just now' : 'CV uploaded just now',
    );
  }

  void completeOnboardingForBuilder({
    required List<String> targetRoles,
    required List<String> preferredLocations,
  }) {
    _updateProfile(
      (profile) => profile.copyWith(
        hasCompletedOnboarding: true,
        hasUploadedCv: false,
        jobPreferences: profile.jobPreferences.copyWith(
          targetRoles: targetRoles,
          preferredLocations: preferredLocations,
        ),
        cvInsight: profile.cvInsight.copyWith(
          fileName: _draftFileName(profile.fullName),
          parsedSummary:
              'Your builder draft is ready. Add experience, projects, and portfolio links to unlock a stronger one-page CV.',
        ),
      ),
      autosaveLabel: 'Builder workspace created',
    );
  }
  void beginBuilderSetup({
    required List<String> targetRoles,
    required List<String> preferredLocations,
  }) {
    _updateProfile(
      (profile) => profile.copyWith(
        hasCompletedOnboarding: false,
        hasUploadedCv: false,
        jobPreferences: profile.jobPreferences.copyWith(
          targetRoles: targetRoles,
          preferredLocations: preferredLocations,
        ),
        cvInsight: profile.cvInsight.copyWith(
          fileName: _draftFileName(profile.fullName),
          parsedSummary:
              'Your SmartJob builder is ready. Add your details and generate a polished CV draft.',
        ),
      ),
      autosaveLabel: 'Builder setup ready',
    );
  }

  void finalizeBuilderOnboarding() {
    _updateProfile(
      (profile) => profile.copyWith(
        hasCompletedOnboarding: true,
        hasUploadedCv: false,
        cvInsight: profile.cvInsight.copyWith(
          fileName: _draftFileName(profile.fullName),
          parsedSummary:
              'Your CV was generated from your SmartJob builder data. Review the preview, switch templates, and keep refining sections anytime.',
        ),
      ),
      autosaveLabel: 'CV generated just now',
    );
  }

  void updateProfileDetails({
    required String fullName,
    required String phoneNumber,
    required String location,
    required String headline,
    String? tagline,
  }) {
    _updateProfile(
      (profile) => profile.copyWith(
        fullName: fullName,
        phoneNumber: phoneNumber,
        location: location,
        headline: headline,
        tagline: tagline ?? profile.tagline,
        photoLabel: _initialsFromName(fullName),
      ),
    );
  }

  void updateProfileIdentity({
    required String fullName,
    required String headline,
    required String email,
    required String phoneNumber,
    required String location,
    String? tagline,
    String? linkedInUrl,
    String? portfolioUrl,
    String? websiteUrl,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    _updateProfile(
      (profile) => profile.copyWith(
        fullName: fullName,
        headline: headline,
        email: normalizedEmail,
        phoneNumber: phoneNumber,
        location: location,
        tagline: tagline ?? profile.tagline,
        linkedInUrl: linkedInUrl ?? profile.linkedInUrl,
        portfolioUrl: portfolioUrl ?? profile.portfolioUrl,
        websiteUrl: websiteUrl ?? profile.websiteUrl,
        links: _composeProfileLinks(
          linkedInUrl: linkedInUrl ?? profile.linkedInUrl,
          portfolioUrl: portfolioUrl ?? profile.portfolioUrl,
          websiteUrl: websiteUrl ?? profile.websiteUrl,
          existingLinks: profile.links,
        ),
        photoLabel: _initialsFromName(fullName),
        smartInboxAlias: '${normalizedEmail.split('@').first}@inbox.smartjob.app',
      ),
      autosaveLabel: 'Personal details autosaved',
    );
  }

  void updateProfileWorkspace({
    required String fullName,
    required String headline,
    required String tagline,
    required String email,
    required String phoneNumber,
    required String location,
    required String linkedInUrl,
    required String portfolioUrl,
    required String websiteUrl,
  }) {
    updateProfileIdentity(
      fullName: fullName,
      headline: headline,
      email: email,
      phoneNumber: phoneNumber,
      location: location,
      tagline: tagline,
      linkedInUrl: linkedInUrl,
      portfolioUrl: portfolioUrl,
      websiteUrl: websiteUrl,
    );
  }

  void updatePublicProfileVisibility(bool enabled) {
    _updateProfile(
      (profile) => profile.copyWith(publicProfileEnabled: enabled),
      autosaveLabel: 'Public profile preferences updated',
    );
  }

  void updateHideContactInfo(bool enabled) {
    _updateProfile(
      (profile) => profile.copyWith(hideContactInfo: enabled),
      autosaveLabel: 'Contact visibility updated',
    );
  }

  void updateJobPreferences({
    required List<String> targetRoles,
    required String salaryRange,
    List<JobType>? preferredJobTypes,
    List<WorkMode>? preferredWorkModes,
    List<String>? preferredLocations,
    int? salaryExpectation,
    bool? hasWorkAuthorization,
    bool? openToRelocation,
    bool? wantsNotifications,
    AlertFrequency? emailFrequency,
    bool? pushNotificationsEnabled,
    bool? emailNotificationsEnabled,
  }) {
    _updateProfile(
      (profile) => profile.copyWith(
        jobPreferences: profile.jobPreferences.copyWith(
          targetRoles: targetRoles,
          salaryRange: salaryRange,
          preferredJobTypes: preferredJobTypes ?? profile.jobPreferences.preferredJobTypes,
          preferredWorkModes: preferredWorkModes ?? profile.jobPreferences.preferredWorkModes,
          preferredLocations: preferredLocations ?? profile.jobPreferences.preferredLocations,
          salaryExpectation: salaryExpectation ?? profile.jobPreferences.salaryExpectation,
          hasWorkAuthorization:
              hasWorkAuthorization ?? profile.jobPreferences.hasWorkAuthorization,
          openToRelocation:
              openToRelocation ?? profile.jobPreferences.openToRelocation,
          wantsNotifications:
              wantsNotifications ?? profile.jobPreferences.wantsNotifications,
          emailFrequency: emailFrequency ?? profile.jobPreferences.emailFrequency,
          pushNotificationsEnabled: pushNotificationsEnabled ??
              profile.jobPreferences.pushNotificationsEnabled,
          emailNotificationsEnabled: emailNotificationsEnabled ??
              profile.jobPreferences.emailNotificationsEnabled,
        ),
      ),
      autosaveLabel: 'Job preferences updated',
    );
  }

  void updateCvStudioCustomization({
    String? templateName,
    String? accentColorHex,
    String? fontFamily,
    List<String>? sectionOrder,
  }) {
    _updateProfile(
      (profile) => profile.copyWith(
        cvInsight: profile.cvInsight.copyWith(
          selectedTemplate: templateName ?? profile.cvInsight.selectedTemplate,
          accentColorHex: accentColorHex ?? profile.cvInsight.accentColorHex,
          fontFamily: fontFamily ?? profile.cvInsight.fontFamily,
          sectionOrder: sectionOrder ?? profile.cvInsight.sectionOrder,
        ),
      ),
      autosaveLabel: 'CV customization autosaved',
    );
  }

  void addProfileEntry(CvCollectionSection section, String value) {
    final sanitized = value.trim();
    if (sanitized.isEmpty) {
      return;
    }

    _updateProfile(
      (profile) => profile.copyWithSection(
        section,
        [...profile.entriesFor(section), sanitized],
      ),
      autosaveLabel: '${section.label} updated',
    );
  }

  void updateProfileEntry({
    required CvCollectionSection section,
    required int index,
    required String value,
  }) {
    final sanitized = value.trim();
    if (sanitized.isEmpty) {
      return;
    }

    _updateProfile(
      (profile) {
        final entries = [...profile.entriesFor(section)];
        if (index < 0 || index >= entries.length) {
          return profile;
        }
        entries[index] = sanitized;
        return profile.copyWithSection(section, entries);
      },
      autosaveLabel: '${section.label} entry saved',
    );
  }

  void removeProfileEntry({
    required CvCollectionSection section,
    required int index,
  }) {
    _updateProfile(
      (profile) {
        final entries = [...profile.entriesFor(section)];
        if (index < 0 || index >= entries.length) {
          return profile;
        }
        entries.removeAt(index);
        return profile.copyWithSection(section, entries);
      },
      autosaveLabel: '${section.label} updated',
    );
  }

  void replaceProfileSectionEntries({
    required CvCollectionSection section,
    required List<String> values,
  }) {
    _updateProfile(
      (profile) => profile.copyWithSection(section, _sanitizeEntries(values)),
      autosaveLabel: '${section.label} updated',
    );
  }

  void resetForLogout() {
    final repository = ref.read(smartJobRepositoryProvider);
    state = _buildStateForAccount(
      repository.initialAccount(
        themeMode: state.profile.themeMode,
      ),
    );
  }

  void deleteAccount() {
    final repository = ref.read(smartJobRepositoryProvider);
    repository.deleteAccount(state.profile.email);
    state = _buildStateForAccount(
      repository.initialAccount(
        themeMode: state.profile.themeMode,
      ),
    );
  }

  void _updateProfile(
    UserProfile Function(UserProfile profile) update, {
    String autosaveLabel = 'Autosaved just now',
  }) {
    final previousEmail = state.profile.email;
    final nextProfile = _refreshProfile(
      update(state.profile),
      autosaveLabel: autosaveLabel,
    );
    _persistAccount(
      profile: nextProfile,
      previousEmail: previousEmail,
    );
  }

  SmartJobState _buildStateForAccount(SmartJobAccountData account) {
    final repository = ref.read(smartJobRepositoryProvider);
    final hydratedProfile = _refreshProfile(
      account.profile,
      autosaveLabel: account.profile.cvInsight.lastUpdatedLabel,
    );
    final hydratedAccount = account.copyWith(profile: hydratedProfile);
    repository.saveAccount(hydratedAccount);

    return SmartJobState(
      profile: hydratedProfile,
      jobs: hydratedAccount.jobs,
      applications: hydratedAccount.applications,
      messages: hydratedAccount.messages,
      searchQuery: '',
      selectedLocation: 'All locations',
      selectedJobType: null,
      selectedWorkMode: null,
      selectedExperienceLevel: null,
      selectedSalaryRange: 'Any salary',
      selectedInboxFilter: MessageFilter.all,
    );
  }

  void _persistAccount({
    UserProfile? profile,
    List<Job>? jobs,
    List<JobApplication>? applications,
    List<InboxMessage>? messages,
    String? previousEmail,
  }) {
    final repository = ref.read(smartJobRepositoryProvider);
    final nextState = state.copyWith(
      profile: profile,
      jobs: jobs,
      applications: applications,
      messages: messages,
    );

    repository.saveAccount(
      _accountDataFromState(nextState),
      previousEmail: previousEmail,
    );
    state = nextState;
  }

  SmartJobAccountData _accountDataFromState(SmartJobState source) {
    return SmartJobAccountData(
      profile: source.profile,
      jobs: source.jobs,
      applications: source.applications,
      messages: source.messages,
    );
  }

  UserProfile _refreshProfile(
    UserProfile profile, {
    required String autosaveLabel,
  }) {
    final requiredSections = <String, bool>{
      'Personal info':
          profile.fullName.trim().isNotEmpty &&
              profile.email.trim().isNotEmpty &&
              profile.headline.trim().isNotEmpty,
      'Education': profile.education.isNotEmpty,
      'Experience': profile.experience.isNotEmpty,
      'Projects': profile.projects.isNotEmpty,
      'Skills': profile.skills.isNotEmpty,
      'Certifications': profile.certifications.isNotEmpty,
      'Languages': profile.languages.isNotEmpty,
      'Links': _profileLinks(profile).isNotEmpty,
      'Awards': profile.awards.isNotEmpty,
      'Volunteer work': profile.volunteerWork.isNotEmpty,
    };

    final completedCount =
        requiredSections.values.where((isComplete) => isComplete).length;
    final completionScore = ((completedCount / requiredSections.length) * 100)
        .round()
        .clamp(profile.hasUploadedCv ? 74 : 12, 98);

    final atsScore = (48 +
            (completedCount * 4) +
            (math.min(profile.skills.length, 8) * 3) +
            (profile.projects.isNotEmpty ? 5 : 0) +
            (_profileLinks(profile).isNotEmpty ? 4 : 0))
        .clamp(32, 98);

    final keywordMatchScore = (40 +
            (math.min(profile.skills.length, 8) * 4) +
            (math.min(profile.jobPreferences.targetRoles.length, 3) * 5) +
            (profile.experience.isNotEmpty ? 8 : 0) +
            (profile.certifications.isNotEmpty ? 5 : 0))
        .clamp(28, 98);

    final missingSections = requiredSections.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .take(3)
        .toList();

    final improvementTips = <String>[
      if (profile.experience.isEmpty)
        'Add one experience entry with action verbs, tools used, and measurable outcomes.',
      if (profile.projects.isEmpty)
        'Show one project that proves how you ship, test, or design real work.',
      if (_profileLinks(profile).isEmpty)
        'Add LinkedIn, GitHub, or portfolio links so recruiters can validate your work fast.',
      if (profile.awards.isEmpty)
        'Awards and achievements help students show proof when experience is still growing.',
      if (profile.skills.length < 5)
        'Expand your skills section with tools, frameworks, and strengths mentioned in job descriptions.',
      if (profile.hasUploadedCv)
        'Review the parsed upload and tighten any generic bullet points before exporting.',
      ...profile.jobPreferences.targetRoles.take(2).map(
            (role) => 'Tailor one project bullet to the language used in $role roles.',
          ),
    ];

    final missingKeywords = _suggestedKeywords(profile);
    final highlightedStrengths = _highlightedStrengths(profile);

    final summary = profile.hasUploadedCv
        ? profile.cvInsight.remoteStoragePath.isNotEmpty
            ? 'Your uploaded CV is backed up to SmartJob cloud storage and synced across supported devices. Keep refining sections below to improve ATS readability and recruiter confidence.'
            : 'Your uploaded CV is connected to SmartJob. Keep refining sections below to improve ATS readability and recruiter confidence.'
        : profile.hasCvDraft
            ? 'Your SmartJob builder is turning profile sections into a polished CV draft. Complete the missing areas to reach a recruiter-ready score.'
            : 'Start with skills, projects, and one experience entry to turn this draft into a stronger one-page CV.';

    final draftFileName = profile.hasUploadedCv
        ? profile.cvInsight.fileName
        : _draftFileName(profile.fullName);

    return profile.copyWith(
      cvInsight: profile.cvInsight.copyWith(
        fileName: draftFileName,
        lastUpdatedLabel: autosaveLabel,
        completionScore: completionScore,
        atsScore: atsScore,
        keywordMatchScore: keywordMatchScore,
        missingSections: missingSections,
        improvementTips: improvementTips.take(4).toList(),
        missingKeywords: missingKeywords,
        highlightedStrengths: highlightedStrengths,
        parsedSummary: summary,
        lastEditedAtIso: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  List<String> _sanitizeEntries(List<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  List<String> _highlightedStrengths(UserProfile profile) {
    final strengths = <String>[
      ...profile.skills.take(2),
      if (profile.projects.isNotEmpty) 'Project-backed profile',
      if (_profileLinks(profile).isNotEmpty) 'Portfolio visibility',
      if (profile.certifications.isNotEmpty) 'Verified learning signals',
      if (profile.volunteerWork.isNotEmpty) 'Community impact',
    ];

    if (strengths.isEmpty) {
      return const [
        'Builder draft ready',
        'Career profile in progress',
        'Guided section suggestions',
      ];
    }

    return strengths.take(3).toList();
  }

  List<String> _profileLinks(UserProfile profile) {
    return _composeProfileLinks(
      linkedInUrl: profile.linkedInUrl,
      portfolioUrl: profile.portfolioUrl,
      websiteUrl: profile.websiteUrl,
      existingLinks: profile.links,
    );
  }

  List<String> _composeProfileLinks({
    required String linkedInUrl,
    required String portfolioUrl,
    required String websiteUrl,
    required List<String> existingLinks,
  }) {
    final prioritizedLinks = [
      linkedInUrl.trim(),
      portfolioUrl.trim(),
      websiteUrl.trim(),
      ...existingLinks.map((link) => link.trim()),
    ];

    final uniqueLinks = <String>[];
    for (final link in prioritizedLinks) {
      if (link.isEmpty || uniqueLinks.contains(link)) {
        continue;
      }
      uniqueLinks.add(link);
    }
    return uniqueLinks;
  }
  List<String> _suggestedKeywords(UserProfile profile) {
    final desiredRoles = profile.jobPreferences.targetRoles.join(' ').toLowerCase();
    final suggestions = <String>{
      'Communication',
      if (desiredRoles.contains('flutter') || desiredRoles.contains('mobile'))
        'State management',
      if (desiredRoles.contains('flutter') || desiredRoles.contains('mobile'))
        'REST APIs',
      if (desiredRoles.contains('designer') || desiredRoles.contains('ux'))
        'User testing',
      if (desiredRoles.contains('designer') || desiredRoles.contains('ux'))
        'Design systems',
      if (profile.projects.isEmpty) 'Case study writing',
      if (profile.experience.isEmpty) 'Cross-functional delivery',
    };

    return suggestions
        .where(
          (keyword) => !profile.skills.any(
            (skill) => skill.toLowerCase().contains(keyword.toLowerCase()),
          ),
        )
        .take(3)
        .toList();
  }

  String _initialsFromName(String value) {
    final parts =
        value.split(' ').where((part) => part.trim().isNotEmpty).take(2);
    final initials = parts.map((part) => part[0].toUpperCase()).join();
    return initials.isEmpty ? 'SJ' : initials;
  }

  String _draftFileName(String fullName) {
    final normalizedName = fullName.trim().isEmpty
        ? 'SmartJob'
        : fullName.trim().replaceAll(RegExp(r'\s+'), '_');
    return '${normalizedName}_CV_Draft.pdf';
  }
}

final smartJobControllerProvider =
    NotifierProvider<SmartJobController, SmartJobState>(
  SmartJobController.new,
);

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(
    smartJobControllerProvider.select((state) => state.profile.themeMode),
  );
});

final filteredJobsProvider = Provider<List<Job>>((ref) {
  final state = ref.watch(smartJobControllerProvider);
  return state.jobs.where((job) {
    final matchesQuery = state.searchQuery.isEmpty ||
        '${job.title} ${job.companyName} ${job.skills.join(' ')}'
            .toLowerCase()
            .contains(state.searchQuery.toLowerCase());

    final matchesLocation = state.selectedLocation == 'All locations' ||
        job.location.toLowerCase().contains(state.selectedLocation.toLowerCase());

    final matchesJobType =
        state.selectedJobType == null || job.jobType == state.selectedJobType;

    final matchesWorkMode =
        state.selectedWorkMode == null || job.workMode == state.selectedWorkMode;

    final matchesLevel = state.selectedExperienceLevel == null ||
        job.experienceLevel == state.selectedExperienceLevel;

    final matchesSalary = state.selectedSalaryRange == 'Any salary' ||
        job.salary.contains(state.selectedSalaryRange);

    return matchesQuery &&
        matchesLocation &&
        matchesJobType &&
        matchesWorkMode &&
        matchesLevel &&
        matchesSalary;
  }).toList();
});

final recommendedJobsProvider = Provider<List<Job>>((ref) {
  final profile = ref.watch(smartJobControllerProvider.select((s) => s.profile));
  final jobs = [...ref.watch(filteredJobsProvider)];

  final preferredRoles = profile.jobPreferences.targetRoles;
  final preferredModes = profile.jobPreferences.preferredWorkModes;

  jobs.sort((a, b) {
    final aRoleBoost = preferredRoles.any(
      (role) =>
          a.title.toLowerCase().contains(role.toLowerCase().split(' ').first),
    )
        ? 0.06
        : 0.0;
    final bRoleBoost = preferredRoles.any(
      (role) =>
          b.title.toLowerCase().contains(role.toLowerCase().split(' ').first),
    )
        ? 0.06
        : 0.0;

    final aModeBoost = preferredModes.contains(a.workMode) ? 0.03 : -0.03;
    final bModeBoost = preferredModes.contains(b.workMode) ? 0.03 : -0.03;

    final aFeedbackBoost = switch (a.feedback) {
      JobFeedback.interested => 0.12,
      JobFeedback.notInterested => -0.18,
      JobFeedback.none => 0.0,
    };
    final bFeedbackBoost = switch (b.feedback) {
      JobFeedback.interested => 0.12,
      JobFeedback.notInterested => -0.18,
      JobFeedback.none => 0.0,
    };

    final aScore = a.matchScore + aRoleBoost + aModeBoost + aFeedbackBoost;
    final bScore = b.matchScore + bRoleBoost + bModeBoost + bFeedbackBoost;
    return bScore.compareTo(aScore);
  });

  return jobs.take(4).toList();
});

final savedJobsProvider = Provider<List<Job>>((ref) {
  return ref
      .watch(smartJobControllerProvider.select((state) => state.jobs))
      .where((job) => job.isSaved)
      .toList();
});

final inboxMessagesProvider = Provider<List<InboxMessage>>((ref) {
  final state = ref.watch(smartJobControllerProvider);
  final messages = state.messages;

  switch (state.selectedInboxFilter) {
    case MessageFilter.all:
      return messages;
    case MessageFilter.important:
      return messages.where((message) => message.isImportant).toList();
    case MessageFilter.unread:
      return messages.where((message) => message.isUnread).toList();
    case MessageFilter.interviews:
      return messages
          .where((message) => message.type == MessageType.interview)
          .toList();
  }
});

final applicationStatsProvider = Provider<Map<ApplicationStatus, int>>((ref) {
  final applications =
      ref.watch(smartJobControllerProvider.select((state) => state.applications));
  return {
    for (final status in ApplicationStatus.values)
      status: applications.where((app) => app.status == status).length,
  };
});



















