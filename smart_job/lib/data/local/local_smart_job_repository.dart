import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/models/application.dart';
import '../../domain/models/job.dart';
import '../../domain/models/message.dart';
import '../../domain/models/profile.dart';
import '../database/smart_job_database.dart';
import '../mock/mock_smart_job_repository.dart';
import '../remote/smart_job_remote_sync.dart';
import '../repositories/smart_job_repository.dart';

class LocalSmartJobRepository implements SmartJobRepository {
  LocalSmartJobRepository(
    this._database, {
    SmartJobRemoteSync? remoteSync,
  }) : _remoteSync = remoteSync;

  final SmartJobDatabase _database;
  final SmartJobRemoteSync? _remoteSync;
  final MockSmartJobRepository _seedRepository = const MockSmartJobRepository();

  @override
  SmartJobAccountData initialAccount({ThemeMode themeMode = ThemeMode.system}) {
    final profile = _seedRepository.initialProfile().copyWith(themeMode: themeMode);
    return SmartJobAccountData(
      profile: profile,
      jobs: _seedRepository.jobs(),
      applications: _seedRepository.applications(),
      messages: _seedRepository.messages(),
    );
  }

  @override
  SmartJobAccountData loadOrCreateAccount({
    required String email,
    String? fullName,
    ThemeMode? themeMode,
  }) {
    final normalizedEmail = _normalizeEmail(email);
    final stored = _database.readAccount(normalizedEmail);
    if (stored != null) {
      return _accountFromMap(stored);
    }

    final created = _newAccountData(
      email: normalizedEmail,
      fullName: fullName,
      themeMode: themeMode,
    );
    saveAccount(created);
    return created;
  }

  @override
  SmartJobAccountData createAccount({
    required String fullName,
    required String email,
    ThemeMode? themeMode,
  }) {
    final created = _newAccountData(
      email: _normalizeEmail(email),
      fullName: fullName,
      themeMode: themeMode,
    );
    saveAccount(created);
    return created;
  }

  @override
  void saveAccount(
    SmartJobAccountData account, {
    String? previousEmail,
  }) {
    final normalizedAccount = _normalizedAccount(account);
    final normalizedCurrentEmail = normalizedAccount.profile.email;
    final accountMap = _accountToMap(normalizedAccount);

    if (previousEmail != null) {
      final normalizedPreviousEmail = _normalizeEmail(previousEmail);
      if (normalizedPreviousEmail != normalizedCurrentEmail) {
        _database.deleteAccount(normalizedPreviousEmail);
        unawaited(_deleteAccountFromRemote(normalizedPreviousEmail));
      }
    }

    _database.writeAccount(normalizedCurrentEmail, accountMap);
    unawaited(_pushAccountToRemote(normalizedAccount, accountMap));
  }

  @override
  void deleteAccount(String email) {
    final normalizedEmail = _normalizeEmail(email);
    _database.deleteAccount(normalizedEmail);
    unawaited(_deleteAccountFromRemote(normalizedEmail));
  }

  @override
  String? currentSessionEmail() => _database.currentSessionEmail();

  @override
  void saveCurrentSessionEmail(String email) {
    _database.saveCurrentSessionEmail(email);
  }

  @override
  void clearCurrentSession() {
    _database.clearCurrentSession();
  }

  SmartJobAccountData cacheRemoteAccount(Map<String, dynamic> accountMap) {
    final account = _normalizedAccount(_accountFromMap(accountMap));
    _database.writeAccount(account.profile.email, _accountToMap(account));
    return account;
  }

  SmartJobAccountData _newAccountData({
    required String email,
    String? fullName,
    ThemeMode? themeMode,
  }) {
    final resolvedName =
        fullName != null && fullName.trim().isNotEmpty ? fullName.trim() : _nameFromEmail(email);

    final profile = _seedRepository.initialProfile().copyWith(
          fullName: resolvedName,
          email: email,
          phoneNumber: '',
          location: '',
          headline: 'Flutter developer building polished, recruiter-ready product experiences.',
          tagline: 'SmartJob candidate workspace',
          photoLabel: _initialsFromName(resolvedName),
          smartInboxAlias: '${email.split('@').first}@inbox.smartjob.app',
          hasCompletedOnboarding: false,
          hasUploadedCv: false,
          skills: const [],
          education: const [],
          experience: const [],
          certifications: const [],
          projects: const [],
          languages: const [],
          links: const [],
          awards: const [],
          volunteerWork: const [],
          interests: const [],
          linkedInUrl: '',
          portfolioUrl: '',
          websiteUrl: '',
          themeMode: themeMode ?? ThemeMode.system,
          cvInsight: const CvInsight(
            fileName: 'SmartJob_CV_Draft.pdf',
            lastUpdatedLabel: 'Draft ready to build',
            completionScore: 18,
            atsScore: 54,
            keywordMatchScore: 42,
            missingSections: ['Experience', 'Projects', 'Skills'],
            improvementTips: [
              'Start with your strongest project and add the tools you used.',
              'Turn coursework into proof of impact with outcomes and metrics.',
              'Add links to GitHub, LinkedIn, or a portfolio for faster shortlisting.',
            ],
            missingKeywords: ['State management', 'REST APIs', 'User testing'],
            highlightedStrengths: [
              'Student-friendly builder',
              'Structured profile guidance',
              'ATS scoring support',
            ],
            selectedTemplate: 'Classic Black & White Professional',
            parsedSummary:
                'Your SmartJob CV draft is ready. Add sections to improve ATS strength and recruiter trust.',
            remoteStoragePath: '',
            uploadedCvBase64: '',
            uploadedCvMimeType: '',
            accentColorHex: '#5D8CC3',
            fontFamily: 'Inter',
            sectionOrder: defaultCvSectionOrder,
            lastEditedAtIso: '',
          ),
        );

    return SmartJobAccountData(
      profile: profile,
      jobs: _seedRepository.jobs(),
      applications: const [],
      messages: const [],
    );
  }

  Future<void> _pushAccountToRemote(
    SmartJobAccountData account,
    Map<String, dynamic> accountMap,
  ) async {
    if (_remoteSync == null) {
      return;
    }

    try {
      await _remoteSync.pushAccount(
        email: account.profile.email,
        fullName: account.profile.fullName,
        accountData: accountMap,
      );
    } catch (_) {
      // Keep the app usable offline even if remote sync is unavailable.
    }
  }

  Future<void> _deleteAccountFromRemote(String email) async {
    if (_remoteSync == null) {
      return;
    }

    try {
      await _remoteSync.deleteAccount(email);
    } catch (_) {
      // Local deletion should still succeed if remote cleanup fails.
    }
  }

  SmartJobAccountData _normalizedAccount(SmartJobAccountData account) {
    final normalizedEmail = _normalizeEmail(account.profile.email);
    if (normalizedEmail == account.profile.email) {
      return account;
    }

    return account.copyWith(
      profile: account.profile.copyWith(email: normalizedEmail),
    );
  }

  Map<String, dynamic> _accountToMap(SmartJobAccountData account) {
    return {
      'profile': _profileToMap(account.profile),
      'jobs': account.jobs.map(_jobToMap).toList(),
      'applications': account.applications.map(_applicationToMap).toList(),
      'messages': account.messages.map(_messageToMap).toList(),
    };
  }

  SmartJobAccountData _accountFromMap(Map<String, dynamic> map) {
    return SmartJobAccountData(
      profile: _profileFromMap(map['profile'] as Map<String, dynamic>),
      jobs: (map['jobs'] as List<dynamic>? ?? const [])
          .map((item) => _jobFromMap(item as Map<String, dynamic>))
          .toList(),
      applications: (map['applications'] as List<dynamic>? ?? const [])
          .map((item) => _applicationFromMap(item as Map<String, dynamic>))
          .toList(),
      messages: (map['messages'] as List<dynamic>? ?? const [])
          .map((item) => _messageFromMap(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> _profileToMap(UserProfile profile) {
    return {
      'fullName': profile.fullName,
      'email': profile.email,
      'phoneNumber': profile.phoneNumber,
      'location': profile.location,
      'headline': profile.headline,
      'tagline': profile.tagline,
      'photoLabel': profile.photoLabel,
      'smartInboxAlias': profile.smartInboxAlias,
      'hasCompletedOnboarding': profile.hasCompletedOnboarding,
      'hasUploadedCv': profile.hasUploadedCv,
      'skills': profile.skills,
      'education': profile.education,
      'experience': profile.experience,
      'certifications': profile.certifications,
      'projects': profile.projects,
      'languages': profile.languages,
      'links': profile.links,
      'awards': profile.awards,
      'volunteerWork': profile.volunteerWork,
      'interests': profile.interests,
      'linkedInUrl': profile.linkedInUrl,
      'portfolioUrl': profile.portfolioUrl,
      'websiteUrl': profile.websiteUrl,
      'jobPreferences': {
        'targetRoles': profile.jobPreferences.targetRoles,
        'preferredLocations': profile.jobPreferences.preferredLocations,
        'preferredWorkModes': profile.jobPreferences.preferredWorkModes
            .map((mode) => mode.name)
            .toList(),
        'preferredJobTypes': profile.jobPreferences.preferredJobTypes
            .map((jobType) => jobType.name)
            .toList(),
        'preferredLevels': profile.jobPreferences.preferredLevels
            .map((level) => level.name)
            .toList(),
        'salaryRange': profile.jobPreferences.salaryRange,
        'salaryExpectation': profile.jobPreferences.salaryExpectation,
        'wantsNotifications': profile.jobPreferences.wantsNotifications,
        'emailFrequency': profile.jobPreferences.emailFrequency.name,
        'pushNotificationsEnabled': profile.jobPreferences.pushNotificationsEnabled,
        'emailNotificationsEnabled': profile.jobPreferences.emailNotificationsEnabled,
        'hasWorkAuthorization': profile.jobPreferences.hasWorkAuthorization,
        'openToRelocation': profile.jobPreferences.openToRelocation,
      },
      'cvInsight': {
        'fileName': profile.cvInsight.fileName,
        'lastUpdatedLabel': profile.cvInsight.lastUpdatedLabel,
        'completionScore': profile.cvInsight.completionScore,
        'atsScore': profile.cvInsight.atsScore,
        'keywordMatchScore': profile.cvInsight.keywordMatchScore,
        'missingSections': profile.cvInsight.missingSections,
        'improvementTips': profile.cvInsight.improvementTips,
        'missingKeywords': profile.cvInsight.missingKeywords,
        'highlightedStrengths': profile.cvInsight.highlightedStrengths,
        'selectedTemplate': profile.cvInsight.selectedTemplate,
        'parsedSummary': profile.cvInsight.parsedSummary,
        'remoteStoragePath': profile.cvInsight.remoteStoragePath,
        'uploadedCvBase64': profile.cvInsight.uploadedCvBase64,
        'uploadedCvMimeType': profile.cvInsight.uploadedCvMimeType,
        'accentColorHex': profile.cvInsight.accentColorHex,
        'fontFamily': profile.cvInsight.fontFamily,
        'sectionOrder': profile.cvInsight.sectionOrder,
        'lastEditedAtIso': profile.cvInsight.lastEditedAtIso,
      },
      'themeMode': _themeModeToString(profile.themeMode),
      'notificationsEnabled': profile.notificationsEnabled,
      'privacyModeEnabled': profile.privacyModeEnabled,
      'publicProfileEnabled': profile.publicProfileEnabled,
      'hideContactInfo': profile.hideContactInfo,
    };
  }

  UserProfile _profileFromMap(Map<String, dynamic> map) {
    final jobPreferences = map['jobPreferences'] as Map<String, dynamic>? ?? const {};
    final cvInsight = map['cvInsight'] as Map<String, dynamic>? ?? const {};

    final decodedSectionOrder = _stringList(cvInsight['sectionOrder']);

    return UserProfile(
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      location: map['location'] as String? ?? '',
      headline: map['headline'] as String? ?? '',
      tagline: map['tagline'] as String? ?? '',
      photoLabel: map['photoLabel'] as String? ?? 'SJ',
      smartInboxAlias: map['smartInboxAlias'] as String? ?? '',
      hasCompletedOnboarding: map['hasCompletedOnboarding'] as bool? ?? false,
      hasUploadedCv: map['hasUploadedCv'] as bool? ?? false,
      skills: _stringList(map['skills']),
      education: _stringList(map['education']),
      experience: _stringList(map['experience']),
      certifications: _stringList(map['certifications']),
      projects: _stringList(map['projects']),
      languages: _stringList(map['languages']),
      links: _stringList(map['links']),
      awards: _stringList(map['awards']),
      volunteerWork: _stringList(map['volunteerWork']),
      interests: _stringList(map['interests']),
      linkedInUrl: map['linkedInUrl'] as String? ?? '',
      portfolioUrl: map['portfolioUrl'] as String? ?? '',
      websiteUrl: map['websiteUrl'] as String? ?? '',
      jobPreferences: JobPreferences(
        targetRoles: _stringList(jobPreferences['targetRoles']),
        preferredLocations: _stringList(jobPreferences['preferredLocations']),
        preferredWorkModes: (jobPreferences['preferredWorkModes'] as List<dynamic>? ?? const [])
            .map((mode) => WorkMode.values.byName(mode as String))
            .toList(),
        preferredJobTypes: (jobPreferences['preferredJobTypes'] as List<dynamic>? ?? const [])
            .map((jobType) => JobType.values.byName(jobType as String))
            .toList(),
        preferredLevels: (jobPreferences['preferredLevels'] as List<dynamic>? ?? const [])
            .map((level) => ExperienceLevel.values.byName(level as String))
            .toList(),
        salaryRange: jobPreferences['salaryRange'] as String? ?? '',
        salaryExpectation: jobPreferences['salaryExpectation'] as int? ?? 6,
        wantsNotifications: jobPreferences['wantsNotifications'] as bool? ?? true,
        emailFrequency: AlertFrequency.values.byName(
          jobPreferences['emailFrequency'] as String? ?? AlertFrequency.daily.name,
        ),
        pushNotificationsEnabled: jobPreferences['pushNotificationsEnabled'] as bool? ?? true,
        emailNotificationsEnabled: jobPreferences['emailNotificationsEnabled'] as bool? ?? true,
        hasWorkAuthorization: jobPreferences['hasWorkAuthorization'] as bool? ?? true,
        openToRelocation: jobPreferences['openToRelocation'] as bool? ?? true,
      ),
      cvInsight: CvInsight(
        fileName: cvInsight['fileName'] as String? ?? 'SmartJob_CV_Draft.pdf',
        lastUpdatedLabel: cvInsight['lastUpdatedLabel'] as String? ?? '',
        completionScore: cvInsight['completionScore'] as int? ?? 0,
        atsScore: cvInsight['atsScore'] as int? ?? 0,
        keywordMatchScore: cvInsight['keywordMatchScore'] as int? ?? 0,
        missingSections: _stringList(cvInsight['missingSections']),
        improvementTips: _stringList(cvInsight['improvementTips']),
        missingKeywords: _stringList(cvInsight['missingKeywords']),
        highlightedStrengths: _stringList(cvInsight['highlightedStrengths']),
        selectedTemplate:
            cvInsight['selectedTemplate'] as String? ?? 'Classic Black & White Professional',
        parsedSummary: cvInsight['parsedSummary'] as String? ?? '',
        remoteStoragePath: cvInsight['remoteStoragePath'] as String? ?? '',
        uploadedCvBase64: cvInsight['uploadedCvBase64'] as String? ?? '',
        uploadedCvMimeType: cvInsight['uploadedCvMimeType'] as String? ?? '',
        accentColorHex: cvInsight['accentColorHex'] as String? ?? '#5D8CC3',
        fontFamily: cvInsight['fontFamily'] as String? ?? 'Inter',
        sectionOrder:
            decodedSectionOrder.isEmpty ? defaultCvSectionOrder : decodedSectionOrder,
        lastEditedAtIso: cvInsight['lastEditedAtIso'] as String? ?? '',
      ),
      themeMode: _themeModeFromString(map['themeMode'] as String?),
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      privacyModeEnabled: map['privacyModeEnabled'] as bool? ?? false,
      publicProfileEnabled: map['publicProfileEnabled'] as bool? ?? true,
      hideContactInfo: map['hideContactInfo'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _jobToMap(Job job) {
    return {
      'id': job.id,
      'title': job.title,
      'companyName': job.companyName,
      'location': job.location,
      'source': job.source,
      'salary': job.salary,
      'aiSummary': job.aiSummary,
      'description': job.description,
      'skills': job.skills,
      'tags': job.tags,
      'workMode': job.workMode.name,
      'jobType': job.jobType.name,
      'experienceLevel': job.experienceLevel.name,
      'logoLabel': job.logoLabel,
      'postedLabel': job.postedLabel,
      'matchScore': job.matchScore,
      'isSaved': job.isSaved,
      'feedback': job.feedback.name,
      'hasEasyApply': job.hasEasyApply,
    };
  }

  Job _jobFromMap(Map<String, dynamic> map) {
    return Job(
      id: map['id'] as String,
      title: map['title'] as String,
      companyName: map['companyName'] as String,
      location: map['location'] as String,
      source: map['source'] as String,
      salary: map['salary'] as String,
      aiSummary: map['aiSummary'] as String,
      description: map['description'] as String,
      skills: _stringList(map['skills']),
      tags: _stringList(map['tags']),
      workMode: WorkMode.values.byName(map['workMode'] as String),
      jobType: JobType.values.byName(map['jobType'] as String),
      experienceLevel: ExperienceLevel.values.byName(map['experienceLevel'] as String),
      logoLabel: map['logoLabel'] as String,
      postedLabel: map['postedLabel'] as String,
      matchScore: (map['matchScore'] as num).toDouble(),
      isSaved: map['isSaved'] as bool? ?? false,
      feedback: JobFeedback.values.byName(map['feedback'] as String? ?? JobFeedback.none.name),
      hasEasyApply: map['hasEasyApply'] as bool? ?? true,
    );
  }

  Map<String, dynamic> _applicationToMap(JobApplication application) {
    return {
      'id': application.id,
      'jobId': application.jobId,
      'role': application.role,
      'company': application.company,
      'location': application.location,
      'status': application.status.name,
      'source': application.source,
      'logoLabel': application.logoLabel,
      'appliedLabel': application.appliedLabel,
      'note': application.note,
      'timeline': application.timeline
          .map(
            (event) => {
              'label': event.label,
              'caption': event.caption,
              'dateLabel': event.dateLabel,
              'isComplete': event.isComplete,
            },
          )
          .toList(),
    };
  }

  JobApplication _applicationFromMap(Map<String, dynamic> map) {
    return JobApplication(
      id: map['id'] as String,
      jobId: map['jobId'] as String,
      role: map['role'] as String,
      company: map['company'] as String,
      location: map['location'] as String,
      status: ApplicationStatus.values.byName(map['status'] as String),
      source: map['source'] as String,
      logoLabel: map['logoLabel'] as String,
      appliedLabel: map['appliedLabel'] as String,
      note: map['note'] as String,
      timeline: (map['timeline'] as List<dynamic>? ?? const [])
          .map(
            (event) => ApplicationTimelineEvent(
              label: (event as Map<String, dynamic>)['label'] as String,
              caption: event['caption'] as String,
              dateLabel: event['dateLabel'] as String,
              isComplete: event['isComplete'] as bool? ?? false,
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> _messageToMap(InboxMessage message) {
    return {
      'id': message.id,
      'senderName': message.senderName,
      'senderCompany': message.senderCompany,
      'subject': message.subject,
      'preview': message.preview,
      'body': message.body,
      'timeLabel': message.timeLabel,
      'type': message.type.name,
      'applicationId': message.applicationId,
      'isUnread': message.isUnread,
      'isImportant': message.isImportant,
    };
  }

  InboxMessage _messageFromMap(Map<String, dynamic> map) {
    return InboxMessage(
      id: map['id'] as String,
      senderName: map['senderName'] as String,
      senderCompany: map['senderCompany'] as String,
      subject: map['subject'] as String,
      preview: map['preview'] as String,
      body: map['body'] as String,
      timeLabel: map['timeLabel'] as String,
      type: MessageType.values.byName(map['type'] as String),
      applicationId: map['applicationId'] as String,
      isUnread: map['isUnread'] as bool? ?? false,
      isImportant: map['isImportant'] as bool? ?? false,
    );
  }

  List<String> _stringList(dynamic value) {
    return (value as List<dynamic>? ?? const []).map((item) => item as String).toList();
  }

  String _themeModeToString(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
    };
  }

  ThemeMode _themeModeFromString(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  String _normalizeEmail(String email) => _database.normalizeEmail(email);

  String _nameFromEmail(String email) {
    final localPart = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ');
    return localPart
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  String _initialsFromName(String value) {
    final parts = value.split(' ').where((part) => part.trim().isNotEmpty).take(2);
    return parts.map((part) => part[0].toUpperCase()).join();
  }
}





